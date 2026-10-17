import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketflow/dictation/dictation_style.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/ui/formatting/app_names.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';
import 'package:pocketflow/ui/widgets/effects/glass.dart';
import 'package:pocketflow/ui/widgets/effects/voice_orb.dart';

class SetupStep {
  const SetupStep({required this.title, required this.subtitle, required this.done, this.onTap});

  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onTap;
}

class HomeStats {
  const HomeStats({required this.words, required this.minutesSaved, required this.learned});

  final int words;
  final int minutesSaved;
  final int learned;
}

/// Android-only controls shown under the orb.
class PhoneControls {
  const PhoneControls({
    required this.armed,
    required this.walkMode,
    required this.headsetAvailable,
    required this.onArmedChanged,
    required this.onWalkModeChanged,
  });

  final bool armed;
  final bool walkMode;
  final bool headsetAvailable;
  final ValueChanged<bool> onArmedChanged;
  final ValueChanged<bool> onWalkModeChanged;
}

class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.state,
    required this.ready,
    required this.message,
    required this.hint,
    required this.setupSteps,
    required this.stats,
    required this.history,
    required this.onOrbTap,
    required this.onCopy,
    required this.onDelete,
    this.level,
    this.phone,
  });

  final DictationState state;
  final bool ready;
  final String message;

  /// How to dictate on this platform, shown under the orb when there's nothing else to say.
  final String hint;
  final List<SetupStep> setupSteps;
  final HomeStats stats;
  final List<HistoryEntry> history;
  final VoidCallback onOrbTap;
  final ValueChanged<HistoryEntry> onCopy;
  final ValueChanged<HistoryEntry> onDelete;
  final ValueListenable<double>? level;
  final PhoneControls? phone;

  @override
  Widget build(BuildContext context) {
    final pending = setupSteps.where((s) => !s.done).length;
    final phone = this.phone;

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverList.list(
              children: [
                _Header(phone: phone),
                if (pending > 0) ...[const SizedBox(height: 20), _SetupCard(steps: setupSteps)],
                const SizedBox(height: 8),
                _OrbSection(state: state, ready: ready, message: message, hint: hint, level: level, onTap: onOrbTap),
                const SizedBox(height: 28),
                _StatsRow(stats: stats),
                if (phone != null) ...[const SizedBox(height: 14), _WalkModeCard(phone: phone)],
                const SizedBox(height: 36),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Recent', style: AppThemeData.serif(30)),
                    const SizedBox(width: 10),
                    if (history.isNotEmpty)
                      Text('${history.length}', style: AppThemeData.mono(13, color: AppColors.textFaint)),
                  ],
                ),
                const SizedBox(height: 14),
                if (history.isEmpty) const _EmptyHistory(),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
          sliver: SliverList.separated(
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = history[index];
              return _HistoryCard(entry: entry, onCopy: () => onCopy(entry), onDelete: () => onDelete(entry));
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.phone});

  final PhoneControls? phone;

  @override
  Widget build(BuildContext context) {
    final phone = this.phone;
    return Row(
      children: [
        Text('PocketFlow', style: AppThemeData.serif(36)),
        const Spacer(),
        if (phone != null) _ReadyPill(on: phone.armed, onChanged: phone.onArmedChanged),
      ],
    );
  }
}

/// "Ready" / "Off" toggle for the background service, with a glowing status dot.
class _ReadyPill extends StatelessWidget {
  const _ReadyPill({required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.mint : AppColors.textFaint;
    return Semantics(
      toggled: on,
      label: 'Ready to dictate',
      child: GestureDetector(
        onTap: () => onChanged(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: on ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withValues(alpha: on ? 0.35 : 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: on ? [BoxShadow(color: color, blurRadius: 8, spreadRadius: 1)] : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(on ? 'Ready' : 'Off', style: AppThemeData.geist(13, weight: 560, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbSection extends StatelessWidget {
  const _OrbSection({
    required this.state,
    required this.ready,
    required this.message,
    required this.hint,
    required this.onTap,
    this.level,
  });

  final DictationState state;
  final bool ready;
  final String message;
  final String hint;
  final VoidCallback onTap;
  final ValueListenable<double>? level;

  @override
  Widget build(BuildContext context) {
    final mode = switch (state) {
      DictationState.listening => OrbMode.listening,
      DictationState.transcribing => OrbMode.processing,
      _ => ready ? OrbMode.idle : OrbMode.asleep,
    };
    final title = switch (state) {
      DictationState.listening => 'Listening…',
      DictationState.transcribing => 'Writing…',
      DictationState.error => 'Hmm.',
      DictationState.idle => ready ? 'Tap to speak' : 'Almost there',
    };
    final subtitle = message.isNotEmpty ? message : (ready ? hint : 'Finish the steps above to start dictating.');

    return Column(
      children: [
        VoiceOrb(
          mode: mode,
          level: level,
          size: 280,
          onTap: onTap,
          semanticLabel: state == DictationState.listening ? 'Finish dictating' : 'Start dictating',
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(title, key: ValueKey(title), style: AppThemeData.serif(40)),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            subtitle,
            key: ValueKey(subtitle),
            textAlign: TextAlign.center,
            style: AppThemeData.geist(
              14,
              color: state == DictationState.error ? AppColors.coral : AppColors.textMuted,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Stat(value: _compact(stats.words), label: 'words'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(value: _compact(stats.minutesSaved), label: 'min saved'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(value: _compact(stats.learned), label: 'words learned'),
        ),
      ],
    );
  }

  static String _compact(int value) => value >= 10000
      ? '${(value / 1000).round()}k'
      : (value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : '$value');
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraText(value, style: AppThemeData.serif(34, height: 1)),
          const SizedBox(height: 4),
          Text(label, style: AppThemeData.geist(12, color: AppColors.textFaint)),
        ],
      ),
    );
  }
}

class _WalkModeCard extends StatelessWidget {
  const _WalkModeCard({required this.phone});

  final PhoneControls phone;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glow: phone.walkMode,
      onTap: () => phone.onWalkModeChanged(!phone.walkMode),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: phone.walkMode ? const LinearGradient(colors: [AppColors.violet, AppColors.magenta]) : null,
              color: phone.walkMode ? null : const Color(0x14FFFFFF),
            ),
            child: const Padding(
              padding: EdgeInsets.all(11),
              child: Icon(Icons.headphones_rounded, size: 22, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Walk mode', style: AppThemeData.geist(16, weight: 580)),
                const SizedBox(height: 3),
                Text(
                  phone.headsetAvailable
                      ? 'Press your headset button to record a memo. Phone stays in your pocket.'
                      : 'Connect a Bluetooth headset, then press its button to record a memo.',
                  style: AppThemeData.geist(13, color: AppColors.textMuted, height: 1.35),
                ),
              ],
            ),
          ),
          Switch(value: phone.walkMode, onChanged: phone.onWalkModeChanged),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.steps});

  final List<SetupStep> steps;

  @override
  Widget build(BuildContext context) {
    final done = steps.where((s) => s.done).length;
    return GlassCard(
      glow: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Set up', style: AppThemeData.serif(28)),
              const Spacer(),
              Text('$done of ${steps.length}', style: AppThemeData.mono(12)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 4, color: const Color(0x14FFFFFF)),
                FractionallySizedBox(
                  widthFactor: steps.isEmpty ? 0 : done / steps.length,
                  child: Container(height: 4, decoration: const BoxDecoration(gradient: AppColors.auroraLinear)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final step in steps) _SetupRow(step: step),
        ],
      ),
    );
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({required this.step});

  final SetupStep step;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: step.done ? null : step.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: step.done
                  ? const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.mint)
                  : const Icon(Icons.radio_button_unchecked_rounded, size: 20, color: AppColors.textFaint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: AppThemeData.geist(
                      15,
                      weight: 560,
                      color: step.done ? AppColors.textFaint : AppColors.text,
                    ).copyWith(decoration: step.done ? TextDecoration.lineThrough : null),
                  ),
                  if (!step.done) ...[
                    const SizedBox(height: 2),
                    Text(step.subtitle, style: AppThemeData.geist(13, color: AppColors.textMuted, height: 1.35)),
                  ],
                ],
              ),
            ),
            if (!step.done && step.onTap != null)
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.onCopy, required this.onDelete});

  final HistoryEntry entry;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final memo = entry.mode == DictationMode.memo;
    final appId = entry.appId;
    return GlassCard(
      onTap: onCopy,
      onLongPress: onDelete,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (memo)
                const GlassChip(label: 'Memo', icon: Icons.graphic_eq_rounded, color: AppColors.magenta)
              else if (appId != null)
                GlassChip(label: appDisplayName(appId), color: AppColors.cyan),
              if (!memo && entry.style != DictationStyle.standard) ...[
                const SizedBox(width: 6),
                GlassChip(label: entry.style.label),
              ],
              const Spacer(),
              Text(_relativeTime(context, entry.createdAt), style: AppThemeData.geist(12, color: AppColors.textFaint)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.text,
            maxLines: memo ? 8 : 5,
            overflow: TextOverflow.ellipsis,
            style: AppThemeData.geist(15.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(BuildContext context, DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return MaterialLocalizations.of(context).formatShortMonthDay(time);
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'Everything you dictate lands here. Tap a card to copy it.',
        style: AppThemeData.geist(14, color: AppColors.textFaint),
      ),
    );
  }
}

final _previewHistory = [
  HistoryEntry(
    id: '1',
    createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
    mode: DictationMode.dictation,
    style: DictationStyle.chat,
    rawText: 'um can we push the sync to thursday no wait friday',
    text: 'Can we push the sync to Friday?',
    appId: 'com.whatsapp',
  ),
  HistoryEntry(
    id: '2',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    mode: DictationMode.memo,
    style: DictationStyle.memo,
    rawText: '',
    text: 'Hi Sinead,\n\nThanks for sending the draft over. I read it on my walk and I love the direction.',
  ),
];

@AppPreview(group: 'Home', size: Size(390, 1400))
Widget homeViewPreview() => HomeView(
  state: DictationState.idle,
  ready: true,
  message: '',
  hint: 'Or use the bubble, the voice keyboard, or Caps Lock.',
  setupSteps: const [],
  stats: const HomeStats(words: 1240, minutesSaved: 23, learned: 7),
  history: _previewHistory,
  onOrbTap: () {},
  onCopy: (_) {},
  onDelete: (_) {},
  phone: PhoneControls(
    armed: true,
    walkMode: true,
    headsetAvailable: true,
    onArmedChanged: (_) {},
    onWalkModeChanged: (_) {},
  ),
);

@AppPreview(group: 'Home', name: 'Setup', size: Size(390, 1200))
Widget homeViewSetupPreview() => HomeView(
  state: DictationState.idle,
  ready: false,
  message: '',
  hint: '',
  setupSteps: [
    SetupStep(title: 'Add your Groq API key', subtitle: 'Free at console.groq.com', done: false, onTap: () {}),
    const SetupStep(title: 'Allow the microphone', subtitle: 'Needed to hear you', done: true),
  ],
  stats: const HomeStats(words: 0, minutesSaved: 0, learned: 0),
  history: const [],
  onOrbTap: () {},
  onCopy: (_) {},
  onDelete: (_) {},
);
