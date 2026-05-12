import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/deck/card_editor_screen.dart';
import '../features/deck/deck_import_screen.dart';
import '../features/deck/deck_screen.dart';
import '../features/deck/decks_screen.dart';
import '../features/deck/deck_edit_screen.dart';
import '../features/deck/deck_pop_settings_screen.dart';
import '../features/home/home_screen.dart';
import '../features/monitoring/monitoring_screen.dart';
import '../features/pop_study/pop_prompt_screen.dart';
import '../features/pop_study/pop_study_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import 'shell_scaffold.dart';
import '../features/study/study_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Named route paths used throughout the app.
abstract final class AppRoutes {
  static const home = '/';
  static const monitoring = '/monitoring';
  static const decks = '/decks';
  static const settings = '/settings';
  static const stats = '/stats';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: '/pop-prompt/:deckId',
        pageBuilder: (context, state) {
          final deckId = state.pathParameters['deckId']!;
          return CustomTransitionPage(
            key: state.pageKey,
            opaque: false,
            barrierColor: Colors.black54,
            barrierDismissible: false,
            child: PopPromptScreen(deckId: deckId),
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
          );
        },
      ),
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
              GoRoute(
                path: 'study',
                builder: (context, state) {
                  final deckId = state.pathParameters['deckId']!;
                  return StudyScreen(deckId: deckId);
                },
              ),
            ],
          ),
          // Branch 1 – Monitoring
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.monitoring,
                builder: (context, state) => const MonitoringScreen(),
              ),
            ],
          ),
          // Branch 2 – Decks (list → detail → pop study)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.decks,
                builder: (context, state) => const DecksScreen(),
                routes: [
                  GoRoute(
                    path: 'import',
                    builder: (context, state) => const DeckImportScreen(),
                  ),
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
                        routes: [
                          GoRoute(
                            path: 'card/new',
                            builder: (context, state) {
                              final deckId =
                                  state.pathParameters['deckId']!;
                              return CardEditorScreen(deckId: deckId);
                            },
                          ),
                          GoRoute(
                            path: 'card/:cardId',
                            builder: (context, state) {
                              final deckId =
                                  state.pathParameters['deckId']!;
                              final cardId =
                                  state.pathParameters['cardId']!;
                              return CardEditorScreen(
                                  deckId: deckId, cardId: cardId);
                            },
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'pop',
                        builder: (context, state) {
                          final deckId = state.pathParameters['deckId']!;
                          return PopStudyScreen(deckId: deckId);
                        },
                      ),
                      GoRoute(
                        path: 'study',
                        builder: (context, state) {
                          final deckId = state.pathParameters['deckId']!;
                          return StudyScreen(deckId: deckId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Branch 3 – Stats
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stats,
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
          // Branch 4 – Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
