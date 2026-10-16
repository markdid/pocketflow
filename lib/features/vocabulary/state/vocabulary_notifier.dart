import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/data/repositories/vocabulary_repository.dart';

final vocabularyProvider = AsyncNotifierProvider<VocabularyNotifier, VocabularyData>(VocabularyNotifier.new);

class VocabularyNotifier extends AsyncNotifier<VocabularyData> {
  @override
  Future<VocabularyData> build() => ref.watch(vocabularyRepositoryProvider).load();

  VocabularyRepository get _repository => ref.read(vocabularyRepositoryProvider);

  Future<void> _run(Future<VocabularyData> Function() action) async {
    final result = await AsyncValue.guard(action);
    if (!ref.mounted) return;
    state = result;
  }

  Future<void> addTerm(String term) => _run(() => _repository.addTerm(term));
  Future<void> removeTerm(String term) => _run(() => _repository.removeTerm(term));
  Future<void> addRule(String from, String to) => _run(() => _repository.addRule(from, to));
  Future<void> removeRule(String from) => _run(() => _repository.removeRule(from));
  Future<void> refresh() => _run(_repository.load);
}
