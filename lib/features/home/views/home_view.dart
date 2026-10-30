import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketflow/dictation/dictation_style.dart';
import 'package:pocketflow/dictation/models.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/ui/formatting/app_names.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';
import 'package:pocketflow/ui/widgets/effects/voice_orb.dart';
import 'package:pocketflow/ui/widgets/surface.dart';

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
    required this.onRetry,
    required this.onDelete,
    this.retrying = const {},
    this.level,
    this.phone,
    this.audioOnly = false,
    this.onRecord,
    this.playback,
    this.position,
    this.onPlay,
    this.onSeek,
    this.onShare,
  });

  final DictationState state;
  final bool ready;
  final String message;

  /// The active recording is a voice memo, saved without transcribing.
  final bool audioOnly;

  /// Starts or stops a voice memo. Null where recording isn't supported.
  final VoidCallback? onRecord;

  /// How to dictate on this platform, shown under the orb when there's nothing else to say.
  final String hint;
  final List<SetupStep> setupSteps;
  final HomeStats stats;
  final List<HistoryEntry> history;
  final VoidCallback onOrbTap;
  final ValueChanged<HistoryEntry> onCopy;

  /// Transcribes an entry's saved recording: a voice memo, or a failed attempt.
  final ValueChanged<HistoryEntry> onRetry;
  final ValueChanged<HistoryEntry> onDelete;

  /// Ids of entries being retried right now.
  final Set<String> retrying;
  final ValueListenable<double>? level;
  final PhoneControls? phone;

  /// The recording loaded in the player, if any, and where it's at.
  final ({String id, bool playing})? playback;
  final ValueListenable<Duration>? position;

  /// Plays, pauses, or resumes an entry's recording. Null hides the player.
  final ValueChanged<HistoryEntry>? onPlay;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<HistoryEntry>? onShare;

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
                _OrbSection(
                  state: state,
                  ready: ready,
                  message: message,
                  hint: hint,
                  level: level,
                  audioOnly: audioOnly,
                  onTap: onOrbTap,
                  onRecord: onRecord,
                ),
                const SizedBox(height: 28),
                _StatsRow(stats: stats),
                if (phone != null) ...[const SizedBox(height: 14), _WalkModeCard(phone: phone)],
                const SizedBox(height: 36),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Recent', style: AppThemeData.display(18)),
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
              final onPlay = this.onPlay;
              final onShare = this.onShare;
              final loaded = playback?.id == entry.id;
              return _HistoryCard(
                entry: entry,
                retrying: retrying.contains(entry.id),
                onCopy: () => onCopy(entry),
                onRetry: () => onRetry(entry),
                onDelete: () => onDelete(entry),
                player: entry.audioPath == null || onPlay == null
                    ? null
                    : _AudioPlayerRow(
                        playing: loaded && playback!.playing,
                        position: loaded ? position : null,
                        audioMillis: entry.audioMillis,
                        onPlay: () => onPlay(entry),
                        onSeek: loaded ? onSeek : null,
                        onShare: onShare == null ? null : () => onShare(entry),
                      ),
              );
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
        Text('PocketFlow', style: AppThemeData.display(26)),
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
    final color = on ? AppColors.text : AppColors.textFaint;
    final dot = on ? AppColors.accent : AppColors.textFaint;
    return Semantics(
      toggled: on,
      label: 'Ready to dictate',
      child: GestureDetector(
        onTap: () => onChanged(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(99),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
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
    this.audioOnly = false,
    this.onRecord,
  });

  final DictationState state;
  final bool ready;
  final String message;
  final String hint;
  final VoidCallback onTap;
  final ValueListenable<double>? level;
  final bool audioOnly;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final mode = switch (state) {
      DictationState.listening => OrbMode.listening,
      DictationState.transcribing => OrbMode.processing,
      _ => ready ? OrbMode.idle : OrbMode.asleep,
    };
    final recording = audioOnly && state == DictationState.listening;
    final onRecord = this.onRecord;
    final title = switch (state) {
      DictationState.listening => recording ? 'Recording…' : 'Listening…',
      DictationState.transcribing => 'Writing…',
      DictationState.error => 'Hmm.',
      DictationState.idle => ready ? 'Tap to speak' : 'Almost there',
    };
    final subtitle = message == title
        ? ''
        : (message.isNotEmpty ? message : (ready ? hint : 'Finish the steps above to start dictating.'));

    return Column(
      children: [
        VoiceOrb(
          mode: mode,
          level: level,
          size: 220,
          onTap: onTap,
          semanticLabel: recording
              ? 'Stop recording'
              : (state == DictationState.listening ? 'Finish dictating' : 'Start dictating'),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(title, key: ValueKey(title), style: AppThemeData.display(28)),
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
              color: state == DictationState.error ? AppColors.danger : AppColors.textMuted,
              height: 1.45,
            ),
          ),
        ),
        if (onRecord != null) ...[
          const SizedBox(height: 18),
          _VoiceMemoButton(
            recording: recording,
            onTap: recording || state == DictationState.idle || state == DictationState.error ? onRecord : null,
          ),
        ],
      ],
    );
  }
}

/// Records audio that's kept on the device and transcribed only on request.
class _VoiceMemoButton extends StatelessWidget {
  const _VoiceMemoButton({required this.recording, this.onTap});

  final bool recording;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? AppColors.textFaint : AppColors.text;
    return Semantics(
      button: true,
      label: recording ? 'Stop voice memo' : 'Record voice memo',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), boxShadow: AppColors.cardShadow),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (recording)
                  const Icon(Icons.stop_rounded, size: 18, color: AppColors.danger)
                else
                  Icon(Icons.mic_none_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Text(recording ? 'Stop' : 'Voice memo', style: AppThemeData.geist(14, weight: 560, color: color)),
              ],
            ),
          ),
        ),
      ),
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
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppThemeData.display(24, height: 1)),
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
    return SurfaceCard(
      onTap: () => phone.onWalkModeChanged(!phone.walkMode),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: phone.walkMode ? AppColors.accent.withValues(alpha: 0.1) : AppColors.surfaceHigh,
            ),
            child: Icon(
              Icons.headphones_rounded,
              size: 22,
              color: phone.walkMode ? AppColors.accent : AppColors.textMuted,
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
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Set up', style: AppThemeData.display(20)),
              const Spacer(),
              Text('$done of ${steps.length}', style: AppThemeData.mono(12)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 3, color: AppColors.surfaceHigh),
                FractionallySizedBox(
                  widthFactor: steps.isEmpty ? 0 : done / steps.length,
                  child: Container(height: 3, color: AppColors.text),
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
                  ? const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.textMuted)
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
  const _HistoryCard({
    required this.entry,
    required this.retrying,
    required this.onCopy,
    required this.onRetry,
    required this.onDelete,
    this.player,
  });

  final HistoryEntry entry;
  final bool retrying;
  final VoidCallback onCopy;
  final VoidCallback onRetry;
  final VoidCallback onDelete;
  final _AudioPlayerRow? player;

  @override
  Widget build(BuildContext context) {
    final memo = entry.mode != DictationMode.dictation;
    final appId = entry.appId;
    final error = entry.error;
    final player = this.player;
    return SurfaceCard(
      onTap: entry.untranscribed ? null : (error == null ? onCopy : (retrying ? null : onRetry)),
      onLongPress: onDelete,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (entry.mode == DictationMode.recording)
                const Tag(label: 'Voice memo', icon: Icons.mic_none_rounded)
              else if (memo)
                const Tag(label: 'Memo', icon: Icons.graphic_eq_rounded)
              else if (appId != null)
                Tag(label: appDisplayName(appId)),
              if (!memo && entry.style != DictationStyle.standard) ...[
                const SizedBox(width: 6),
                Tag(label: entry.style.label),
              ],
              const Spacer(),
              Text(_relativeTime(context, entry.createdAt), style: AppThemeData.geist(12, color: AppColors.textFaint)),
            ],
          ),
          const SizedBox(height: 10),
          if (error != null)
            _FailedBody(error: error, audioMillis: entry.audioMillis, retrying: retrying, onRetry: onRetry)
          else if (!entry.untranscribed)
            Text(
              entry.text,
              maxLines: memo ? 8 : 5,
              overflow: TextOverflow.ellipsis,
              style: AppThemeData.geist(15.5, height: 1.45),
            ),
          if (player != null) ...[if (!entry.untranscribed) const SizedBox(height: 8), player],
          if (entry.untranscribed) ...[
            const SizedBox(height: 8),
            _TranscribeButton(retrying: retrying, label: 'Transcribe', onPressed: onRetry),
          ],
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

/// A recording that couldn't be transcribed yet, kept so nothing said is lost.
class _FailedBody extends StatelessWidget {
  const _FailedBody({required this.error, required this.retrying, required this.onRetry, this.audioMillis});

  final String error;
  final int? audioMillis;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final millis = audioMillis;
    final length = millis == null ? '' : ' · ${_clock(Duration(milliseconds: millis))}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.danger),
            const SizedBox(width: 6),
            Text('Not transcribed yet$length', style: AppThemeData.geist(15, weight: 560)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          error,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppThemeData.geist(13, color: AppColors.textMuted, height: 1.35),
        ),
        const SizedBox(height: 12),
        _TranscribeButton(retrying: retrying, label: 'Try again', onPressed: onRetry),
      ],
    );
  }
}

class _TranscribeButton extends StatelessWidget {
  const _TranscribeButton({required this.retrying, required this.label, required this.onPressed});

  final bool retrying;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!retrying) return FilledButton.tonal(onPressed: onPressed, child: Text(label));
    return Row(
      children: [
        const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Text('Transcribing…', style: AppThemeData.geist(14, color: AppColors.textMuted)),
      ],
    );
  }
}

/// Play / pause, a scrubber while the recording is loaded, its length, and share.
class _AudioPlayerRow extends StatelessWidget {
  const _AudioPlayerRow({
    required this.playing,
    required this.onPlay,
    this.position,
    this.audioMillis,
    this.onSeek,
    this.onShare,
  });

  final bool playing;
  final VoidCallback onPlay;

  /// Set while this recording is loaded in the player.
  final ValueListenable<Duration>? position;
  final int? audioMillis;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final total = Duration(milliseconds: audioMillis ?? 0);
    final position = this.position;
    final onSeek = this.onSeek;
    final onShare = this.onShare;
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onPlay,
          tooltip: playing ? 'Pause' : 'Play',
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
        Expanded(
          child: position == null
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(_clock(total), style: AppThemeData.mono(12, color: AppColors.textMuted)),
                )
              : ValueListenableBuilder<Duration>(
                  valueListenable: position,
                  builder: (context, at, _) {
                    final end = total > at ? total : at;
                    return Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: at.inMilliseconds.toDouble(),
                            max: end.inMilliseconds == 0 ? 1 : end.inMilliseconds.toDouble(),
                            onChanged: onSeek == null ? null : (value) => onSeek(Duration(milliseconds: value.round())),
                          ),
                        ),
                        Text(_clock(at), style: AppThemeData.mono(12, color: AppColors.textMuted)),
                      ],
                    );
                  },
                ),
        ),
        if (onShare != null)
          IconButton(
            onPressed: onShare,
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded, size: 20, color: AppColors.textMuted),
          ),
      ],
    );
  }
}

String _clock(Duration duration) => '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

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
    id: '3',
    createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
    mode: DictationMode.memo,
    style: DictationStyle.memo,
    rawText: '',
    text: '',
    audioPath: '/memos/recording.m4a',
    audioMillis: 134000,
    error: 'Couldn’t reach the API. Check your internet connection.',
  ),
  HistoryEntry(
    id: '4',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    mode: DictationMode.recording,
    style: DictationStyle.memo,
    rawText: '',
    text: '',
    audioPath: '/memos/recording_2.m4a',
    audioMillis: 74000,
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
  onRetry: (_) {},
  onDelete: (_) {},
  onRecord: () {},
  playback: (id: '4', playing: true),
  position: ValueNotifier(const Duration(seconds: 23)),
  onPlay: (_) {},
  onSeek: (_) {},
  onShare: (_) {},
  phone: PhoneControls(
    armed: true,
    walkMode: true,
    headsetAvailable: true,
    onArmedChanged: (_) {},
    onWalkModeChanged: (_) {},
  ),
);

@AppPreview(group: 'Home', name: 'Recording voice memo', size: Size(390, 900))
Widget homeViewRecordingPreview() => HomeView(
  state: DictationState.listening,
  ready: true,
  message: 'Recording…',
  hint: '',
  audioOnly: true,
  setupSteps: const [],
  stats: const HomeStats(words: 1240, minutesSaved: 23, learned: 7),
  history: const [],
  onOrbTap: () {},
  onRecord: () {},
  onCopy: (_) {},
  onRetry: (_) {},
  onDelete: (_) {},
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
  onRetry: (_) {},
  onDelete: (_) {},
);
