import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/router.dart';
import '../pop_study/pop_repository.dart';
import 'selected_deck_provider.dart';

/// Home / Dashboard screen.
///
/// Displays placeholder metrics for today's study progress and a deck
/// selector that persists the chosen deck for pop-study.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final decks = ref.watch(deckRepositoryProvider).values.toList();
    final selectedDeckId = ref.watch(selectedDeckProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ホーム')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今日の学習',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _MetricCard(
              label: '今日の学習数',
              value: '—',
              icon: Icons.menu_book_outlined,
              color: colorScheme.primaryContainer,
            ),
            _MetricCard(
              label: '正答率',
              value: '—',
              icon: Icons.check_circle_outline,
              color: colorScheme.secondaryContainer,
            ),
            _MetricCard(
              label: '割り込み回数',
              value: '—',
              icon: Icons.notifications_outlined,
              color: colorScheme.tertiaryContainer,
            ),
            const SizedBox(height: 24),
            Text('ポップ学習デッキ',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Deck selector
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'デッキを選択',
                    border: InputBorder.none,
                  ),
                  value: decks.any((d) => d.deckId == selectedDeckId)
                      ? selectedDeckId
                      : null,
                  hint: const Text('デッキを選択してください'),
                  items: decks
                      .map((d) => DropdownMenuItem(
                            value: d.deckId,
                            child: Text(d.name),
                          ))
                      .toList(),
                  onChanged: (id) =>
                      ref.read(selectedDeckProvider.notifier).select(id),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Start pop-study button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('ポップ学習を開始'),
                onPressed: selectedDeckId == null
                    ? null
                    : () => context
                        .go('${AppRoutes.decks}/$selectedDeckId/pop'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(value,
            style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
