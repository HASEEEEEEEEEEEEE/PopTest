import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import 'pop_counts.dart';
import 'pop_models.dart';
import 'pop_study_active_provider.dart';
import 'pop_study_controller.dart';
import '../home/selected_deck_provider.dart';
import '../../core/scheduler/scheduler.dart';
import '../../routing/router.dart' show AppRoutes;
import '../pop_study/pop_repository.dart';

class PopStudyScreen extends ConsumerStatefulWidget {
  const PopStudyScreen({super.key, required this.deckId});

  final String deckId;

  @override
  ConsumerState<PopStudyScreen> createState() => _PopStudyScreenState();
}

class _PopStudyScreenState extends ConsumerState<PopStudyScreen> {
  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('学習を中断しますか？'),
        content: const Text('回答済みのカード状態は保存されています。残りのカードは次回も学習できます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('終了'),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(popStudyProvider(widget.deckId));
    final controller = ref.read(popStudyProvider(widget.deckId).notifier);

    return PopScope(
      canPop: state.isDone,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        unawaited(_confirmExit());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pop Study'),
          leading: BackButton(
            onPressed: state.isDone
                ? () => context.pop()
                : () => unawaited(_confirmExit()),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: '元に戻す',
              onPressed: state.canUndo ? controller.undo : null,
            ),
          ],
        ),
        body: state.isDone
            ? _buildDoneView(state, controller)
            : _buildStudyView(state),
      ),
    );
  }

  Widget _buildDoneView(PopStudyState state, PopStudyController controller) {
    final now = DateTime.now();
    final counts = countDue(state.cardMap.values, now);
    final noActiveCards =
        counts.nNew == 0 && counts.nLearning == 0 && counts.nReview == 0;
    final emptySession = state.answeredCount == 0;

    if (emptySession || noActiveCards) {
      return _buildDeckFinishedView(state, emptySession: emptySession);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text('セッション完了！', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '${state.answeredCount}問回答・${state.graduatedCount}枚復習予定',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          if (state.canUndo)
            OutlinedButton.icon(
              icon: const Icon(Icons.undo),
              label: const Text('最後の回答を取り消す'),
              onPressed: controller.undo,
            ),
          if (state.canUndo) const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.school),
            label: const Text('このまま学習を続ける'),
            onPressed: () => context.go('/decks/${widget.deckId}/study'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.layers_outlined),
            label: const Text('デッキを確認する'),
            onPressed: () => context.go('/decks/${widget.deckId}'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('元のアプリに戻る'),
            onPressed: _moveTaskToBack,
          ),
        ],
      ),
    );
  }

  Widget _buildDeckFinishedView(PopStudyState state,
      {required bool emptySession}) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              emptySession ? Icons.inbox_outlined : Icons.celebration_outlined,
              size: 64,
              color: emptySession ? Colors.grey : Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              emptySession
                  ? '学習できるカードがありません'
                  : 'このデッキの学習が完了しました！',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              emptySession
                  ? '現在学習対象のカードがありません'
                  : '${state.answeredCount}問回答・${state.graduatedCount}枚復習予定',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: const Text('別のデッキに変更'),
              onPressed: () => unawaited(_showDeckSelector()),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('ポップ学習を停止'),
              onPressed: () async {
                await ref
                    .read(popStudyActiveProvider.notifier)
                    .setActive(false);
                if (mounted) context.go(AppRoutes.home);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('元のアプリに戻る'),
              onPressed: _moveTaskToBack,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeckSelector() async {
    final deckMap = ref.read(deckRepositoryProvider);
    final decks = deckMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('デッキを選択',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            ...decks.map((deck) => ListTile(
                  title: Text(deck.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await ref
                        .read(selectedDeckProvider.notifier)
                        .select(deck.deckId);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) context.go(AppRoutes.home);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _moveTaskToBack() async {
    const channel = MethodChannel('poptest.pop_monitoring/methods');
    await channel.invokeMethod('moveTaskToBack');
  }

  Widget _buildStudyView(PopStudyState state) {
    final current = state.currentCard!;

    return Column(
      children: [
        _SessionBar(state: state, currentState: current.state),
        const Divider(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(child: _CardFace(state: state, card: current)),
                const SizedBox(height: 16),
                if (!state.showBack)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => ref
                          .read(popStudyProvider(widget.deckId).notifier)
                          .reveal(),
                      child: const Text('裏面を見る'),
                    ),
                  )
                else
                  _AnswerButtons(deckId: widget.deckId),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionBar extends StatelessWidget {
  const _SessionBar({required this.state, required this.currentState});

  final PopStudyState state;
  final CardState currentState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = state.popCount - state.answeredCount;
    final now = DateTime.now();
    final counts = countDue(state.cardMap.values, now);
    final nNew = counts.nNew;
    final nLearning = counts.nLearning;
    final nReview = counts.nReview;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            '残り $remaining問',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          const Text('| '),
          _CountChip(
            label: '未学習',
            count: nNew,
            highlight: currentState == CardState.newCard,
          ),
          const SizedBox(width: 4),
          _CountChip(
            label: '学習中',
            count: nLearning,
            highlight: currentState == CardState.learning,
          ),
          const SizedBox(width: 4),
          _CountChip(
            label: '復習中',
            count: nReview,
            highlight: currentState == CardState.review,
          ),
          if (state.graduatedCount > 0) ...[
            const SizedBox(width: 4),
            _CountChip(
              label: '復習予定',
              count: state.graduatedCount,
              highlight: false,
              color: Colors.green,
            ),
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.highlight,
    this.color,
  });

  final String label;
  final int count;
  final bool highlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ??
        (highlight ? theme.colorScheme.primary : theme.colorScheme.onSurface);
    return Text(
      '$label: $count',
      style: theme.textTheme.bodySmall?.copyWith(
        decoration: highlight ? TextDecoration.underline : TextDecoration.none,
        fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
        color: effectiveColor,
        decorationColor: highlight ? theme.colorScheme.primary : null,
        decorationThickness: highlight ? 2 : null,
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.state, required this.card});

  final PopStudyState state;
  final CardModel card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.front,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              if (state.showBack) ...[
                const Divider(height: 32),
                Text(
                  card.back,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerButtons extends ConsumerWidget {
  const _AnswerButtons({required this.deckId});

  final String deckId;

  String _formatInterval(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}日';
    if (d.inHours >= 1) return '${d.inHours}時間';
    if (d.inMinutes >= 1) return '${d.inMinutes}分';
    return '<1分';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(popStudyProvider(deckId).notifier);
    final state = ref.watch(popStudyProvider(deckId));
    final card = state.currentCard;
    if (card == null) return const SizedBox.shrink();

    final ratings = [
      (ReviewRating.again, 'もう一度', Colors.red),
      (ReviewRating.hard, '難しい', Colors.orange),
      (ReviewRating.good, '正解', Colors.blue),
      (ReviewRating.easy, '簡単', Colors.green),
    ];

    return Row(
      children: ratings.map((r) {
        final (rating, label, color) = r;
        final preview = Sm2Scheduler.previewInterval(card, rating);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: OutlinedButton(
              onPressed: () => controller.rate(rating),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(_formatInterval(preview),
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
