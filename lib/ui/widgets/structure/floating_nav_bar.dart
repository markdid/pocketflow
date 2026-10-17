import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pocketflow/ui/preview/app_preview.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

/// Floating tab bar; the selected tab is inverted (paper on ink).
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({super.key, required this.selectedIndex, required this.onSelected, required this.items});

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 12),
      child: Center(
        heightFactor: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (index, (icon, label)) in items.indexed)
                      _NavItem(
                        icon: icon,
                        label: label,
                        selected: index == selectedIndex,
                        onTap: () => onSelected(index),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: selected ? AppColors.text : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: selected ? AppColors.ink : AppColors.textMuted),
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(label, style: AppThemeData.geist(14, weight: 600, color: AppColors.ink)),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@AppPreview(group: 'Structure', name: 'Nav bar')
Widget floatingNavBarPreview() => Align(
  alignment: Alignment.bottomCenter,
  child: FloatingNavBar(
    selectedIndex: 0,
    onSelected: (_) {},
    items: const [
      (Icons.graphic_eq_rounded, 'Home'),
      (Icons.auto_awesome_outlined, 'Vocabulary'),
      (Icons.tune_rounded, 'Settings'),
    ],
  ),
);
