import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketflow/features/home/home_page.dart';
import 'package:pocketflow/features/home/state/home_notifiers.dart';
import 'package:pocketflow/features/settings/settings_page.dart';
import 'package:pocketflow/features/vocabulary/vocabulary_page.dart';
import 'package:pocketflow/platform/android_bridge.dart';
import 'package:pocketflow/ui/widgets/effects/aurora_background.dart';
import 'package:pocketflow/ui/widgets/structure/glass_nav_bar.dart';

enum AppRoute {
  home('/'),
  vocabulary('/vocabulary'),
  settings('/settings');

  const AppRoute(this.path);

  final String path;
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoute.home.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabShell(shell: shell),
        branches: [
          for (final (route, page) in [
            (AppRoute.home, const HomePage()),
            (AppRoute.vocabulary, const VocabularyPage()),
            (AppRoute.settings, const SettingsPage()),
          ])
            StatefulShellBranch(
              routes: [GoRoute(path: route.path, name: route.name, builder: (context, state) => page)],
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _TabShell extends ConsumerWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dictationActivityProvider).state;
    final energy = switch (state) {
      DictationState.listening => 1.0,
      DictationState.transcribing => 0.6,
      _ => 0.0,
    };

    return AuroraBackground(
      energy: energy,
      child: Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: GlassNavBar(
          selectedIndex: shell.currentIndex,
          onSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
          items: const [
            (Icons.graphic_eq_rounded, 'Home'),
            (Icons.auto_awesome_outlined, 'Vocabulary'),
            (Icons.tune_rounded, 'Settings'),
          ],
        ),
      ),
    );
  }
}
