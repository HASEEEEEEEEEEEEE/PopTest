import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/router.dart';
import '../pop_study/pop_counts.dart';
import '../pop_study/pop_repository.dart';

/// Individual deck screen showing study actions and card-state breakdown.
class DeckScreen extends ConsumerWidget {
  const DeckScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(deckRepositoryProvider);
    final deck = repo.getDeck(deckId);
    final counts = countAll(deck.cards);

    return Scaffold(
      appBar: AppBar(title: Text(deck.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card state breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('状態別カード数',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StateCount(
                            label: '新規',
                            count: counts.nNew,
                            color: Colors.blue),
                        _StateCount(
                            label: '学習中',
                            count: counts.nLearning,
                            color: Colors.orange),
                        _StateCount(
                            label: '復習',
                            count: counts.nReview,
                            color: Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Primary action
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('学習開始'),
              onPressed: () =>
                  context.go('${AppRoutes.decks}/$deckId/pop'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('ポップ設定'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ポップ設定 (未実装)')),
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('編集'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('編集 (未実装)')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StateCount extends StatelessWidget {
  const _StateCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
