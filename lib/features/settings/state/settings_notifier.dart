import 'dart:io';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/data/repositories/settings_repository.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/platform/android_bridge.dart';

part 'settings_notifier.mapper.dart';

@MappableClass()
class SettingsState with SettingsStateMappable {
  const SettingsState({required this.settings, required this.apiKey, this.device});

  final AppSettings settings;
  final String apiKey;

  /// Android-only device settings.
  final AndroidDeviceSettings? device;
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final repository = ref.watch(settingsRepositoryProvider);
    return SettingsState(
      settings: await repository.load(),
      apiKey: await repository.apiKey(),
      device: Platform.isAndroid ? await ref.watch(androidBridgeProvider).deviceSettings() : null,
    );
  }

  Future<void> updateSettings(AppSettings settings) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(settings: settings));
    await ref.read(settingsRepositoryProvider).save(settings);
  }

  Future<void> setApiKey(String apiKey) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(apiKey: apiKey.trim()));
    await ref.read(settingsRepositoryProvider).setApiKey(apiKey);
  }

  Future<void> updateDevice(AndroidDeviceSettings device) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(device: device));
    await ref.read(androidBridgeProvider).saveDeviceSettings(device);
  }
}
