import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/router.dart';

/// Deck management screen placeholder.
/// TODO: implement deck CRUD backed by Drift local DB.
class DeckScreen extends StatelessWidget {
  const DeckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decks'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.home)),
      ),
      body: const Center(child: Text('Decks (placeholder)')),
    );
  }
}
