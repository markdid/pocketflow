import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

/// Previews wrapped in the app theme. Run with `make preview`.
///
/// ```dart
/// @AppPreview(group: 'Home')
/// Widget homeViewPreview() => HomeView(count: 42, onIncrement: () {});
/// ```
///
/// Preview functions must be public and top-level (or static) with no
/// parameters. Views and widgets only — pages need provider overrides.
final class AppPreview extends MultiPreview {
  const AppPreview({this.group = 'Default', this.name, this.size});

  final String group;
  final String? name;
  final Size? size;

  @override
  // The brand is dark-only, so one variant.
  List<Preview> get previews => [
    Preview(group: group, name: name ?? 'Default', size: size, brightness: Brightness.dark, wrapper: darkThemeWrapper),
  ];
}

Widget darkThemeWrapper(Widget child) => _ThemedPreview(theme: AppThemeData.dark, child: child);

class _ThemedPreview extends StatelessWidget {
  const _ThemedPreview({required this.theme, required this.child});

  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(backgroundColor: AppColors.ink, body: child),
    );
  }
}
