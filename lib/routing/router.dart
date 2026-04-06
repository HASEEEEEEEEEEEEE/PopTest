import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/deck/deck_screen.dart';
import '../features/deck/decks_screen.dart';
import '../features/deck/deck_edit_screen.dart';
import '../features/deck/deck_pop_settings_screen.dart';
import '../features/home/home_screen.dart';
import '../features/pop_study/pop_study_screen.dart';
import '../features/review/review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import 'shell_scaffold.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Named route paths used throughout the app.
abstract final class AppRoutes {
  static const home = '/';
  static const decks = '/decks';
  static const review = '/review';
  static const settings = '/settings';
  static const stats = '/stats';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          // Branch 0 – Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Branch 1 – Decks (list → detail → pop study)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.decks,
                builder: (context, state) => const DecksScreen(),
                routes: [
                  GoRoute(
                    path: ':deckId',
                    builder: (context, state) {
                      final deckId = state.pathParameters['deckId']!;
                      return DeckScreen(deckId: deckId);
                    },
                    routes: [
                      GoRoute(
                        path: 'pop-settings',
                        builder: (context, state) {
                          final deckId = state.pathParameters['deckId']!;
                          return DeckPopSettingsScreen(deckId: deckId);
                        },
                      ),
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) {
                          final deckId = state.pathParameters['deckId']!;
                          return DeckEditScreen(deckId: deckId);
                        },
                      ),
                      GoRoute(
                        path: 'pop',
                        builder: (context, state) {
                          final deckId = state.pathParameters['deckId']!;
                          return PopStudyScreen(deckId: deckId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Branch 2 – Review
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.review,
                builder: (context, state) => const ReviewScreen(),
              ),
            ],
          ),
          // Branch 3 – Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
          // Branch 4 – Stats
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stats,
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
