import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/deck/deck_screen.dart';
import '../features/home/home_screen.dart';
import '../features/review/review_screen.dart';
import '../features/settings/settings_screen.dart';

/// Named route paths used throughout the app.
abstract final class AppRoutes {
  static const home = '/';
  static const deck = '/deck';
  static const review = '/review';
  static const settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.deck,
        builder: (context, state) => const DeckScreen(),
      ),
      GoRoute(
        path: AppRoutes.review,
        builder: (context, state) => const ReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
