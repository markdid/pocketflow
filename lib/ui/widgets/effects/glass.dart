import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

/// Frosted glass panel: blurs the aurora behind it, with a hairline edge that catches the light at the top.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.onTap,
    this.onLongPress,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Aurora-gradient edge for the one card that deserves attention.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return CustomPaint(
      foregroundPainter: _EdgePainter(radius: radius, glow: glow),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Material(
            color: AppColors.glass,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: shape,
              splashColor: AppColors.violet.withValues(alpha: 0.12),
              highlightColor: Colors.white.withValues(alpha: 0.03),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.radius, required this.glow});

  final double radius;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final shader = glow
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.violet, AppColors.magenta, AppColors.amber],
          ).createShader(rect)
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.04)],
          ).createShader(rect);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glow ? 1.2 : 1
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) => oldDelegate.glow != glow || oldDelegate.radius != radius;
}

/// Small rounded label, e.g. an app name or style on a history card.
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textMuted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: tint), const SizedBox(width: 4)],
            Text(label, style: AppThemeData.geist(11.5, weight: 540, color: tint)),
          ],
        ),
      ),
    );
  }
}

/// Text painted with the aurora gradient.
class AuroraText extends StatelessWidget {
  const AuroraText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: AppColors.auroraLinear.createShader,
      child: Text(text, style: style),
    );
  }
}

@AppPreview(group: 'Effects', name: 'Glass')
Widget glassCardPreview() => const Padding(
  padding: EdgeInsets.all(24),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      GlassCard(child: Text('A frosted card')),
      SizedBox(height: 12),
      GlassCard(glow: true, child: Text('The one that matters')),
      SizedBox(height: 12),
      GlassChip(label: 'Gmail', icon: Icons.mail_outline),
    ],
  ),
);
