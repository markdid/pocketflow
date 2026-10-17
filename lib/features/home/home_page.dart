import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/features/home/state/home_notifiers.dart';
import 'package:pocketflow/features/home/views/home_view.dart';
import 'package:pocketflow/features/settings/state/settings_notifier.dart';
import 'package:pocketflow/features/vocabulary/state/vocabulary_notifier.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/platform/desktop_dictation.dart';
import 'package:pocketflow/platform/voice_level.dart';
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
      ref.read(desktopDictationProvider.notifier).refreshPermissions();
      ref.read(historyProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final android = ref.watch(androidStatusProvider).value;
    final desktop = ref.watch(desktopDictationProvider);
    final activity = ref.watch(dictationActivityProvider);
    final learned = ref.watch(vocabularyProvider).value?.terms.where((t) => t.source == TermSource.learned).length;
    final apiKey = ref.watch(settingsProvider).value?.apiKey ?? '';
    final bridge = ref.read(androidBridgeProvider);
    final statusNotifier = ref.read(androidStatusProvider.notifier);

    return Scaffold(
      body: history.when(
        loading: () => const ViewShell.loading(),
        error: (error, _) => ViewShell.error(message: error.toString(), onRetry: () => ref.invalidate(historyProvider)),
        data: (entries) => HomeView(
          state: activity.state,
          ready: activity.ready,
          message: activity.message,
          hint: desktop != null
              ? 'Or hold Right ⌥ Option in any app. Release to insert.'
              : 'Or use the bubble, the voice keyboard, the quick tile, or Caps Lock.',
          level: ref.watch(voiceLevelProvider),
          setupSteps: _setupSteps(context, apiKey: apiKey, android: android, bridge: bridge, desktop: desktop),
          stats: _stats(entries, learned ?? 0),
          history: entries,
          onOrbTap: () {
            HapticFeedback.mediumImpact();
            if (desktop != null) {
              ref.read(desktopDictationProvider.notifier).toggle();
            } else {
              bridge.toggleDictation();
            }
          },
          phone: android == null
              ? null
              : PhoneControls(
                  armed: android.armed,
                  walkMode: android.walkMode,
                  headsetAvailable: android.bluetoothMicAvailable,
                  onArmedChanged: (value) => statusNotifier.setArmed(armed: value),
                  onWalkModeChanged: (value) => statusNotifier.setWalkMode(enabled: value),
                ),
          onCopy: (entry) => _copy(context, entry),
          onDelete: (entry) => _confirmDelete(context, entry),
        ),
      ),
    );
  }

  /// Typing runs about 40 words a minute; whatever speaking took less than that is time saved.
  HomeStats _stats(List<HistoryEntry> entries, int learned) {
    var words = 0;
    var spokenMillis = 0;
    for (final entry in entries) {
      words += entry.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      spokenMillis += entry.audioMillis ?? 0;
    }
    final saved = (words / 40 - spokenMillis / 60000).round();
    return HomeStats(words: words, minutesSaved: saved < 0 ? 0 : saved, learned: learned);
  }

  List<SetupStep> _setupSteps(
    BuildContext context, {
    required String apiKey,
    required AndroidStatus? android,
    required AndroidBridge bridge,
    required DesktopDictationState? desktop,
  }) {
    final desktopNotifier = ref.read(desktopDictationProvider.notifier);
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
      if (desktop != null) ...[
        SetupStep(
          title: 'Allow the microphone',
          subtitle: 'To hear you while you hold the dictation key.',
          done: desktop.microphone,
          onTap: desktopNotifier.requestMicrophone,
        ),
        SetupStep(
          title: 'Allow Accessibility',
          subtitle: 'Lets PocketFlow notice the dictation key and paste into the app you’re using.',
          done: desktop.accessibility,
          onTap: desktopNotifier.requestAccessibility,
        ),
      ],
    ];
  }

  Future<void> _copy(BuildContext context, HistoryEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.text));
    if (!context.mounted) return;
    unawaited(HapticFeedback.selectionClick());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
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
