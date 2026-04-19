import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart';
import 'pop_counts.dart';
import 'deck_pop_settings.dart';
import 'pop_models.dart';
import 'pop_repository.dart';
import 'pop_settings.dart';
import '../../core/scheduler/scheduler.dart';

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
    final popCount = ref.read(effectivePopSettingsProvider(deckId)).popCount;
    final deck = repo.getDeck(deckId);
    final queue = buildSessionQueue(
      cards: deck.cards,
      newLimit: newLimit,
      sessionLimit: popCount,
    );
    final cardMap = {for (final c in deck.cards) c.id: c};
    return PopStudyState(queue: queue, cardMap: cardMap, showBack: false);
  }

  /// Reveal the back face of the current card.
  void reveal() {
    if (state.isDone) return;
    state = state.copyWith(showBack: true);
  }

  // pop_study_controller.dart の PopStudyController 内
  void reset() {
    final repo = ref.read(deckRepositoryProvider.notifier);
    final newLimit = ref.read(newLimitProvider);
    final popCount = ref.read(effectivePopSettingsProvider(arg)).popCount;
    final deck = repo.getDeck(arg);
    final queue = buildSessionQueue(
      cards: deck.cards,
      newLimit: newLimit,
      sessionLimit: popCount,
    );
    final cardMap = {for (final c in deck.cards) c.id: c};
    state = PopStudyState(queue: queue, cardMap: cardMap, showBack: false);
  }

  void rate(ReviewRating rating) {
    if (state.isDone) return;
    final card = state.queue.first;
    final updated = Sm2Scheduler.applyRating(card, rating);

    // queueから取り除く（again/hardなら末尾に戻す）
    final newQueue = state.queue.skip(1).toList();
    if (rating == ReviewRating.again || rating == ReviewRating.hard) {
      newQueue.add(updated);
    }

    final newCardMap = Map<String, CardModel>.of(state.cardMap)
      ..[updated.id] = updated;
    state =
        state.copyWith(queue: newQueue, cardMap: newCardMap, showBack: false);

    ref.read(deckRepositoryProvider.notifier).updateCardFull(arg, updated);
  }

// 互換性のため残す
  void again() => rate(ReviewRating.again);
  void good() => rate(ReviewRating.good);
}

final popStudyProvider = NotifierProvider.autoDispose
    .family<PopStudyController, PopStudyState, String>(
  PopStudyController.new,
);
