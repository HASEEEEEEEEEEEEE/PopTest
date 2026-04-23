import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/scheduler/scheduler.dart';
import '../pop_study/pop_counts.dart';
import '../pop_study/pop_models.dart';
import '../pop_study/pop_repository.dart';

class _UndoSnapshot {
  const _UndoSnapshot({required this.card, required this.state});
  final CardModel card;
  final StudyState state;
}

class StudyState {
  const StudyState({
    required this.currentCard,
    required this.showBack,
    required this.newCount,
    required this.learningCount,
    required this.reviewCount,
    required this.canUndo,
  });

  final CardModel? currentCard;
  final bool showBack;
  final int newCount;
  final int learningCount;
  final int reviewCount;
  final bool canUndo;

  bool get isDone => currentCard == null;

  StudyState copyWith({
    CardModel? currentCard,
    bool? showBack,
    int? newCount,
    int? learningCount,
    int? reviewCount,
    bool? canUndo,
    bool clearCurrentCard = false,
  }) {
    return StudyState(
      currentCard: clearCurrentCard ? null : (currentCard ?? this.currentCard),
      showBack: showBack ?? this.showBack,
      newCount: newCount ?? this.newCount,
      learningCount: learningCount ?? this.learningCount,
      reviewCount: reviewCount ?? this.reviewCount,
      canUndo: canUndo ?? this.canUndo,
    );
  }
}

class StudyController extends AutoDisposeFamilyNotifier<StudyState, String> {
  _UndoSnapshot? _undoSnapshot;

  @override
  StudyState build(String deckId) {
    _undoSnapshot = null;
    return _buildNext();
  }

  StudyState _buildNext({bool canUndo = false}) {
    final repo = ref.read(deckRepositoryProvider.notifier);
    final deck = repo.getDeck(arg);
    final now = DateTime.now();

    final dueCards =
        deck.cards.where((c) => Sm2Scheduler.isDue(c, now)).toList();

    dueCards.sort((a, b) {
      int priority(CardState s) => switch (s) {
            CardState.learning => 0,
            CardState.review => 1,
            CardState.newCard => 2,
          };
      final p = priority(a.state).compareTo(priority(b.state));
      if (p != 0) return p;
      final ad = a.dueAt?.millisecondsSinceEpoch ?? 0;
      final bd = b.dueAt?.millisecondsSinceEpoch ?? 0;
      return ad.compareTo(bd);
    });

    final counts = countDue(deck.cards, now);

    return StudyState(
      currentCard: dueCards.isEmpty ? null : dueCards.first,
      showBack: false,
      newCount: counts.nNew,
      learningCount: counts.nLearning,
      reviewCount: counts.nReview,
      canUndo: canUndo,
    );
  }

  void reveal() {
    if (state.isDone) return;
    state = state.copyWith(showBack: true);
  }

  Future<void> rate(ReviewRating rating) async {
    final card = state.currentCard;
    if (card == null) return;

    _undoSnapshot = _UndoSnapshot(card: card, state: state);

    final updated = Sm2Scheduler.applyRating(card, rating);
    await ref.read(deckRepositoryProvider.notifier).updateCardFull(arg, updated);

    state = _buildNext(canUndo: true);
  }

  Future<void> undo() async {
    final snapshot = _undoSnapshot;
    if (snapshot == null) return;
    _undoSnapshot = null;
    await ref
        .read(deckRepositoryProvider.notifier)
        .updateCardFull(arg, snapshot.card);
    state = snapshot.state.copyWith(showBack: true, canUndo: false);
  }

  void refresh() {
    state = _buildNext();
  }
}

final studyProvider = NotifierProvider.autoDispose
    .family<StudyController, StudyState, String>(StudyController.new);
