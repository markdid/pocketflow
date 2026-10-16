import 'package:pocketflow/dictation/models.dart';

/// Turns the personal vocabulary into transcription hints and applies replacement rules.
///
/// The prompt budget and echo checks follow OpenWhispr's measurements (MIT, see NOTICE).
class Vocabulary {
  Vocabulary._();

  /// Groq rejects a `prompt` over 896 characters.
  static const groqPromptLimit = 890;

  /// Whisper decoders read ~223 prompt tokens and keep the *tail* of anything longer. A comma-separated list of
  /// names tokenizes at roughly 2.5 characters per token, so this is what actually reaches the model.
  static const whisperDecoderChars = 550;

  /// Whisper `prompt`: the highest-ranked terms that fit, ordered so the most important come last (the decoder keeps
  /// the tail).
  static String whisperPrompt(List<VocabularyTerm> terms, {int budget = whisperDecoderChars}) {
    final picked = <String>[];
    var length = 0;
    for (final term in rank(terms)) {
      final cost = term.term.length + (picked.isEmpty ? 0 : 2);
      if (length + cost > budget) continue;
      picked.add(term.term);
      length += cost;
    }
    return picked.reversed.join(', ');
  }

  /// Newest manual entries first (the user just asked for them), then by how often each term is actually used.
  static List<VocabularyTerm> rank(List<VocabularyTerm> terms) {
    final manual = terms.where((t) => t.source == TermSource.manual).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final fresh = manual.take(5).toList();
    final rest = terms.where((t) => !fresh.contains(t)).toList()
      ..sort((a, b) {
        final byHits = b.hits.compareTo(a.hits);
        return byHits != 0 ? byHits : b.addedAt.compareTo(a.addedAt);
      });
    return [...fresh, ...rest];
  }

  /// True when Whisper hallucinated the hint list back instead of transcribing speech (common on silent audio).
  static bool isPromptEcho(String text, String prompt) {
    final textWords = _words(text);
    final promptWords = _words(prompt).toSet();
    if (textWords.isEmpty || promptWords.isEmpty) return false;

    final unique = textWords.toSet();
    final fromPrompt = unique.where(promptWords.contains).length;
    if (fromPrompt / unique.length < 0.9) return false;

    final counts = <String, int>{};
    final looped = textWords.any((w) => (counts[w] = (counts[w] ?? 0) + 1) >= 3);
    final usesMostOfPrompt = fromPrompt / promptWords.length >= 0.7;
    final continuesList = text.contains(',') && unique.length >= 3;
    return looped || usesMostOfPrompt || continuesList;
  }

  /// Applies replacement rules on word boundaries, case-insensitively.
  static String applyReplacements(String text, List<ReplacementRule> rules) {
    var result = text;
    for (final rule in rules) {
      if (rule.from.trim().isEmpty) continue;
      final pattern = RegExp(
        '(?<![\\p{L}\\p{N}])${RegExp.escape(rule.from.trim())}(?![\\p{L}\\p{N}])',
        caseSensitive: false,
        unicode: true,
      );
      result = result.replaceAll(pattern, rule.to);
    }
    return result;
  }

  /// Terms that appear in [text], used to bump their ranking.
  static List<VocabularyTerm> termsUsedIn(String text, List<VocabularyTerm> terms) {
    final lower = text.toLowerCase();
    return terms.where((t) => t.term.isNotEmpty && lower.contains(t.term.toLowerCase())).toList();
  }

  static List<String> _words(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
}
