import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketflow/platform/desktop_dictation.dart';
import 'package:pocketflow/router/router.dart';
import 'package:pocketflow/ui/theme/app_theme_data.dart';

/// The macOS title bar is transparent, so content starts below the window buttons.
Widget _clearTrafficLights(BuildContext context, Widget? child) {
  final media = MediaQuery.of(context);
  return MediaQuery(
    data: media.copyWith(padding: media.padding.copyWith(top: media.padding.top + 28)),
    child: child ?? const SizedBox.shrink(),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Desktop dictation lives as long as the app (it runs from the menu bar with the window closed).
    ref.listen(desktopDictationProvider, (_, _) {});

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: MaterialApp.router(
        title: 'PocketFlow',
        theme: AppThemeData.light,
        routerConfig: ref.watch(routerProvider),
        debugShowCheckedModeBanner: false,
        builder: Platform.isMacOS ? _clearTrafficLights : null,
      ),
    );
  }
}
