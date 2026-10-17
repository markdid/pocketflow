import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/platform/desktop_dictation.dart';
import 'package:pocketflow/router/router.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Desktop dictation lives as long as the app (it runs from the menu bar with the window closed).
    ref.listen(desktopDictationProvider, (_, _) {});

    return MaterialApp.router(
      title: 'PocketFlow',
      theme: AppThemeData.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
