import 'package:dart_mappable/dart_mappable.dart';
import 'package:pocketflow/dictation/dictation_style.dart';

part 'models.mapper.dart';

const groqBaseUrl = 'https://api.groq.com/openai/v1';

/// Pipeline settings shared by every platform. Device-specific settings (hotkeys, Bluetooth mic, bubble) live
/// natively because the platform services read them on every key event.
@MappableClass()
class AppSettings with AppSettingsMappable {
  const AppSettings({
    this.apiBaseUrl = groqBaseUrl,
    this.transcriptionModel = 'whisper-large-v3-turbo',
    this.cleanupModel = 'openai/gpt-oss-20b',
    this.cleanupEnabled = true,
    this.language = '',
    this.learnFromCorrections = true,
    this.customInstructions = '',
    this.appStyles = const {},
    this.keepRecordings = false,
  });

  /// Any OpenAI-compatible API. Groq by default (free tier, fast Whisper).
  final String apiBaseUrl;
  final String transcriptionModel;
  final String cleanupModel;
  final bool cleanupEnabled;

  /// ISO-639-1 code, or empty for auto-detect.
  final String language;
  final bool learnFromCorrections;

  /// Free-form preferences appended to the cleanup prompt ("British spelling", "never use em dashes").
  final String customInstructions;

  /// User overrides of the built-in app → style mapping, keyed by Android package or macOS bundle id.
  final Map<String, DictationStyle> appStyles;

  /// Keep every dictation's audio, not only memos and failed recordings, to debug what the mic actually heard.
  final bool keepRecordings;
}

@MappableEnum()
enum TermSource { manual, learned }

@MappableClass()
class VocabularyTerm with VocabularyTermMappable {
  const VocabularyTerm({required this.term, required this.source, required this.addedAt, this.hits = 0});

  final String term;
  final TermSource source;
  final DateTime addedAt;

  /// How often the term showed up in a final transcript; ranks it for the limited Whisper prompt.
  final int hits;
}

/// Deterministic fix applied to every transcript: a recurring mishearing ("shin aid") → the intended term ("Sinead").
@MappableClass()
class ReplacementRule with ReplacementRuleMappable {
  const ReplacementRule({required this.from, required this.to, required this.source, required this.addedAt});

  final String from;
  final String to;
  final TermSource source;
  final DateTime addedAt;
}

@MappableEnum()
enum DictationMode {
  /// Text goes straight into the focused field.
  dictation,

  /// Hands-free recording (e.g. walking with a headset) saved as a memo or draft.
  memo,

  /// Audio saved on the device without transcribing; [HistoryEntry.text] stays empty until it's transcribed on request.
  recording,
}

@MappableClass()
class HistoryEntry with HistoryEntryMappable {
  const HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.mode,
    required this.style,
    required this.rawText,
    required this.text,
    this.appId,
    this.audioPath,
    this.audioMillis,
    this.processingMillis,
    this.transcribeMillis,
    this.cleanupMillis,
    this.error,
  });

  final String id;
  final DateTime createdAt;
  final DictationMode mode;
  final DictationStyle style;
  final String rawText;
  final String text;
  final String? appId;

  /// Kept for memos and recordings so they can be replayed or re-transcribed, and for any recording whose
  /// transcription failed.
  /// Dictation audio is otherwise deleted after processing, unless [AppSettings.keepRecordings] is on.
  final String? audioPath;
  final int? audioMillis;
  final int? processingMillis;

  /// Time spent on each step, within [processingMillis]. [cleanupMillis] is null when cleanup was skipped.
  final int? transcribeMillis;
  final int? cleanupMillis;

  /// Why transcription failed. Set while the entry is waiting to be retried; [text] is empty until then.
  final String? error;

  bool get failed => error != null;

  /// A recording saved without transcribing, not transcribed yet.
  bool get untranscribed => mode == DictationMode.recording && text.isEmpty && error == null;
}

/// Something learned from a correction, reported back so the UI can show it and offer undo.
@MappableClass()
class LearnedItem with LearnedItemMappable {
  const LearnedItem({required this.heard, required this.term, required this.addedRule});

  final String heard;
  final String term;
  final bool addedRule;
}
