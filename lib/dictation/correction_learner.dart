import 'dart:convert';
import 'dart:math';

import 'package:pocketflow/dictation/openai_client.dart';

/// A spot where the user changed what was dictated: [heard] (what we inserted) became [fixed].
class CorrectionCandidate {
  const CorrectionCandidate({required this.heard, required this.fixed, required this.context});

  final String heard;
  final String fixed;

  /// A few words around the edit, so the reviewer can tell a name from a rewording.
  final String context;

  @override
  String toString() => '$heard → $fixed';
}

class ReviewedCorrection {
  const ReviewedCorrection({required this.candidate, required this.term, required this.safeAsRule});

  final CorrectionCandidate candidate;
  final String term;

  /// The misheard form is never right on its own, so it can be rewritten automatically on future transcripts.
  final bool safeAsRule;
}

/// Learns vocabulary from the edits a user makes right after dictating.
///
/// Finding candidates is a word-level diff in the spirit of OpenWhispr's correctionLearner (MIT, see NOTICE),
/// extended to phrases ("shin aid" → "Sinead"). An LLM pass then rejects anything that isn't a mishearing of a name
/// or term, so ordinary rewording never pollutes the vocabulary.
class CorrectionLearner {
  CorrectionLearner._();

  static const _maxPhraseWords = 3;
  static const _maxEditDistanceRatio = 0.65;

  /// Diffs the inserted text against the field's final value.
  static List<CorrectionCandidate> findCandidates({
    required String inserted,
    required String fieldText,
    Iterable<String> known = const [],
  }) {
    if (inserted.trim().isEmpty || fieldText.trim().isEmpty || inserted == fieldText) return const [];
    final original = _tokenize(inserted);
    final edited = _tokenize(_editedRegion(inserted, fieldText));
    if (original.isEmpty || edited.isEmpty) return const [];

    final changes = _changedRuns(original, edited);
    final changedWords = changes.fold<int>(0, (sum, c) => sum + c.$1.length);
    // Most of the text changed: that's a rewrite, not a correction.
    if (changedWords > original.length * 0.5) return const [];

    final knownLower = known.map((k) => k.toLowerCase()).toSet();
    final seen = <String>{};
    final results = <CorrectionCandidate>[];
    for (final (removed, added, editedIndex) in changes) {
      if (removed.isEmpty || added.isEmpty) continue;
      if (removed.length > _maxPhraseWords || added.length > _maxPhraseWords) continue;

      final heard = removed.join(' ');
      final fixed = added.join(' ');
      final fixedLower = fixed.toLowerCase();
      if (heard.toLowerCase() == fixedLower) continue; // case-only edits are style, not vocabulary
      if (fixed.length < 3 || knownLower.contains(fixedLower) || !seen.add(fixedLower)) continue;
      if (added.length == 1 && _commonWords.contains(fixedLower)) continue;

      final a = _letters(heard);
      final b = _letters(fixed);
      if (_editDistance(a, b) / max(a.length, b.length) > _maxEditDistanceRatio) continue;

      final start = max(0, editedIndex - 4);
      final end = min(edited.length, editedIndex + added.length + 4);
      results.add(CorrectionCandidate(heard: heard, fixed: fixed, context: edited.sublist(start, end).join(' ')));
    }
    return results;
  }

  /// Asks the model which candidates are genuine mishearings worth remembering.
  static Future<List<ReviewedCorrection>> review(
    OpenAiClient client,
    String model,
    List<CorrectionCandidate> candidates,
  ) async {
    if (candidates.isEmpty) return const [];
    final input = [
      for (final (i, c) in candidates.indexed) {'id': i, 'heard': c.heard, 'fixed': c.fixed, 'context': c.context},
    ];
    final reply = await client.chat(model: model, system: _reviewPrompt, user: jsonEncode(input), jsonMode: true);

    final results = <ReviewedCorrection>[];
    try {
      final items = (jsonDecode(reply) as Map<String, Object?>)['results'] as List<Object?>? ?? const [];
      for (final item in items.whereType<Map<String, Object?>>()) {
        final id = item['id'];
        if (item['accept'] != true || id is! int || id < 0 || id >= candidates.length) continue;
        final candidate = candidates[id];
        final term = (item['term'] as String?)?.trim();
        results.add(
          ReviewedCorrection(
            candidate: candidate,
            term: term == null || term.isEmpty ? candidate.fixed : term,
            safeAsRule: item['rule'] == true,
          ),
        );
      }
    } on FormatException {
      return const [];
    }
    return results;
  }

  static const _reviewPrompt = '''
You review possible vocabulary for a voice dictation app. Each candidate is a word or phrase the speech recognizer produced ("heard"), what the user changed it to right afterwards ("fixed"), and a few surrounding words ("context").

Accept a candidate only if both are true:
1. Sound-alike: "heard" is a plausible mishearing of "fixed" (similar sounds, words split or merged, phonetic spelling). Examples: "shin aid" → "Sinead", "graph QL" → "GraphQL", "Kate Lynn" → "Caitlin".
2. Worth remembering: "fixed" is a name, brand, product, jargon, acronym, or unusual spelling the recognizer is likely to get wrong again. Treat a multi-word name as one term.

Reject ordinary editing: rewording, synonyms, grammar or tense changes, typo fixes in common words, and changes that alter the meaning.

For each accepted candidate also decide "rule": true only if "heard" would essentially never be the right text on its own, so it can be replaced automatically in future. Examples: "shin aid" → "Sinead" is accepted with rule true; "grok" → "Groq" is accepted with rule false, because "grok" is a real word in other sentences.

Reply with JSON only: {"results":[{"id":0,"accept":true,"term":"Sinead","rule":true}]}. Include every id.''';

  /// The part of the field that corresponds to the inserted text (the field may hold other text too).
  static String _editedRegion(String inserted, String fieldText) {
    if (fieldText.length <= inserted.length * 1.5) return fieldText;
    if (fieldText.contains(inserted)) return inserted;

    final original = _tokenize(inserted);
    final field = _tokenize(fieldText);
    final window = original.length;
    if (field.length <= window) return fieldText;

    var bestStart = 0;
    var bestScore = -1;
    for (var i = 0; i <= field.length - window; i++) {
      var matches = 0;
      for (var j = 0; j < window; j++) {
        if (field[i + j].toLowerCase() == original[j].toLowerCase()) matches++;
      }
      if (matches > bestScore) {
        bestScore = matches;
        bestStart = i;
      }
    }
    // Not recognizably the same text any more.
    if (bestScore < window * 0.3) return fieldText;
    // Widen a little so phrase edits that changed the word count are still covered.
    final end = min(field.length, bestStart + window + _maxPhraseWords);
    return field.sublist(bestStart, end).join(' ');
  }

  /// Word-level LCS alignment, returning each run of (removed words, added words, index in edited).
  static List<(List<String>, List<String>, int)> _changedRuns(List<String> a, List<String> b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        dp[i][j] = a[i - 1].toLowerCase() == b[j - 1].toLowerCase()
            ? dp[i - 1][j - 1] + 1
            : max(dp[i - 1][j], dp[i][j - 1]);
      }
    }

    final runs = <(List<String>, List<String>, int)>[];
    var removed = <String>[];
    var added = <String>[];
    var i = m;
    var j = n;
    void flush() {
      if (removed.isNotEmpty || added.isNotEmpty) runs.add((removed.reversed.toList(), added.reversed.toList(), j));
      removed = [];
      added = [];
    }

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && a[i - 1].toLowerCase() == b[j - 1].toLowerCase()) {
        flush();
        i--;
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        added.add(b[j - 1]);
        j--;
      } else {
        removed.add(a[i - 1]);
        i--;
      }
    }
    flush();
    return runs.reversed.toList();
  }

  static List<String> _tokenize(String text) => text
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'^[^\p{L}\p{N}_]+|[^\p{L}\p{N}_]+$', unicode: true), ''))
      .where((w) => w.isNotEmpty)
      .toList();

  static String _letters(String text) => text.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  static int _editDistance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        current[j] = a[i - 1] == b[j - 1]
            ? previous[j - 1]
            : 1 + min(previous[j - 1], min(previous[j], current[j - 1]));
      }
      previous = current;
    }
    return previous[b.length];
  }

  /// Swapping one everyday word for another is a content edit, not vocabulary.
  static final _commonWords =
      '''
the and for not with you this but his from they say her she will one all would there their what out about who get
which when make can like time just him know take into year your good some could them see other than then now look
only come over think also back after use two how our work first well way even new want because any these give day
most are was were been has had did does said went made got came took saw knew thought where why here very much many
still too again off down never every own same another both each few more less last next while before through under
between should might must being have that its yes okay sure thanks'''
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toSet();
}
