import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketflow/features/home/home_page.dart';
import 'package:pocketflow/features/settings/settings_page.dart';
import 'package:pocketflow/features/vocabulary/vocabulary_page.dart';
import 'package:pocketflow/ui/widgets/structure/floating_nav_bar.dart';

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

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: shell.currentIndex,
        onSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        items: const [
          (Icons.graphic_eq_rounded, 'Home'),
          (Icons.spellcheck_rounded, 'Vocabulary'),
          (Icons.tune_rounded, 'Settings'),
        ],
      ),
    );
  }
}
