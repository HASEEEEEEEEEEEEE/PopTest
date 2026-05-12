import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/scheduler/scheduler.dart';
import '../../routing/router.dart';
import '../pop_study/pop_models.dart';
import 'card_face.dart';
import 'study_controller.dart';

class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyProvider(deckId));
    final controller = ref.read(studyProvider(deckId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学習'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: '元に戻す',
            onPressed: state.canUndo ? () => unawaited(controller.undo()) : null,
          ),
        ],
      ),
      body: state.isDone
          ? _buildDoneView(context, state, controller)
          : _buildStudyView(context, ref, state),
    );
  }

  Widget _buildDoneView(
      BuildContext context, StudyState state, StudyController controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text('今日の学習は完了です！',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '次の復習カードが到来するまでお待ちください',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          if (state.canUndo)
            OutlinedButton.icon(
              icon: const Icon(Icons.undo),
              label: const Text('最後の回答を取り消す'),
              onPressed: () => unawaited(controller.undo()),
            ),
          if (state.canUndo) const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('デッキに戻る'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyView(
      BuildContext context, WidgetRef ref, StudyState state) {
    final card = state.currentCard!;

    return Column(
      children: [
        _CountsBar(state: state, currentState: card.state),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: CardFace(
                    card: card,
                    showBack: state.showBack,
                    onEdit: () async {
                      await context.push(
                          '${AppRoutes.decks}/$deckId/edit/card/${card.id}');
                      ref
                          .read(studyProvider(deckId).notifier)
                          .syncCurrentCardFromRepo();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (!state.showBack)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () =>
                          ref.read(studyProvider(deckId).notifier).reveal(),
                      child: const Text('裏面を見る'),
                    ),
                  )
                else
                  _RatingButtons(deckId: deckId, card: card),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CountsBar extends StatelessWidget {
  const _CountsBar({required this.state, required this.currentState});

  final StudyState state;
  final CardState currentState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _countChip('未学習', state.newCount, CardState.newCard, currentState,
              Colors.blue, theme),
          _countChip('学習中', state.learningCount, CardState.learning,
              currentState, Colors.orange, theme),
          _countChip('復習中', state.reviewCount, CardState.review, currentState,
              Colors.green, theme),
        ],
      ),
    );
  }

  Widget _countChip(String label, int count, CardState target,
      CardState current, Color color, ThemeData theme) {
    final highlight = current == target;
    return Column(
      children: [
        Text(
          '$count',
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            decoration: highlight ? TextDecoration.underline : null,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _RatingButtons extends ConsumerWidget {
  const _RatingButtons({required this.deckId, required this.card});

  final String deckId;
  final CardModel card;

  String _formatInterval(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}日';
    if (d.inHours >= 1) return '${d.inHours}時間';
    if (d.inMinutes >= 1) return '${d.inMinutes}分';
    return '<1分';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(studyProvider(deckId).notifier);

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
              onPressed: () => unawaited(controller.rate(rating)),
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
