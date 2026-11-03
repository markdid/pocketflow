import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketflow/data/repositories/history_repository.dart';
import 'package:pocketflow/dictation/dictation_pipeline.dart';
import 'package:pocketflow/dictation/dictation_style.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/features/home/state/home_notifiers.dart';

import '../../../helpers/mocks.dart';

class MockDictationPipeline extends Mock implements DictationPipeline {}

HistoryEntry _entry(String id) => HistoryEntry(
  id: id,
  createdAt: DateTime(2026, 10, 22),
  mode: DictationMode.dictation,
  style: DictationStyle.standard,
  rawText: 'hello',
  text: 'Hello.',
);

void main() {
  late MockHistoryRepository history;
  late MockDictationPipeline pipeline;
  late ProviderContainer container;

  setUp(() {
    history = MockHistoryRepository();
    pipeline = MockDictationPipeline();
    container = ProviderContainer.test(
      overrides: [
        historyRepositoryProvider.overrideWithValue(history),
        dictationPipelineProvider.overrideWithValue(pipeline),
      ],
      retry: (_, _) => null,
    );
  });

  group('HistoryNotifier', () {
    test('loads the history', () async {
      when(history.load).thenAnswer((_) async => [_entry('1')]);

      expect(await container.read(historyProvider.future), [_entry('1')]);
    });

    test('surfaces a failed load as an error', () async {
      when(history.load).thenThrow(Exception('disk full'));
      container.listen(historyProvider, (_, _) {});

      await expectLater(container.read(historyProvider.future), throwsException);
      expect(container.read(historyProvider).hasError, isTrue);
    });

    test('remove deletes the entry and reloads', () async {
      when(history.load).thenAnswer((_) async => [_entry('1'), _entry('2')]);
      container.listen(historyProvider, (_, _) {});
      await container.read(historyProvider.future);

      when(() => history.remove('1')).thenAnswer((_) async {});
      when(history.load).thenAnswer((_) async => [_entry('2')]);
      await container.read(historyProvider.notifier).remove('1');

      verify(() => history.remove('1')).called(1);
      expect(container.read(historyProvider).value, [_entry('2')]);
    });
  });

  group('RetryingNotifier', () {
    setUp(() => when(history.load).thenAnswer((_) async => [_entry('1')]));

    test('marks the entry as retrying until the pipeline finishes', () async {
      final done = Completer<DictationResult>();
      when(() => pipeline.retry('1')).thenAnswer((_) => done.future);
      container.listen(historyProvider, (_, _) {});

      final retry = container.read(retryingProvider.notifier).retry('1');
      expect(container.read(retryingProvider), {'1'});

      done.complete(DictationResult(text: 'Hello.', entry: _entry('1')));
      await retry;
      expect(container.read(retryingProvider), isEmpty);
      verify(history.load).called(greaterThanOrEqualTo(1));
    });

    test('ignores a second retry of the same entry', () async {
      final done = Completer<DictationResult>();
      when(() => pipeline.retry('1')).thenAnswer((_) => done.future);

      final first = container.read(retryingProvider.notifier).retry('1');
      await container.read(retryingProvider.notifier).retry('1');
      done.complete(const DictationResult(text: '', entry: null));
      await first;

      verify(() => pipeline.retry('1')).called(1);
    });

    test('rethrows a failure and clears the retrying state', () async {
      when(() => pipeline.retry('1')).thenThrow(Exception('offline'));

      await expectLater(container.read(retryingProvider.notifier).retry('1'), throwsException);
      expect(container.read(retryingProvider), isEmpty);
    });
  });
}
