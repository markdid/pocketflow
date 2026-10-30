import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/data/repositories/history_repository.dart';
import 'package:pocketflow/dictation/dictation_pipeline.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/features/settings/state/settings_notifier.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/platform/desktop_dictation.dart';

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);

class HistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  @override
  Future<List<HistoryEntry>> build() => ref.watch(historyRepositoryProvider).load();

  Future<void> refresh() async {
    final result = await AsyncValue.guard(ref.read(historyRepositoryProvider).load);
    if (!ref.mounted) return;
    state = result;
  }

  Future<void> remove(String id) async {
    await ref.read(historyRepositoryProvider).remove(id);
    await refresh();
  }
}

final retryingProvider = NotifierProvider<RetryingNotifier, Set<String>>(RetryingNotifier.new);

/// Ids of history entries whose saved recording is being transcribed again.
class RetryingNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Returns the transcript, empty if nothing was said, or null if [id] is already being transcribed. Rethrows the
  /// failure; the entry keeps its recording either way.
  Future<String?> retry(String id) async {
    if (state.contains(id)) return null;
    state = {...state, id};
    try {
      return (await ref.read(dictationPipelineProvider).retry(id)).text;
    } finally {
      if (ref.mounted) {
        state = {...state}..remove(id);
        await ref.read(historyProvider.notifier).refresh();
      }
    }
  }
}

typedef Playback = ({String id, bool playing});

final playbackProvider = NotifierProvider<PlaybackNotifier, Playback?>(PlaybackNotifier.new);

/// Plays saved recordings, one at a time. Null when nothing is loaded.
class PlaybackNotifier extends Notifier<Playback?> {
  late AudioPlayer _player;

  /// Where the current recording is. A notifier rather than state, so position ticks don't rebuild pages.
  final position = ValueNotifier<Duration>(Duration.zero);

  @override
  Playback? build() {
    final player = _player = AudioPlayer();
    final subscriptions = [
      player.onPositionChanged.listen((value) => position.value = value),
      player.onPlayerComplete.listen((_) {
        position.value = Duration.zero;
        state = null;
      }),
    ];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
      unawaited(player.dispose());
    });
    return null;
  }

  /// Plays [entry]'s recording from the start, or pauses / resumes it if it's the one loaded.
  Future<void> toggle(HistoryEntry entry) async {
    final path = entry.audioPath;
    final current = state;
    if (path == null) return;
    if (current?.id == entry.id) {
      state = (id: entry.id, playing: !current!.playing);
      await (current.playing ? _player.pause() : _player.resume());
      return;
    }
    position.value = Duration.zero;
    state = (id: entry.id, playing: true);
    await _player.play(DeviceFileSource(path));
  }

  Future<void> seek(Duration to) async {
    position.value = to;
    await _player.seek(to);
  }

  /// Before the entry's recording is deleted.
  Future<void> release(String id) async {
    if (state?.id != id) return;
    state = null;
    position.value = Duration.zero;
    await _player.release();
  }
}

final androidStatusProvider = AsyncNotifierProvider<AndroidStatusNotifier, AndroidStatus?>(AndroidStatusNotifier.new);

/// Live status of the Android services. Null on other platforms.
class AndroidStatusNotifier extends AsyncNotifier<AndroidStatus?> {
  @override
  Future<AndroidStatus?> build() async {
    if (!Platform.isAndroid) return null;
    final bridge = ref.watch(androidBridgeProvider);
    final subscription = bridge.events().listen((event) {
      switch (event['type']) {
        case 'status':
          unawaited(refresh());
        case 'history':
          unawaited(ref.read(historyProvider.notifier).refresh());
      }
    });
    ref.onDispose(subscription.cancel);
    return bridge.status();
  }

  /// Permissions and accessibility can change while the app is in the background, so re-read on resume.
  Future<void> refresh() async {
    final result = await AsyncValue.guard(ref.read(androidBridgeProvider).status);
    if (!ref.mounted) return;
    state = result;
  }

  Future<void> setArmed({required bool armed}) async {
    await ref.read(androidBridgeProvider).setArmed(armed: armed);
    await refresh();
  }

  Future<void> setWalkMode({required bool enabled}) async {
    await ref.read(androidBridgeProvider).setWalkMode(enabled: enabled);
    await refresh();
  }
}

/// [audioOnly]: the active recording is saved without transcribing.
typedef DictationActivity = ({DictationState state, bool ready, String message, bool audioOnly});

/// What dictation is doing right now on this platform, for the orb and the status line.
final dictationActivityProvider = Provider<DictationActivity>((ref) {
  final hasKey = (ref.watch(settingsProvider).value?.apiKey ?? '').isNotEmpty;
  final android = ref.watch(androidStatusProvider).value;
  if (android != null) {
    return (
      state: android.state,
      ready: hasKey && android.micPermission && android.accessibilityEnabled,
      message: android.message,
      audioOnly: android.audioOnly,
    );
  }
  final desktop = ref.watch(desktopDictationProvider);
  if (desktop != null) {
    return (
      state: desktop.state,
      ready: hasKey && desktop.microphone && desktop.accessibility,
      message: desktop.message,
      audioOnly: desktop.audioOnly,
    );
  }
  return (state: DictationState.idle, ready: hasKey, message: '', audioOnly: false);
});
