import 'package:flutter/material.dart';

/// Deck screen – placeholder.
/// TODO: implement deck list and management.
class DeckScreen extends StatelessWidget {
  const DeckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Decks')),
      body: const Center(child: Text('Deck (placeholder)')),
    );
  }
}
