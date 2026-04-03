import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/router.dart';

/// Home screen – entry point of the app.
/// TODO: implement flashcard feed.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Home (placeholder)'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.deck),
              child: const Text('Decks'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => context.go(AppRoutes.review),
              child: const Text('Review'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => context.go(AppRoutes.settings),
              child: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
