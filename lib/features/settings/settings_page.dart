import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/features/home/state/home_notifiers.dart';
import 'package:pocketflow/features/settings/state/settings_notifier.dart';
import 'package:pocketflow/features/settings/views/settings_view.dart';
import 'package:pocketflow/ui/widgets/structure/view_shell.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final android = ref.watch(androidStatusProvider).value;

    return Scaffold(
      body: settings.when(
        loading: () => const ViewShell.loading(),
        error: (error, _) =>
            ViewShell.error(message: error.toString(), onRetry: () => ref.invalidate(settingsProvider)),
        data: (state) => SettingsView(
          settings: state.settings,
          apiKey: state.apiKey,
          onSettingsChanged: notifier.updateSettings,
          onApiKeyChanged: notifier.setApiKey,
          device: state.device,
          onDeviceChanged: notifier.updateDevice,
          walkMode: android?.walkMode ?? false,
          onWalkModeChanged: android == null
              ? null
              : (value) => ref.read(androidStatusProvider.notifier).setWalkMode(enabled: value),
        ),
      ),
    );
  }
}
