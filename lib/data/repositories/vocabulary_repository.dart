import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/data/json_file_store.dart';
import 'package:pocketflow/dictation/models.dart';

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) => VocabularyRepository());

typedef VocabularyData = ({List<VocabularyTerm> terms, List<ReplacementRule> rules});

class VocabularyRepository {
  VocabularyRepository({JsonFileStore? store}) : _store = store ?? JsonFileStore();

  final JsonFileStore _store;

  Future<VocabularyData> load() async {
    final json = await _store.read('vocabulary');
    if (json is! Map<String, Object?>) return (terms: <VocabularyTerm>[], rules: <ReplacementRule>[]);
    return (
      terms: [
        for (final item in (json['terms'] as List<Object?>? ?? const []).whereType<Map<String, Object?>>())
          VocabularyTermMapper.fromMap(item),
      ],
      rules: [
        for (final item in (json['rules'] as List<Object?>? ?? const []).whereType<Map<String, Object?>>())
          ReplacementRuleMapper.fromMap(item),
      ],
    );
  }

  Future<void> _save(VocabularyData data) => _store.write('vocabulary', {
    'terms': [for (final t in data.terms) t.toMap()],
    'rules': [for (final r in data.rules) r.toMap()],
  });

  Future<VocabularyData> addTerm(String term, {TermSource source = TermSource.manual}) async {
    final data = await load();
    final clean = term.trim();
    if (clean.isEmpty || data.terms.any((t) => t.term.toLowerCase() == clean.toLowerCase())) return data;
    final updated = (
      terms: [
        ...data.terms,
        VocabularyTerm(term: clean, source: source, addedAt: DateTime.now()),
      ],
      rules: data.rules,
    );
    await _save(updated);
    return updated;
  }

  Future<VocabularyData> removeTerm(String term) async {
    final data = await load();
    final updated = (terms: data.terms.where((t) => t.term != term).toList(), rules: data.rules);
    await _save(updated);
    return updated;
  }

  Future<VocabularyData> addRule(String from, String to, {TermSource source = TermSource.manual}) async {
    final data = await load();
    final cleanFrom = from.trim();
    final cleanTo = to.trim();
    if (cleanFrom.isEmpty || cleanTo.isEmpty) return data;
    final updated = (
      terms: data.terms,
      rules: [
        ...data.rules.where((r) => r.from.toLowerCase() != cleanFrom.toLowerCase()),
        ReplacementRule(from: cleanFrom, to: cleanTo, source: source, addedAt: DateTime.now()),
      ],
    );
    await _save(updated);
    return updated;
  }

  Future<VocabularyData> removeRule(String from) async {
    final data = await load();
    final updated = (terms: data.terms, rules: data.rules.where((r) => r.from != from).toList());
    await _save(updated);
    return updated;
  }

  /// Bumps usage counts so frequently used terms win the limited transcription prompt.
  Future<void> recordHits(Iterable<String> terms) async {
    final used = terms.map((t) => t.toLowerCase()).toSet();
    if (used.isEmpty) return;
    final data = await load();
    await _save((
      terms: [for (final t in data.terms) used.contains(t.term.toLowerCase()) ? t.copyWith(hits: t.hits + 1) : t],
      rules: data.rules,
    ));
  }
}
