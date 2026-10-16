import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/data/repositories/history_repository.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/platform/android_bridge.dart';

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
