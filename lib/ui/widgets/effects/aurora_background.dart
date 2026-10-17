import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

/// Slow-drifting aurora light behind the whole app. [energy] (0..1) brightens it while PocketFlow is listening.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, this.energy = 0, this.child});

  final double energy;
  final Widget? child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.energy),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, energy, child) => CustomPaint(
        painter: _AuroraPainter(reduceMotion ? const AlwaysStoppedAnimation(0.2) : _controller, energy),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.animation, this.energy) : super(repaint: animation);

  final Animation<double> animation;
  final double energy;

  static const _blobs = [
    (AppColors.violet, 0.55, 0.0, 0.18, 0.12),
    (AppColors.magenta, 0.45, 1.7, 0.82, 0.30),
    (AppColors.cyan, 0.40, 3.4, 0.25, 0.78),
    (AppColors.amber, 0.30, 5.1, 0.80, 0.92),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.ink);
    final t = animation.value * 2 * pi;
    final span = max(size.width, size.height);

    for (final (color, strength, phase, x, y) in _blobs) {
      final center = Offset(size.width * (x + 0.12 * sin(t + phase)), size.height * (y + 0.08 * cos(t * 0.8 + phase)));
      final radius = span * (0.55 + 0.08 * sin(t * 1.3 + phase) + energy * 0.12);
      final alpha = (strength * (0.32 + energy * 0.28)).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Fade the bottom back to ink so lists stay readable.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.ink.withValues(alpha: 0), AppColors.ink.withValues(alpha: 0.75)],
          stops: const [0.35, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => oldDelegate.energy != energy;
}

@AppPreview(group: 'Effects', name: 'Aurora')
Widget auroraBackgroundPreview() => const AuroraBackground(child: SizedBox.expand());
