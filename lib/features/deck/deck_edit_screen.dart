import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/router.dart';
import '../pop_study/pop_models.dart';
import '../pop_study/pop_repository.dart';

class DeckEditScreen extends ConsumerWidget {
  const DeckEditScreen({super.key, required this.deckId});

  final String deckId;

  void _openCardEditor(BuildContext context, {CardModel? card}) {
    final base = '${AppRoutes.decks}/$deckId/edit';
    final target = card == null ? '$base/card/new' : '$base/card/${card.id}';
    context.go(target);
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('デッキ名編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'デッキ名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == true) {
      await ref.read(deckRepositoryProvider.notifier).renameDeck(deckId, controller.text);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deckMap = ref.watch(deckRepositoryProvider);
    final deck = deckMap[deckId];
    if (deck == null) {
      return const Scaffold(body: Center(child: Text('デッキが見つかりません')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('デッキ編集'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '全カードを未学習にリセット',
            onPressed: () =>
                ref.read(deckRepositoryProvider.notifier).resetAllCardStates(deckId),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCardEditor(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(deck.name),
              subtitle: const Text('デッキ名'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _showRenameDialog(context, ref, deck.name),
            ),
          ),
          const SizedBox(height: 8),
          ...deck.cards.map((card) => Card(
                child: ListTile(
                  title: Text(card.front),
                  subtitle: Text('${card.back}\n状態: ${_stateLabel(card)}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      final repo = ref.read(deckRepositoryProvider.notifier);
                      switch (value) {
                        case 'edit':
                          _openCardEditor(context, card: card);
                          break;
                        case 'reset':
                          await repo.resetCardState(deckId, card.id);
                          break;
                        case 'delete':
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('カード削除'),
                              content: const Text('このカードを削除しますか？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('キャンセル'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('削除'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await repo.deleteCard(deckId, card.id);
                          }
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('編集')),
                      PopupMenuItem(value: 'reset', child: Text('状態を未学習に戻す')),
                      PopupMenuItem(value: 'delete', child: Text('削除')),
                    ],
                  ),
                ),
              )),
          if (deck.cards.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('カードがありません')),
            ),
        ],
      ),
    );
  }
}

String _stateLabel(CardModel card) {
  switch (card.state) {
    case CardState.newCard:
      return '未学習';
    case CardState.learning:
      return '学習中';
    case CardState.review:
      final due = card.dueAt;
      if (due == null || !due.isAfter(DateTime.now())) return '復習中';
      return '復習予定';
  }
}
