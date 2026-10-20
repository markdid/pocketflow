import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/data/repositories/history_repository.dart';
import 'package:pocketflow/data/repositories/settings_repository.dart';
import 'package:pocketflow/data/repositories/vocabulary_repository.dart';
import 'package:pocketflow/dictation/cleanup_prompt.dart';
import 'package:pocketflow/dictation/correction_learner.dart';
import 'package:pocketflow/dictation/dictation_style.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/dictation/openai_client.dart';
import 'package:pocketflow/dictation/vocabulary.dart';
import 'package:pocketflow/services/logging_service.dart';

final dictationPipelineProvider = Provider<DictationPipeline>((ref) {
  final pipeline = DictationPipeline(
    settings: ref.watch(settingsRepositoryProvider),
    vocabulary: ref.watch(vocabularyRepositoryProvider),
    history: ref.watch(historyRepositoryProvider),
  );
  ref.onDispose(pipeline.close);
  return pipeline;
});

class MissingApiKeyException implements Exception {
  @override
  String toString() => 'Add your Groq API key in PocketFlow settings first.';
}

/// Transcription failed, but the recording was saved to history so it can be retried.
class TranscriptionSavedException implements Exception {
  TranscriptionSavedException(this.cause, this.entry);

  final Object cause;
  final HistoryEntry entry;

  @override
  String toString() => '$cause The recording is saved in PocketFlow to try again.';
}

class DictationResult {
  const DictationResult({required this.text, required this.entry, this.warning});

  /// Empty when nothing was said.
  final String text;
  final HistoryEntry? entry;

  /// Set when cleanup failed and the raw transcript was used instead.
  final String? warning;
}

/// Audio file in, finished text out: transcribe with vocabulary hints, fix known mishearings, clean up for the
/// destination app, and record the result in history. A recording that can't be transcribed (offline, API down, no
/// key yet) is kept in history instead of being lost.
class DictationPipeline {
  DictationPipeline({
    required this._settings,
    required this._vocabulary,
    required this._history,
    OpenAiClient Function(String baseUrl, String apiKey)? clientFactory,
  }) : _clientFactory = clientFactory ?? ((baseUrl, apiKey) => OpenAiClient(baseUrl: baseUrl, apiKey: apiKey));

  final SettingsRepository _settings;
  final VocabularyRepository _vocabulary;
  final HistoryRepository _history;
  final OpenAiClient Function(String baseUrl, String apiKey) _clientFactory;
  OpenAiClient? _cachedClient;

  /// Call when recording starts, so the connection is open by the time the audio is ready.
  Future<void> warmUp() async {
    try {
      (await _client(await _settings.load())).warmUp();
    } on Exception catch (e) {
      LoggerService.w('Warm-up skipped', e);
    }
  }

  void close() {
    _cachedClient?.close();
    _cachedClient = null;
  }

  /// Throws [TranscriptionSavedException] when transcription fails and the recording was kept for [retry].
  /// [voiceCommand] means the recording starts with a spoken "take a note" (from the glasses), which is dropped.
  Future<DictationResult> process({
    required File audio,
    DictationMode mode = DictationMode.dictation,
    String? appId,
    int? audioMillis,
    bool voiceCommand = false,
  }) async {
    final timer = Stopwatch()..start();
    final started = DateTime.now();
    final settings = await _settings.load();
    final entry = HistoryEntry(
      id: started.microsecondsSinceEpoch.toString(),
      createdAt: started,
      mode: mode,
      style: mode == DictationMode.memo
          ? DictationStyle.memo
          : DictationStyle.forApp(appId, overrides: settings.appStyles),
      rawText: '',
      text: '',
      appId: appId,
      audioMillis: audioMillis,
    );
    final String raw;
    try {
      final heard = await _transcribe(settings, audio);
      raw = voiceCommand ? dropNoteCommand(heard) : heard;
    } on Exception catch (e) {
      LoggerService.w('Transcription failed, keeping the recording to retry', e);
      final saved = entry.copyWith(audioPath: await _keepAudio(audio, started), error: e.toString());
      await _history.save(saved);
      throw TranscriptionSavedException(e, saved);
    }
    return _finish(settings, entry.copyWith(transcribeMillis: timer.elapsedMilliseconds), raw, audio, timer);
  }

  /// Transcribes a recording kept after a failed attempt and fills in its history entry. On failure the entry keeps
  /// the recording and the new error, and the error is rethrown.
  Future<DictationResult> retry(String id) async {
    final timer = Stopwatch()..start();
    final entry = (await _history.load()).where((e) => e.id == id).firstOrNull;
    final path = entry?.audioPath;
    if (entry == null || path == null) return const DictationResult(text: '', entry: null);
    final audio = File(path);
    final settings = await _settings.load();
    final String raw;
    try {
      raw = await _transcribe(settings, audio);
    } on Exception catch (e) {
      await _history.save(entry.copyWith(error: e.toString()));
      rethrow;
    }
    final result = await _finish(
      settings,
      entry.copyWith(error: null, transcribeMillis: timer.elapsedMilliseconds),
      raw,
      audio,
      timer,
    );
    // Nothing was said after all.
    if (result.entry == null) await _history.remove(id);
    return result;
  }

  Future<String> _transcribe(AppSettings settings, File audio) async {
    final client = await _client(settings);
    final vocabulary = await _vocabulary.load();
    final prompt = Vocabulary.whisperPrompt(vocabulary.terms);
    final text = await client.transcribe(
      audio: audio,
      model: settings.transcriptionModel,
      language: settings.language,
      prompt: prompt,
    );
    if (prompt.isNotEmpty && Vocabulary.isPromptEcho(text, prompt)) {
      LoggerService.w('Dropped a transcript that echoed the vocabulary prompt: $text');
      return '';
    }
    return text;
  }

  Future<DictationResult> _finish(
    AppSettings settings,
    HistoryEntry entry,
    String raw,
    File audio,
    Stopwatch timer,
  ) async {
    if (raw.isEmpty) return const DictationResult(text: '', entry: null);
    final vocabulary = await _vocabulary.load();
    final corrected = Vocabulary.applyReplacements(raw, vocabulary.rules);

    String? warning;
    var text = corrected;
    int? cleanupMillis;
    if (settings.cleanupEnabled && !_alreadyClean(settings, entry.style, corrected)) {
      final cleanupStarted = timer.elapsedMilliseconds;
      try {
        text = await _cleanUp(await _client(settings), settings, entry.style, corrected, vocabulary.terms, entry.appId);
      } on Exception catch (e) {
        LoggerService.w('Cleanup failed, using the raw transcript', e);
        warning = 'Cleanup failed, inserted the raw transcript.';
        text = corrected;
      }
      cleanupMillis = timer.elapsedMilliseconds - cleanupStarted;
    }
    if (text.isEmpty) return const DictationResult(text: '', entry: null);

    await _vocabulary.recordHits(Vocabulary.termsUsedIn(text, vocabulary.terms).map((t) => t.term));
    final keep = entry.mode == DictationMode.memo || settings.keepRecordings;
    final kept = entry.audioPath;
    final finished = entry.copyWith(
      rawText: raw,
      text: text,
      audioPath: keep ? kept ?? await _keepAudio(audio, entry.createdAt) : null,
      cleanupMillis: cleanupMillis,
      processingMillis: timer.elapsedMilliseconds,
    );
    LoggerService.i(
      'Dictation took ${finished.processingMillis} ms: transcribe ${finished.transcribeMillis} ms, '
      'cleanup ${cleanupMillis == null ? 'skipped' : '$cleanupMillis ms'}',
    );
    await _history.save(finished);
    // A retried dictation no longer needs its recording; memos keep theirs for replay.
    if (!keep && kept != null && File(kept).existsSync()) await File(kept).delete();
    return DictationResult(text: text, entry: finished, warning: warning);
  }

  /// "Take a note, call Sinead." → "Call Sinead." Matches the phrases Lumon listens for to route a note here.
  static String dropNoteCommand(String transcript) {
    final match = _noteCommand.firstMatch(transcript);
    if (match == null) return transcript;
    final rest = transcript.substring(match.end).trim();
    return rest.isEmpty ? '' : rest[0].toUpperCase() + rest.substring(1);
  }

  static final _noteCommand = RegExp(
    r'^\s*(?:(?:please\s+)?(?:take|make)\s+a\s+note|note\s+to\s+self|note|remember(?:\s+that)?)\b[\s,:.-]*',
    caseSensitive: false,
  );

  /// A short phrase Whisper already punctuated needs no cleanup, and skipping the call saves a round trip. Custom
  /// instructions may apply even to short phrases, so they always go through the model.
  static bool _alreadyClean(AppSettings settings, DictationStyle style, String transcript) =>
      settings.customInstructions.trim().isEmpty && CleanupPrompt.isAlreadyClean(transcript, style);

  Future<String> _cleanUp(
    OpenAiClient client,
    AppSettings settings,
    DictationStyle style,
    String transcript,
    List<VocabularyTerm> terms,
    String? appId,
  ) async {
    var cleaned = await client.chat(
      model: settings.cleanupModel,
      system: CleanupPrompt.system(style: style, customInstructions: settings.customInstructions),
      user: CleanupPrompt.user(
        transcript: transcript,
        vocabulary: Vocabulary.rank(terms).take(80).map((t) => t.term).toList(),
        appId: appId,
      ),
      // Memos can be minutes long.
      timeout: Duration(seconds: style == DictationStyle.memo ? 120 : 45),
    );
    if (cleaned.trim() == CleanupPrompt.empty) return '';
    // Some models end lines with markdown hard breaks ("Thanks,  ").
    cleaned = cleaned.split('\n').map((line) => line.trimRight()).join('\n').trim();
    if (cleaned.isEmpty || CleanupPrompt.looksLikeAnAnswer(transcript, cleaned)) return transcript;
    // Replacement rules again, in case the model "corrected" a learned spelling back.
    final rules = (await _vocabulary.load()).rules;
    return Vocabulary.applyReplacements(cleaned, rules);
  }

  /// Called once the user has finished editing a field we typed into. Returns what was learned.
  Future<List<LearnedItem>> learnFromEdit({required String inserted, required String fieldText}) async {
    final settings = await _settings.load();
    if (!settings.learnFromCorrections) return const [];
    final vocabulary = await _vocabulary.load();
    final candidates = CorrectionLearner.findCandidates(
      inserted: inserted,
      fieldText: fieldText,
      known: vocabulary.terms.map((t) => t.term),
    );
    if (candidates.isEmpty) return const [];
    LoggerService.i('Correction candidates: $candidates');

    final reviewed = await CorrectionLearner.review(await _client(settings), settings.cleanupModel, candidates);
    final learned = <LearnedItem>[];
    for (final r in reviewed) {
      await _vocabulary.addTerm(r.term, source: TermSource.learned);
      if (r.safeAsRule) await _vocabulary.addRule(r.candidate.heard, r.term, source: TermSource.learned);
      learned.add(LearnedItem(heard: r.candidate.heard, term: r.term, addedRule: r.safeAsRule));
    }
    return learned;
  }

  Future<OpenAiClient> _client(AppSettings settings) async {
    final key = await _settings.apiKey();
    if (key.isEmpty) throw MissingApiKeyException();
    final cached = _cachedClient;
    if (cached != null && cached.baseUrl == settings.apiBaseUrl && cached.apiKey == key) return cached;
    cached?.close();
    return _cachedClient = _clientFactory(settings.apiBaseUrl, key);
  }

  Future<String> _keepAudio(File audio, DateTime started) async {
    final dir = await _history.recordingsDirectory();
    final extension = audio.path.contains('.') ? audio.path.split('.').last : 'wav';
    final kept = await audio.copy('${dir.path}/recording_${started.millisecondsSinceEpoch}.$extension');
    return kept.path;
  }
}
