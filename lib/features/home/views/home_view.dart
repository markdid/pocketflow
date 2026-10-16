import 'package:flutter/material.dart';
import 'package:pocketflow/dictation/dictation_style.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/widgets/structure/view_shell.dart';

class SetupStep {
  const SetupStep({required this.title, required this.subtitle, required this.done, this.onTap});

  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onTap;
}

class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.setupSteps,
    required this.history,
    required this.onCopy,
    required this.onDelete,
    this.android,
    this.onArmedChanged,
    this.onWalkModeChanged,
    this.onDictate,
    this.desktopHint,
  });

  final List<SetupStep> setupSteps;
  final List<HistoryEntry> history;
  final ValueChanged<HistoryEntry> onCopy;
  final ValueChanged<HistoryEntry> onDelete;
  final AndroidStatus? android;
  final ValueChanged<bool>? onArmedChanged;
  final ValueChanged<bool>? onWalkModeChanged;
  final VoidCallback? onDictate;
  final String? desktopHint;

  @override
  Widget build(BuildContext context) {
    final pending = setupSteps.where((s) => !s.done).toList();
    final status = android;

    return ListView(
      padding: const EdgeInsets.all(ViewShell.padding),
      children: [
        if (pending.isNotEmpty) ...[_SetupCard(steps: setupSteps), const SizedBox(height: 16)],
        if (status != null) ...[
          _ControlsCard(
            status: status,
            onArmedChanged: onArmedChanged,
            onWalkModeChanged: onWalkModeChanged,
            onDictate: onDictate,
          ),
          const SizedBox(height: 16),
        ],
        if (desktopHint != null) ...[
          Card(
            child: ListTile(leading: const Icon(Icons.keyboard_alt_outlined), title: Text(desktopHint!)),
          ),
          const SizedBox(height: 16),
        ],
        Text('History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('Your dictations and memos will show up here.')),
          )
        else
          for (final entry in history)
            _HistoryTile(entry: entry, onCopy: () => onCopy(entry), onDelete: () => onDelete(entry)),
      ],
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.steps});

  final List<SetupStep> steps;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Finish setting up', style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final step in steps)
              ListTile(
                leading: Icon(
                  step.done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: step.done ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(step.title),
                subtitle: Text(step.subtitle),
                trailing: step.done || step.onTap == null ? null : const Icon(Icons.chevron_right),
                onTap: step.done ? null : step.onTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard({required this.status, this.onArmedChanged, this.onWalkModeChanged, this.onDictate});

  final AndroidStatus status;
  final ValueChanged<bool>? onArmedChanged;
  final ValueChanged<bool>? onWalkModeChanged;
  final VoidCallback? onDictate;

  @override
  Widget build(BuildContext context) {
    final busy = status.state == DictationState.listening || status.state == DictationState.transcribing;
    final label = switch (status.state) {
      DictationState.listening => 'Stop',
      DictationState.transcribing => 'Transcribing…',
      _ => 'Dictate',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Ready to dictate'),
              subtitle: const Text('Keeps PocketFlow running so hotkeys, the bubble, and the notification work.'),
              value: status.armed,
              onChanged: onArmedChanged,
            ),
            SwitchListTile(
              title: const Text('Walk mode'),
              subtitle: Text(
                status.bluetoothMicAvailable
                    ? 'Press your headset button to record a memo. Press again to finish.'
                    : 'Press your headset button to record a memo. Connect a Bluetooth headset to use its mic.',
              ),
              value: status.walkMode,
              onChanged: onWalkModeChanged,
            ),
            if (status.message.isNotEmpty)
              ListTile(
                dense: true,
                leading: Icon(status.state == DictationState.error ? Icons.error_outline : Icons.info_outline),
                title: Text(status.message),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: status.state == DictationState.transcribing ? null : onDictate,
                  icon: Icon(busy ? Icons.stop : Icons.mic),
                  label: Text(label),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.onCopy, required this.onDelete});

  final HistoryEntry entry;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final time =
        '${localizations.formatShortDate(entry.createdAt)} '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(entry.createdAt))}';
    final meta = [
      time,
      if (entry.mode == DictationMode.memo) 'Memo' else entry.style.label,
      if (entry.appId != null) entry.appId!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onCopy,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.text, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(meta, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(tooltip: 'Copy', icon: const Icon(Icons.copy_outlined), onPressed: onCopy),
            ],
          ),
        ),
      ),
    );
  }
}

final _previewHistory = [
  HistoryEntry(
    id: '1',
    createdAt: DateTime(2026, 10, 16, 9, 41),
    mode: DictationMode.dictation,
    style: DictationStyle.chat,
    rawText: 'um can we push the sync to thursday no wait friday',
    text: 'Can we push the sync to Friday?',
    appId: 'com.whatsapp',
  ),
  HistoryEntry(
    id: '2',
    createdAt: DateTime(2026, 10, 16, 8, 5),
    mode: DictationMode.memo,
    style: DictationStyle.memo,
    rawText: '',
    text: 'Hi Sinead,\n\nThanks for sending the draft over. I read it on my walk and I love the direction.',
  ),
];

@AppPreview(group: 'Home')
Widget homeViewPreview() => HomeView(
  setupSteps: const [],
  history: _previewHistory,
  onCopy: (_) {},
  onDelete: (_) {},
  android: const AndroidStatus(armed: true, walkMode: true, bluetoothMicAvailable: true),
  onArmedChanged: (_) {},
  onWalkModeChanged: (_) {},
  onDictate: () {},
);

@AppPreview(group: 'Home', name: 'Setup')
Widget homeViewSetupPreview() => HomeView(
  setupSteps: [
    SetupStep(title: 'Add your Groq API key', subtitle: 'Free at console.groq.com', done: false, onTap: () {}),
    const SetupStep(title: 'Allow the microphone', subtitle: 'Needed to hear you', done: true),
  ],
  history: const [],
  onCopy: (_) {},
  onDelete: (_) {},
);
