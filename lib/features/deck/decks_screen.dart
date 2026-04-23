import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/router.dart';
import '../pop_study/pop_counts.dart';
import '../pop_study/pop_repository.dart';

/// Screen that lists all decks.
class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the state map directly – rebuilds when card states change.
    final deckMap = ref.watch(deckRepositoryProvider);
    final decks = deckMap.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('デッキ一覧')),
      body: decks.isEmpty
          ? const Center(child: Text('デッキがありません'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: decks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final deck = decks[i];
                final counts = countDue(deck.cards, DateTime.now());

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      deck.name.isNotEmpty ? deck.name[0] : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(deck.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('カード数: ${counts.total}'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: deck.progress),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.go('${AppRoutes.decks}/${deck.deckId}'),
                );
              },
            ),
    );
  }
}
