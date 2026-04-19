import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import 'pop_counts.dart';
import 'pop_models.dart';
import 'pop_study_controller.dart';
import '../../core/scheduler/scheduler.dart';

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
        ),
        body: state.isDone ? _buildDoneView() : _buildStudyView(state),
      ),
    );
  }

  Widget _buildDoneView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text('セッション完了！', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('お疲れさまでした', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
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
            onPressed: () async {
              const channel = MethodChannel('poptest.pop_monitoring/methods');
              await channel.invokeMethod('moveTaskToBack');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudyView(PopStudyState state) {
    final current = state.currentCard!;
    final sessionCounts = countAll(state.queue);
    final deckCounts = countAll(state.cardMap.values);

    return Column(
      children: [
        _CountsBar(
          label: 'セッション残り',
          counts: sessionCounts,
          currentState: current.state,
        ),
        _CountsBar(
          label: 'デッキ全体',
          counts: deckCounts,
          currentState: current.state,
        ),
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

class _CountsBar extends StatelessWidget {
  const _CountsBar({
    required this.label,
    required this.counts,
    required this.currentState,
  });

  final String label;
  final ({int nNew, int nLearning, int nReview, int total}) counts;
  final CardState currentState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text('$label: ${counts.total}枚', style: theme.textTheme.bodySmall),
          const SizedBox(width: 8),
          const Text('| '),
          _CountChip(
            label: '未学習: ${counts.nNew}',
            highlight: currentState == CardState.newCard,
          ),
          const SizedBox(width: 4),
          _CountChip(
            label: '学習中: ${counts.nLearning}',
            highlight: currentState == CardState.learning,
          ),
          const SizedBox(width: 4),
          _CountChip(
            label: '復習中: ${counts.nReview}',
            highlight: currentState == CardState.review,
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.highlight});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        decoration: highlight ? TextDecoration.underline : TextDecoration.none,
        fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
        color:
            highlight ? theme.colorScheme.primary : theme.colorScheme.onSurface,
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
      (ReviewRating.good, '普通', Colors.blue),
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
