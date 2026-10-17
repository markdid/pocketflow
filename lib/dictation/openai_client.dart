import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.body, {this.retryAfter});

  final int statusCode;
  final String body;

  /// From the `retry-after` header, when the API sent one.
  final Duration? retryAfter;

  bool get isRateLimited => statusCode == 429;
  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() {
    if (isAuthError) return 'The API key was rejected ($statusCode). Check it in Settings.';
    if (isRateLimited) return 'Rate limited by the API. Wait a moment and try again.';
    if (statusCode == 413) return 'The recording is too large for the API to accept.';
    if (isServerError) return 'The API is having trouble right now ($statusCode).';
    return 'API error $statusCode: $body';
  }
}

/// The request never got an answer: no connection, DNS failure, dropped socket, or a timeout.
class NetworkException implements Exception {
  NetworkException(this.cause);

  final Object cause;

  @override
  String toString() => cause is TimeoutException
      ? 'The API took too long to answer. Check your connection.'
      : 'Couldn’t reach the API. Check your internet connection.';
}

/// Minimal client for OpenAI-compatible transcription and chat endpoints (Groq, OpenAI, local servers).
///
/// Keep one instance around: it holds the connection open between dictations, and [warmUp] opens it while the user
/// is still speaking, so neither the transcription nor the cleanup request pays for DNS, TCP, and TLS setup.
class OpenAiClient {
  OpenAiClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
    this.retryDelays = const [Duration(seconds: 1), Duration(seconds: 3)],
  }) : _http = httpClient ?? IOClient(HttpClient()..idleTimeout = const Duration(minutes: 5));

  final String baseUrl;
  final String apiKey;
  final http.Client _http;

  /// Waits between transcription attempts after a dropped connection, rate limit, or server error.
  final List<Duration> retryDelays;

  Future<void>? _warming;

  /// Opens the connection ahead of the first real request. Failures are ignored; the real request reports them.
  void warmUp() {
    _warming ??= _http
        .get(_uri('models'), headers: {'Authorization': 'Bearer $apiKey'})
        .timeout(const Duration(seconds: 5))
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(() => _warming = null);
  }

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/$path');

  Future<String> transcribe({required File audio, required String model, String language = '', String? prompt}) {
    // Uploads on a slow mobile connection need longer than the transcription itself: allow about 10 s per MB.
    final timeout = Duration(seconds: 60 + audio.lengthSync() ~/ 100000);
    return _withRetry(() async {
      final request = http.MultipartRequest('POST', _uri('audio/transcriptions'))
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = model
        ..fields['response_format'] = 'json'
        ..fields['temperature'] = '0'
        ..files.add(await http.MultipartFile.fromPath('file', audio.path));
      if (language.isNotEmpty) request.fields['language'] = language;
      if (prompt != null && prompt.isNotEmpty) request.fields['prompt'] = prompt;

      final response = await _send(() async => http.Response.fromStream(await _http.send(request)), timeout);
      final json = _decode(response);
      return (json['text'] as String? ?? '').trim();
    });
  }

  Future<String> chat({
    required String model,
    required String system,
    required String user,
    bool jsonMode = false,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final body = <String, Object?>{
      'model': model,
      'temperature': 0,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      if (jsonMode) 'response_format': {'type': 'json_object'},
      // Reasoning models (gpt-oss, qwen3) otherwise spend seconds thinking about a one-line cleanup.
      if (_isReasoningModel(model)) ...{'reasoning_effort': 'low', 'include_reasoning': false},
    };
    final response = await _send(
      () => _http.post(
        _uri('chat/completions'),
        headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      timeout,
    );
    final json = _decode(response);
    final choices = json['choices'] as List<Object?>? ?? const [];
    if (choices.isEmpty) return '';
    final message = (choices.first as Map<String, Object?>)['message'] as Map<String, Object?>?;
    return (message?['content'] as String? ?? '').trim();
  }

  static bool _isReasoningModel(String model) => model.contains('gpt-oss') || model.contains('qwen3');

  Future<http.Response> _send(Future<http.Response> Function() request, Duration timeout) async {
    // Starting now would open a second connection next to the one being warmed up.
    await _warming;
    try {
      return await request().timeout(timeout);
    } on TimeoutException catch (e) {
      throw NetworkException(e);
    } on SocketException catch (e) {
      throw NetworkException(e);
    } on http.ClientException catch (e) {
      throw NetworkException(e);
    }
  }

  /// Retries failures that are likely to pass: connection errors, rate limits with a short wait, and server errors.
  /// Timeouts and other API errors fail straight away so nobody waits minutes for an answer.
  Future<T> _withRetry<T>(Future<T> Function() attempt) async {
    for (var i = 0; ; i++) {
      try {
        return await attempt();
      } on Exception catch (e) {
        final wait = i < retryDelays.length ? _retryWait(e, retryDelays[i]) : null;
        if (wait == null) rethrow;
        await Future<void>.delayed(wait);
      }
    }
  }

  static Duration? _retryWait(Exception error, Duration fallback) {
    if (error is NetworkException) return error.cause is TimeoutException ? null : fallback;
    if (error is! ApiException) return null;
    if (error.isServerError) return fallback;
    if (!error.isRateLimited) return null;
    final retryAfter = error.retryAfter ?? fallback;
    return retryAfter <= const Duration(seconds: 10) ? retryAfter : null;
  }

  Map<String, Object?> _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final seconds = double.tryParse(response.headers['retry-after'] ?? '');
      throw ApiException(
        response.statusCode,
        text,
        retryAfter: seconds == null ? null : Duration(milliseconds: (seconds * 1000).round()),
      );
    }
    return jsonDecode(text) as Map<String, Object?>;
  }

  void close() => _http.close();
}
