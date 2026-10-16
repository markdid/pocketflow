import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  bool get isRateLimited => statusCode == 429;
  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() {
    if (isAuthError) return 'The API key was rejected ($statusCode). Check it in Settings.';
    if (isRateLimited) return 'Rate limited by the API. Wait a moment and try again.';
    return 'API error $statusCode: $body';
  }
}

/// Minimal client for OpenAI-compatible transcription and chat endpoints (Groq, OpenAI, local servers).
class OpenAiClient {
  OpenAiClient({required this.baseUrl, required this.apiKey, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _http;

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/$path');

  Future<String> transcribe({required File audio, required String model, String language = '', String? prompt}) async {
    final request = http.MultipartRequest('POST', _uri('audio/transcriptions'))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model'] = model
      ..fields['response_format'] = 'json'
      ..fields['temperature'] = '0'
      ..files.add(await http.MultipartFile.fromPath('file', audio.path));
    if (language.isNotEmpty) request.fields['language'] = language;
    if (prompt != null && prompt.isNotEmpty) request.fields['prompt'] = prompt;

    final response = await http.Response.fromStream(await _http.send(request).timeout(const Duration(seconds: 120)));
    final json = _decode(response);
    return (json['text'] as String? ?? '').trim();
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
    final response = await _http
        .post(
          _uri('chat/completions'),
          headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    final json = _decode(response);
    final choices = json['choices'] as List<Object?>? ?? const [];
    if (choices.isEmpty) return '';
    final message = (choices.first as Map<String, Object?>)['message'] as Map<String, Object?>?;
    return (message?['content'] as String? ?? '').trim();
  }

  static bool _isReasoningModel(String model) => model.contains('gpt-oss') || model.contains('qwen3');

  Map<String, Object?> _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) throw ApiException(response.statusCode, text);
    return jsonDecode(text) as Map<String, Object?>;
  }

  void close() => _http.close();
}
