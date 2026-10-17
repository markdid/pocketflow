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

  /// Transcribing and cleaning up: a thin beam circles the orb.
  processing,
}

/// A matte liquid orb that ripples with the voice and lights up in the signal color while listening. Tap to dictate.
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

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final t = f.time;
    final base = size.shortestSide * 0.30 * (1 - f.press * 0.05) * (1 + 0.015 * sin(t * 1.6));
    // How "live" the orb is: 0 at rest, up to 1 on loud speech. Only this brings in the signal color.
    final live = (f.energy - 0.18).clamp(0.0, 1.0) / 0.82 * (1 - f.processing);
    final dim = 1 - f.asleep * 0.6;

    // Signal glow behind the orb, only while listening.
    if (live > 0.01) {
      final glowRadius = base * (1.3 + f.level * 0.25);
      canvas.drawCircle(
        center,
        glowRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.signal.withValues(alpha: 0.14 * live),
              AppColors.signal.withValues(alpha: 0),
            ],
            stops: const [0.7, 1],
          ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
      );
    }

    final ripple = 0.018 + f.energy * 0.025 + f.level * 0.11;
    final shape = _blob(center, base, t, ripple);
    final bounds = Rect.fromCircle(center: center, radius: base * 1.3);

    canvas.save();
    canvas.clipPath(shape);

    // Matte charcoal, lit from the top left.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 1.25,
          colors: [
            Color.lerp(AppColors.surface, const Color(0xFF4A4A50), dim)!,
            const Color(0xFF1A1A1D),
            const Color(0xFF0C0C0E),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: base)),
    );

    // Rim light: faint white at rest, the signal color when the mic is live.
    final rimColor = Color.lerp(Colors.white.withValues(alpha: 0.10 * dim), AppColors.signal, live)!;
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = base * (0.035 + f.level * 0.025)
        ..color = rimColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, base * 0.012),
    );

    // Soft specular highlight.
    final glint = center + Offset(-base * 0.4, -base * 0.48);
    final glintRect = Rect.fromCenter(center: glint, width: base * 0.8, height: base * 0.45);
    canvas.drawOval(
      glintRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10 * dim),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(glintRect),
    );
    canvas.restore();

    // Writing: a thin white beam circling the orb.
    if (f.processing > 0.01) {
      final ring = Rect.fromCircle(center: center, radius: base * 1.28);
      final start = f.spin * 1.6;
      canvas.drawArc(
        ring,
        start,
        pi * 0.48,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = base * 0.022
          ..shader = SweepGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.9 * f.processing),
            ],
            stops: const [0, 0.24],
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
