import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart';
import 'pop_counts.dart';
import 'pop_models.dart';
import 'pop_repository.dart';

/// Snapshot of the pop-study session state.
class PopStudyState {
  const PopStudyState({
    required this.queue,
    required this.cardMap,
    required this.showBack,
  });

  /// Remaining cards to study in this session.
  final List<CardModel> queue;

  /// All cards in the deck, keyed by id, reflecting latest state updates.
  final Map<String, CardModel> cardMap;

  /// Whether the back face of the current card is revealed.
  final bool showBack;

  bool get isDone => queue.isEmpty;

  CardModel? get currentCard => queue.isEmpty ? null : queue.first;

  PopStudyState copyWith({
    List<CardModel>? queue,
    Map<String, CardModel>? cardMap,
    bool? showBack,
  }) {
    return PopStudyState(
      queue: queue ?? this.queue,
      cardMap: cardMap ?? this.cardMap,
      showBack: showBack ?? this.showBack,
    );
  }
}

/// Controller for a single pop-study session.
class PopStudyController
    extends AutoDisposeFamilyNotifier<PopStudyState, String> {
  @override
  PopStudyState build(String deckId) {
    final repo = ref.read(deckRepositoryProvider.notifier);
    final newLimit = ref.read(newLimitProvider);
    final deck = repo.getDeck(deckId);
    final queue = buildSessionQueue(cards: deck.cards, newLimit: newLimit);
    final cardMap = {for (final c in deck.cards) c.id: c};
    return PopStudyState(queue: queue, cardMap: cardMap, showBack: false);
  }

  /// Reveal the back face of the current card.
  void reveal() {
    if (state.isDone) return;
    state = state.copyWith(showBack: true);
  }

  /// "Again" – keep card in session (move to end of queue) and set learning.
  void again() {
    if (state.isDone) return;
    final card = state.queue.first.copyWith(state: CardState.learning);
    final newQueue = [...state.queue.skip(1), card];
    final newCardMap = Map<String, CardModel>.of(state.cardMap)
      ..[card.id] = card;
    state =
        state.copyWith(queue: newQueue, cardMap: newCardMap, showBack: false);
    // Persist the updated card state.
    ref
        .read(deckRepositoryProvider.notifier)
        .updateCardState(deckId, card.id, card);
  }

  /// "Good" – advance state and remove card from queue.
  /// new → review, learning → review, review → review (refresh dueAt +1 day).
  void good() {
    if (state.isDone) return;
    final card = state.queue.first.copyWith(
      state: CardState.review,
      dueAt: DateTime.now().add(const Duration(days: 1)),
    );
    final newQueue = state.queue.skip(1).toList();
    final newCardMap = Map<String, CardModel>.of(state.cardMap)
      ..[card.id] = card;
    state =
        state.copyWith(queue: newQueue, cardMap: newCardMap, showBack: false);
    // Persist the updated card state.
    ref
        .read(deckRepositoryProvider.notifier)
        .updateCardState(deckId, card.id, card);
  }
}

final popStudyProvider = NotifierProvider.autoDispose
    .family<PopStudyController, PopStudyState, String>(
  PopStudyController.new,
);
