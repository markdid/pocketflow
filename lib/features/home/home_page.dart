import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/features/home/state/home_notifiers.dart';
import 'package:pocketflow/features/home/views/home_view.dart';
import 'package:pocketflow/features/settings/state/settings_notifier.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/router/router.dart';
import 'package:pocketflow/ui/widgets/structure/view_shell.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from system settings (accessibility, keyboards, permissions).
    if (state == AppLifecycleState.resumed) {
      ref.read(androidStatusProvider.notifier).refresh();
      ref.read(historyProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final android = ref.watch(androidStatusProvider).value;
    final apiKey = ref.watch(settingsProvider).value?.apiKey ?? '';
    final bridge = ref.read(androidBridgeProvider);
    final statusNotifier = ref.read(androidStatusProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('PocketFlow')),
      body: history.when(
        loading: () => const ViewShell.loading(),
        error: (error, _) => ViewShell.error(message: error.toString(), onRetry: () => ref.invalidate(historyProvider)),
        data: (entries) => HomeView(
          setupSteps: _setupSteps(context, apiKey: apiKey, android: android, bridge: bridge),
          history: entries,
          android: android,
          onArmedChanged: (value) => statusNotifier.setArmed(armed: value),
          onWalkModeChanged: (value) => statusNotifier.setWalkMode(enabled: value),
          onDictate: bridge.toggleDictation,
          desktopHint: Platform.isMacOS ? 'Hold Right ⌥ Option anywhere to dictate. Release to insert.' : null,
          onCopy: (entry) => _copy(context, entry),
          onDelete: (entry) => _confirmDelete(context, entry),
        ),
      ),
    );
  }

  List<SetupStep> _setupSteps(
    BuildContext context, {
    required String apiKey,
    required AndroidStatus? android,
    required AndroidBridge bridge,
  }) {
    return [
      SetupStep(
        title: 'Add your Groq API key',
        subtitle: 'Free at console.groq.com. Your key stays on this device.',
        done: apiKey.isNotEmpty,
        onTap: () => context.go(AppRoute.settings.path),
      ),
      if (android != null) ...[
        SetupStep(
          title: 'Allow microphone and notifications',
          subtitle: 'To hear you, and to show the dictation controls.',
          done: android.micPermission && android.notificationPermission,
          onTap: bridge.requestPermissions,
        ),
        SetupStep(
          title: 'Turn on PocketFlow accessibility',
          subtitle: 'Inserts text into any app, shows the mic bubble, and handles keyboard hotkeys.',
          done: android.accessibilityEnabled,
          onTap: bridge.openAccessibilitySettings,
        ),
        SetupStep(
          title: 'Enable the PocketFlow keyboard (optional)',
          subtitle: 'A voice keyboard you can switch to, and the way text reaches remote desktop apps.',
          done: android.keyboardEnabled,
          onTap: bridge.openKeyboardSettings,
        ),
      ],
    ];
  }

  Future<void> _copy(BuildContext context, HistoryEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  Future<void> _confirmDelete(BuildContext context, HistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(entry.audioPath != null ? 'The recording is deleted too.' : 'This can’t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await ref.read(historyProvider.notifier).remove(entry.id);
  }
}
