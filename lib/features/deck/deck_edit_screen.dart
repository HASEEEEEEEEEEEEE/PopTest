import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pop_study/pop_models.dart';
import '../pop_study/pop_repository.dart';

class DeckEditScreen extends ConsumerWidget {
  const DeckEditScreen({super.key, required this.deckId});

  final String deckId;

  Future<void> _showCardEditor(
    BuildContext context,
    WidgetRef ref, {
    CardModel? card,
  }) async {
    final frontController = TextEditingController(text: card?.front ?? '');
    final backController = TextEditingController(text: card?.back ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(card == null ? 'カード追加' : 'カード編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: frontController,
              decoration: const InputDecoration(labelText: '表面'),
            ),
            TextField(
              controller: backController,
              decoration: const InputDecoration(labelText: '裏面'),
            ),
          ],
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
    if (result != true) return;
    final repo = ref.read(deckRepositoryProvider.notifier);
    if (card == null) {
      await repo.addCard(deckId, frontController.text, backController.text);
    } else {
      await repo.updateCard(
        deckId,
        card.id,
        front: frontController.text,
        back: backController.text,
      );
    }
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
        onPressed: () => _showCardEditor(context, ref),
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
                  subtitle: Text('${card.back}\n状態: ${_stateLabel(card.state)}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      final repo = ref.read(deckRepositoryProvider.notifier);
                      switch (value) {
                        case 'edit':
                          await _showCardEditor(context, ref, card: card);
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

String _stateLabel(CardState state) => switch (state) {
      CardState.newCard => '未学習',
      CardState.learning => '学習中',
      CardState.review => '復習中',
    };
