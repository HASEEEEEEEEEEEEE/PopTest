import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/router.dart';
import '../pop_study/pop_counts.dart';
import '../pop_study/pop_repository.dart';

/// Screen that lists all decks.
class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  Future<void> _showAddDeckSheet(
      BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('空のデッキを作成'),
              subtitle: const Text('カードを1枚ずつ手で追加'),
              onTap: () => Navigator.pop(ctx, 'create'),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('ファイルからインポート'),
              subtitle: const Text('.txt / .csv / .tsv'),
              onTap: () => Navigator.pop(ctx, 'import'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'import') {
      context.go('${AppRoutes.decks}/import');
    } else {
      await _promptDeckName(context, ref);
    }
  }

  Future<void> _promptDeckName(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規デッキ作成'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'デッキ名'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final deckId = ref.read(deckRepositoryProvider.notifier).addDeck(name);
    if (deckId.isEmpty || !context.mounted) return;
    context.go('${AppRoutes.decks}/$deckId/edit');
  }

  Future<void> _confirmDeleteDeck(
      BuildContext context, WidgetRef ref, String deckId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('デッキ削除'),
        content: Text('「$name」を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(deckRepositoryProvider.notifier).deleteDeck(deckId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deckMap = ref.watch(deckRepositoryProvider);
    final decks = deckMap.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('デッキ一覧')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDeckSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新規デッキ'),
      ),
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
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'open':
                          context.go('${AppRoutes.decks}/${deck.deckId}');
                          break;
                        case 'delete':
                          _confirmDeleteDeck(
                              context, ref, deck.deckId, deck.name);
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'open', child: Text('開く')),
                      PopupMenuItem(value: 'delete', child: Text('削除')),
                    ],
                  ),
                  onTap: () =>
                      context.go('${AppRoutes.decks}/${deck.deckId}'),
                );
              },
            ),
    );
  }
}
