import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/scheduler/scheduler.dart';
import '../pop_study/pop_models.dart';
import '../pop_study/pop_repository.dart';

/// 通常学習の状態。セッション概念なし、1問ずつ処理。
class StudyState {
  const StudyState({
    required this.currentCard,
    required this.showBack,
    required this.newCount,
    required this.learningCount,
    required this.reviewCount,
  });

  final CardModel? currentCard;
  final bool showBack;
  final int newCount;
  final int learningCount;
  final int reviewCount;

  bool get isDone => currentCard == null;

  StudyState copyWith({
    CardModel? currentCard,
    bool? showBack,
    int? newCount,
    int? learningCount,
    int? reviewCount,
    bool clearCurrentCard = false,
  }) {
    return StudyState(
      currentCard: clearCurrentCard ? null : (currentCard ?? this.currentCard),
      showBack: showBack ?? this.showBack,
      newCount: newCount ?? this.newCount,
      learningCount: learningCount ?? this.learningCount,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }
}

class StudyController extends AutoDisposeFamilyNotifier<StudyState, String> {
  @override
  StudyState build(String deckId) {
    return _buildNext();
  }

  StudyState _buildNext() {
    final repo = ref.read(deckRepositoryProvider.notifier);
    final deck = repo.getDeck(arg); // deckId → arg
    final now = DateTime.now();

    // 期日到来カードのみをフィルタ
    final dueCards =
        deck.cards.where((c) => Sm2Scheduler.isDue(c, now)).toList();

    // 優先順: learning > review > new
    dueCards.sort((a, b) {
      int priority(CardState s) => switch (s) {
            CardState.learning => 0,
            CardState.review => 1,
            CardState.newCard => 2,
          };
      final p = priority(a.state).compareTo(priority(b.state));
      if (p != 0) return p;
      // 同じ状態内ではdueAtが古い順
      final ad = a.dueAt?.millisecondsSinceEpoch ?? 0;
      final bd = b.dueAt?.millisecondsSinceEpoch ?? 0;
      return ad.compareTo(bd);
    });

    int newCount = 0, learningCount = 0, reviewCount = 0;
    for (final c in dueCards) {
      switch (c.state) {
        case CardState.newCard:
          newCount++;
        case CardState.learning:
          learningCount++;
        case CardState.review:
          reviewCount++;
      }
    }

    return StudyState(
      currentCard: dueCards.isEmpty ? null : dueCards.first,
      showBack: false,
      newCount: newCount,
      learningCount: learningCount,
      reviewCount: reviewCount,
    );
  }

  void reveal() {
    if (state.isDone) return;
    state = state.copyWith(showBack: true);
  }

  Future<void> rate(ReviewRating rating) async {
    final card = state.currentCard;
    if (card == null) return;

    final updated = Sm2Scheduler.applyRating(card, rating);
    await ref
        .read(deckRepositoryProvider.notifier)
        .updateCardFull(arg, updated); // deckId → arg

    // 次のカードへ
    state = _buildNext();
  }

  void refresh() {
    state = _buildNext();
  }
}

final studyProvider = NotifierProvider.autoDispose
    .family<StudyController, StudyState, String>(StudyController.new);
