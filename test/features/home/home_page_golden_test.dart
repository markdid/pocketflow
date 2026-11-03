@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/data/repositories/vocabulary_repository.dart';
import 'package:pocketflow/dictation/dictation_style.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/features/home/home_page.dart';
import 'package:pocketflow/features/home/state/home_notifiers.dart';
import 'package:pocketflow/features/settings/state/settings_notifier.dart';
import 'package:pocketflow/features/vocabulary/state/vocabulary_notifier.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/platform/desktop_dictation.dart';
import 'package:pocketflow/platform/voice_level.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

import '../../helpers/golden_test_helper.dart';

class FakeHistoryNotifier extends HistoryNotifier {
  FakeHistoryNotifier(this._load);

  final Future<List<HistoryEntry>> Function() _load;

  @override
  Future<List<HistoryEntry>> build() => _load();
}

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<SettingsState> build() async => const SettingsState(settings: AppSettings(), apiKey: 'gsk_test');
}

class FakeVocabularyNotifier extends VocabularyNotifier {
  @override
  Future<VocabularyData> build() async => (terms: const <VocabularyTerm>[], rules: const <ReplacementRule>[]);
}

/// The page picks Android or macOS controls from the host platform; pin both off so goldens match everywhere.
class FakeAndroidStatusNotifier extends AndroidStatusNotifier {
  @override
  Future<AndroidStatus?> build() async => null;
}

class FakeDesktopDictationNotifier extends DesktopDictationNotifier {
  @override
  DesktopDictationState? build() => null;
}

class FakePlaybackNotifier extends PlaybackNotifier {
  @override
  Playback? build() => null;
}

// Relative to now, so the cards always read "4m" and "3h".
final _now = DateTime.now();

final _history = [
  HistoryEntry(
    id: '1',
    createdAt: _now.subtract(const Duration(minutes: 4)),
    mode: DictationMode.dictation,
    style: DictationStyle.chat,
    rawText: 'um can we push the sync to thursday no wait friday',
    text: 'Can we push the sync to Friday?',
    appId: 'com.whatsapp',
    audioMillis: 3000,
  ),
  HistoryEntry(
    id: '2',
    createdAt: _now.subtract(const Duration(hours: 3)),
    mode: DictationMode.memo,
    style: DictationStyle.memo,
    rawText: '',
    text: 'Thanks for sending the draft over. I read it on my walk and I love the direction.',
    audioMillis: 9000,
  ),
];

Widget _page(Future<List<HistoryEntry>> Function() load) => ProviderScope(
  overrides: [
    historyProvider.overrideWith(() => FakeHistoryNotifier(load)),
    settingsProvider.overrideWith(FakeSettingsNotifier.new),
    vocabularyProvider.overrideWith(FakeVocabularyNotifier.new),
    androidStatusProvider.overrideWith(FakeAndroidStatusNotifier.new),
    desktopDictationProvider.overrideWith(FakeDesktopDictationNotifier.new),
    playbackProvider.overrideWith(FakePlaybackNotifier.new),
    voiceLevelProvider.overrideWithValue(ValueNotifier<double>(0)),
  ],
  retry: (_, _) => null,
  child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppThemeData.light, home: const HomePage()),
);

void main() {
  // The orb and the loading spinner animate forever, so every state pumps a fixed time instead of settling.
  const pump = Duration(milliseconds: 500);

  testWidgets('data', (tester) async {
    await expectGoldenAcrossScreenSizes(
      tester,
      widget: _page(() async => _history),
      goldenFileName: 'home_page_data',
      pumpDuration: pump,
    );
  });

  testWidgets('empty', (tester) async {
    await expectGoldenAcrossScreenSizes(
      tester,
      widget: _page(() async => []),
      goldenFileName: 'home_page_empty',
      pumpDuration: pump,
    );
  });

  testWidgets('loading', (tester) async {
    await expectGoldenAcrossScreenSizes(
      tester,
      widget: _page(() => Completer<List<HistoryEntry>>().future),
      goldenFileName: 'home_page_loading',
      pumpDuration: pump,
    );
  });

  testWidgets('error', (tester) async {
    await expectGoldenAcrossScreenSizes(
      tester,
      widget: _page(() async => throw Exception('Could not read history')),
      goldenFileName: 'home_page_error',
      pumpDuration: pump,
    );
  });
}
