import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketflow/features/home/home_page.dart';
import 'package:pocketflow/features/settings/settings_page.dart';
import 'package:pocketflow/features/vocabulary/vocabulary_page.dart';

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
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.spellcheck), label: 'Vocabulary'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
