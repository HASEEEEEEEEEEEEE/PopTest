import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'pop_counts.dart';
import 'pop_models.dart';
import 'pop_study_controller.dart';

/// Pop Study screen – the core Anki-like study experience.
///
/// Shows both:
///  • Session remaining counts (with current card state underlined).
///  • Deck total counts (with current card state underlined).
///
/// Implements "solve-to-dismiss": back navigation shows a confirmation dialog
/// unless the session is already complete.
class PopStudyScreen extends ConsumerWidget {
  const PopStudyScreen({super.key, required this.deckId});

  final String deckId;

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('学習を終了しますか？'),
        content: const Text('セッションの進捗は保存されません。'),
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
    if (shouldExit == true && context.mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(popStudyProvider(deckId));

    return PopScope(
      canPop: state.isDone,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        unawaited(_confirmExit(context));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pop Study'),
          leading: BackButton(
            onPressed: state.isDone
                ? () => context.pop()
                : () => unawaited(_confirmExit(context)),
          ),
        ),
        body: state.isDone
            ? _buildDoneView(context)
            : _buildStudyView(context, ref, state),
      ),
    );
  }

  Widget _buildDoneView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text('セッション完了！',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('デッキに戻る'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyView(
      BuildContext context, WidgetRef ref, PopStudyState state) {
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
                      onPressed: () =>
                          ref.read(popStudyProvider(deckId).notifier).reveal(),
                      child: const Text('裏面を見る'),
                    ),
                  )
                else
                  _AnswerButtons(deckId: deckId),
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
          Text('$label: ${counts.total}枚',
              style: theme.textTheme.bodySmall),
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
        decoration:
            highlight ? TextDecoration.underline : TextDecoration.none,
        fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
        color: highlight
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(popStudyProvider(deckId).notifier);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: controller.again,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('もう一度'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton(
            onPressed: controller.good,
            child: const Text('覚えた'),
          ),
        ),
      ],
    );
  }
}
