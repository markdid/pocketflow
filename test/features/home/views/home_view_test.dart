import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/dictation/dictation_style.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/features/home/views/home_view.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

final _done = HistoryEntry(
  id: '1',
  createdAt: DateTime.now(),
  mode: DictationMode.dictation,
  style: DictationStyle.standard,
  rawText: 'um see you friday',
  text: 'See you Friday.',
);

final _failed = HistoryEntry(
  id: '2',
  createdAt: DateTime.now(),
  mode: DictationMode.memo,
  style: DictationStyle.memo,
  rawText: '',
  text: '',
  audioPath: '/memos/recording.m4a',
  audioMillis: 65000,
  error: 'Couldn’t reach the API.',
);

Future<void> _pump(
  WidgetTester tester, {
  List<HistoryEntry> history = const [],
  List<SetupStep> setupSteps = const [],
  Set<String> retrying = const {},
  ValueChanged<HistoryEntry>? onCopy,
  ValueChanged<HistoryEntry>? onRetry,
}) async {
  // Wide enough for the Ahem test font, whose glyphs are full squares.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppThemeData.light,
      home: Scaffold(
        body: HomeView(
          state: DictationState.idle,
          ready: true,
          message: '',
          hint: 'Hold Right Option',
          setupSteps: setupSteps,
          stats: const HomeStats(words: 12, minutesSaved: 3, learned: 1),
          history: history,
          retrying: retrying,
          onOrbTap: () {},
          onCopy: onCopy ?? (_) {},
          onRetry: onRetry ?? (_) {},
          onDelete: (_) {},
        ),
      ),
    ),
  );
  // The orb animates forever, so pump a frame instead of settling.
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('tapping a transcribed entry copies it', (tester) async {
    HistoryEntry? copied;
    await _pump(tester, history: [_done], onCopy: (entry) => copied = entry);

    await tester.tap(find.text('See you Friday.'));

    expect(copied, _done);
  });

  testWidgets('a failed entry offers a retry', (tester) async {
    HistoryEntry? retried;
    await _pump(tester, history: [_failed], onRetry: (entry) => retried = entry);

    expect(find.text('Not transcribed yet · 1:05'), findsOneWidget);
    await tester.tap(find.text('Try again'));

    expect(retried, _failed);
  });

  testWidgets('an entry being retried shows progress instead of the button', (tester) async {
    await _pump(tester, history: [_failed], retrying: {'2'});

    expect(find.text('Transcribing…'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('the setup card shows only while a step is pending', (tester) async {
    const pending = SetupStep(title: 'Add your Groq API key', subtitle: '', done: false);
    const done = SetupStep(title: 'Allow the microphone', subtitle: '', done: true);

    await _pump(tester, setupSteps: [pending, done]);
    expect(find.text('Add your Groq API key'), findsOneWidget);

    await _pump(tester, setupSteps: [done]);
    expect(find.text('Allow the microphone'), findsNothing);
  });
}
