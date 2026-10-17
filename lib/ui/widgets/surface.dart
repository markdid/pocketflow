import 'package:flutter/material.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

/// Flat panel with a hairline edge.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: AppColors.hairline),
    );
    return Material(
      color: AppColors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        highlightColor: Colors.white.withValues(alpha: 0.03),
        splashColor: Colors.white.withValues(alpha: 0.04),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small quiet label, e.g. the app or style on a history card.
class Tag extends StatelessWidget {
  const Tag({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: AppColors.textMuted), const SizedBox(width: 4)],
            Text(label, style: AppThemeData.geist(11.5, weight: 520, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

@AppPreview(group: 'Structure', name: 'Surface')
Widget surfaceCardPreview() => const Padding(
  padding: EdgeInsets.all(24),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SurfaceCard(child: Text('A panel')),
      SizedBox(height: 12),
      Tag(label: 'Gmail'),
    ],
  ),
);
