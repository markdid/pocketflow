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

final dictationPipelineProvider = Provider<DictationPipeline>(
  (ref) => DictationPipeline(
    settings: ref.watch(settingsRepositoryProvider),
    vocabulary: ref.watch(vocabularyRepositoryProvider),
    history: ref.watch(historyRepositoryProvider),
  ),
);

class MissingApiKeyException implements Exception {
  @override
  String toString() => 'Add your Groq API key in PocketFlow settings first.';
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
/// destination app, and record the result in history.
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

  Future<DictationResult> process({
    required File audio,
    DictationMode mode = DictationMode.dictation,
    String? appId,
    int? audioMillis,
  }) async {
    final started = DateTime.now();
    final settings = await _settings.load();
    final client = await _client(settings);
    try {
      final vocabulary = await _vocabulary.load();
      final prompt = Vocabulary.whisperPrompt(vocabulary.terms);

      var raw = await client.transcribe(
        audio: audio,
        model: settings.transcriptionModel,
        language: settings.language,
        prompt: prompt,
      );
      if (prompt.isNotEmpty && Vocabulary.isPromptEcho(raw, prompt)) {
        LoggerService.w('Dropped a transcript that echoed the vocabulary prompt: $raw');
        raw = '';
      }
      if (raw.isEmpty) return const DictationResult(text: '', entry: null);

      final style = mode == DictationMode.memo
          ? DictationStyle.memo
          : DictationStyle.forApp(appId, overrides: settings.appStyles);
      final corrected = Vocabulary.applyReplacements(raw, vocabulary.rules);

      String? warning;
      var text = corrected;
      if (settings.cleanupEnabled) {
        try {
          text = await _cleanUp(client, settings, style, corrected, vocabulary.terms, appId);
        } on Exception catch (e) {
          LoggerService.w('Cleanup failed, using the raw transcript', e);
          warning = 'Cleanup failed, inserted the raw transcript.';
          text = corrected;
        }
      }
      if (text.isEmpty) return const DictationResult(text: '', entry: null);

      await _vocabulary.recordHits(Vocabulary.termsUsedIn(text, vocabulary.terms).map((t) => t.term));
      final entry = HistoryEntry(
        id: started.microsecondsSinceEpoch.toString(),
        createdAt: started,
        mode: mode,
        style: style,
        rawText: raw,
        text: text,
        appId: appId,
        audioPath: mode == DictationMode.memo ? await _keepMemoAudio(audio, started) : null,
        audioMillis: audioMillis,
        processingMillis: DateTime.now().difference(started).inMilliseconds,
      );
      await _history.add(entry);
      return DictationResult(text: text, entry: entry, warning: warning);
    } finally {
      client.close();
    }
  }

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

    final client = await _client(settings);
    try {
      final reviewed = await CorrectionLearner.review(client, settings.cleanupModel, candidates);
      final learned = <LearnedItem>[];
      for (final r in reviewed) {
        await _vocabulary.addTerm(r.term, source: TermSource.learned);
        if (r.safeAsRule) await _vocabulary.addRule(r.candidate.heard, r.term, source: TermSource.learned);
        learned.add(LearnedItem(heard: r.candidate.heard, term: r.term, addedRule: r.safeAsRule));
      }
      return learned;
    } finally {
      client.close();
    }
  }

  Future<OpenAiClient> _client(AppSettings settings) async {
    final key = await _settings.apiKey();
    if (key.isEmpty) throw MissingApiKeyException();
    return _clientFactory(settings.apiBaseUrl, key);
  }

  Future<String> _keepMemoAudio(File audio, DateTime started) async {
    final dir = await _history.memoDirectory();
    final extension = audio.path.contains('.') ? audio.path.split('.').last : 'wav';
    final kept = await audio.copy('${dir.path}/memo_${started.millisecondsSinceEpoch}.$extension');
    return kept.path;
  }
}
