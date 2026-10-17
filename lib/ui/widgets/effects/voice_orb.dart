import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

enum OrbMode {
  /// Not ready (no key, service off): a dim, slow orb.
  asleep,

  /// Ready: breathing gently.
  idle,

  /// Mic open: the surface ripples with the voice level.
  listening,

  /// Transcribing and cleaning up: the colors swirl and a beam circles the orb.
  processing,
}

/// A liquid aurora orb that reacts to the voice. Tap it to dictate.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({super.key, required this.mode, this.level, this.size = 220, this.onTap, this.semanticLabel});

  final OrbMode mode;

  /// Live microphone level, 0..1.
  final ValueListenable<double>? level;
  final double size;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = _OrbFrame();
  var _pressed = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = elapsed.inMicroseconds / 1e6 - _frame.time;
    final targetLevel = widget.mode == OrbMode.listening ? (widget.level?.value ?? 0) : 0.0;
    final targetEnergy = switch (widget.mode) {
      OrbMode.asleep => 0.0,
      OrbMode.idle => 0.18,
      OrbMode.listening => 0.45 + targetLevel * 0.55,
      OrbMode.processing => 0.55,
    };
    // Rise fast, fall slowly, like a VU meter.
    final levelRate = targetLevel > _frame.level ? 18.0 : 4.0;
    _frame
      ..time = elapsed.inMicroseconds / 1e6
      ..level += (targetLevel - _frame.level) * min(1, dt * levelRate)
      ..energy += (targetEnergy - _frame.energy) * min(1, dt * 3)
      ..spin += dt * (widget.mode == OrbMode.processing ? 2.4 : 0.35)
      ..processing += ((widget.mode == OrbMode.processing ? 1 : 0) - _frame.processing) * min(1, dt * 4)
      ..asleep += ((widget.mode == OrbMode.asleep ? 1 : 0) - _frame.asleep) * min(1, dt * 3)
      ..press += ((_pressed ? 1 : 0) - _frame.press) * min(1, dt * 14);
    _frame.tick();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_ticker.isActive == reduceMotion) reduceMotion ? _ticker.stop() : _ticker.start();

    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _pressed = true,
        onTapUp: (_) => _pressed = false,
        onTapCancel: () => _pressed = false,
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: _OrbPainter(_frame)),
        ),
      ),
    );
  }
}

/// Smoothed animation values, shared between the ticker and the painter.
class _OrbFrame extends ChangeNotifier {
  double time = 0;
  double level = 0;
  double energy = 0.18;
  double spin = 0;
  double processing = 0;
  double asleep = 0;
  double press = 0;

  void tick() => notifyListeners();
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.f) : super(repaint: f);

  final _OrbFrame f;

  /// Pools of light drifting inside the orb: color, orbit speed, orbit size, pool size, phase.
  static const _pools = [
    (AppColors.magenta, 0.55, 0.62, 0.78, 0.0),
    (AppColors.cyan, -0.42, 0.66, 0.70, 1.9),
    (AppColors.amber, 0.33, 0.58, 0.55, 3.6),
    (AppColors.violet, -0.25, 0.35, 0.95, 5.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final t = f.time;
    final base = size.shortestSide * 0.30 * (1 - f.press * 0.06) * (1 + 0.02 * sin(t * 1.6));
    final wake = 1 - f.asleep * 0.7;

    // Halo: a wide bloom that swells with the voice.
    final haloRadius = base * (1.6 + f.energy * 0.45 + f.level * 0.3);
    canvas.drawCircle(
      center,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.magenta.withValues(alpha: wake * (0.22 + f.energy * 0.28)),
            AppColors.violet.withValues(alpha: wake * (0.12 + f.energy * 0.16)),
            AppColors.violet.withValues(alpha: 0),
          ],
          stops: const [0.3, 0.6, 1],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
    );

    final ripple = 0.025 + f.energy * 0.035 + f.level * 0.13;
    final shape = _blob(center, base, t, ripple);
    final bounds = Rect.fromCircle(center: center, radius: base * 1.3);

    canvas.save();
    canvas.clipPath(shape);

    // Deep body.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.2, 0.3),
          colors: [Color(0xFF2B1870), Color(0xFF0D0820)],
        ).createShader(bounds),
    );

    // Light pools, screened together so they bloom where they meet.
    final drift = 0.75 + f.energy * 0.5;
    for (final (color, speed, orbit, poolSize, phase) in _pools) {
      final a = t * speed * drift + phase + f.spin * 0.5;
      final position = center + Offset(cos(a), sin(a * 1.3)) * base * orbit * (0.8 + f.level * 0.5);
      final radius = base * poolSize * (0.9 + f.level * 0.35);
      canvas.drawCircle(
        position,
        radius,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.85 * wake),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: position, radius: radius)),
      );
    }

    // A white-hot core that flares on loud syllables.
    final core = base * (0.35 + f.level * 0.45);
    canvas.drawCircle(
      center,
      core,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: wake * (0.04 + f.level * 0.3)),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: core)),
    );

    // Volume: dark falloff toward the edge, then a thin inner rim of light.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
          stops: const [0.55, 0.85],
        ).createShader(Rect.fromCircle(center: center, radius: base * 1.15)),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = base * 0.08
        ..blendMode = BlendMode.screen
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, base * 0.05)
        ..shader = SweepGradient(
          colors: [for (final c in AppColors.aurora) c.withValues(alpha: 0.7 * wake)],
          transform: GradientRotation(f.spin + t * 0.2),
        ).createShader(bounds),
    );

    // Specular highlight.
    final glint = center + Offset(-base * 0.38, -base * 0.45);
    canvas.drawOval(
      Rect.fromCenter(center: glint, width: base * 0.7, height: base * 0.42),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.42 * wake),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCenter(center: glint, width: base * 0.7, height: base * 0.42)),
    );

    if (f.asleep > 0.01) {
      canvas.drawRect(bounds, Paint()..color = AppColors.ink.withValues(alpha: 0.5 * f.asleep));
    }
    canvas.restore();

    // Processing: a comet beam circling the orb.
    if (f.processing > 0.01) {
      final ringRadius = base * 1.3;
      final ring = Rect.fromCircle(center: center, radius: ringRadius);
      final start = f.spin * 1.6;
      // The gradient runs a quarter turn from the arc's tail to its bright head.
      canvas.drawArc(
        ring,
        start,
        pi * 0.48,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = base * 0.035
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
          ..shader = SweepGradient(
            colors: [
              AppColors.cyan.withValues(alpha: 0),
              AppColors.cyan.withValues(alpha: 0.85 * f.processing),
              Colors.white.withValues(alpha: f.processing),
            ],
            stops: const [0, 0.22, 0.25],
            transform: GradientRotation(start),
          ).createShader(ring),
      );
    }
  }

  Path _blob(Offset center, double radius, double t, double ripple) {
    const points = 120;
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final a = i / points * 2 * pi;
      final wobble = sin(3 * a + t * 1.7) + 0.6 * sin(5 * a - t * 2.3 + 1.1) + 0.35 * sin(8 * a + t * 3.4 - 0.7);
      final p = center + Offset(cos(a), sin(a)) * radius * (1 + ripple * wobble / 1.95);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) => false;
}

class _PreviewLevel extends ValueNotifier<double> {
  _PreviewLevel() : super(0.6);
}

@AppPreview(group: 'Effects', name: 'Orb idle')
Widget voiceOrbIdlePreview() => const Center(child: VoiceOrb(mode: OrbMode.idle));

@AppPreview(group: 'Effects', name: 'Orb listening')
Widget voiceOrbListeningPreview() => Center(
  child: VoiceOrb(mode: OrbMode.listening, level: _PreviewLevel()),
);

@AppPreview(group: 'Effects', name: 'Orb processing')
Widget voiceOrbProcessingPreview() => const Center(child: VoiceOrb(mode: OrbMode.processing));
