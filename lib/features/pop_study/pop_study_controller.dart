import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart';
import 'pop_counts.dart';
import 'deck_pop_settings.dart';
import 'pop_models.dart';
import 'pop_repository.dart';
import '../../core/scheduler/scheduler.dart';

class _UndoSnapshot {
  const _UndoSnapshot({
    required this.card,
    required this.queue,
    required this.cardMap,
    required this.answeredCount,
    required this.graduatedCount,
  });

  final CardModel card;
  final List<CardModel> queue;
  final Map<String, CardModel> cardMap;
  final int answeredCount;
  final int graduatedCount;
}

class PopStudyState {
  const PopStudyState({
    required this.queue,
    required this.cardMap,
    required this.showBack,
    required this.answeredCount,
    required this.popCount,
    required this.graduatedCount,
    required this.canUndo,
  });

  final List<CardModel> queue;
  final Map<String, CardModel> cardMap;
  final bool showBack;
  final int answeredCount;
  final int popCount;
  final int graduatedCount;
  final bool canUndo;

  bool get isDone => answeredCount >= popCount || queue.isEmpty;
  CardModel? get currentCard => queue.isEmpty ? null : queue.first;

  PopStudyState copyWith({
    List<CardModel>? queue,
    Map<String, CardModel>? cardMap,
    bool? showBack,
    int? answeredCount,
    int? graduatedCount,
    bool? canUndo,
  }) {
    return PopStudyState(
      queue: queue ?? this.queue,
      cardMap: cardMap ?? this.cardMap,
      showBack: showBack ?? this.showBack,
      answeredCount: answeredCount ?? this.answeredCount,
      popCount: popCount,
      graduatedCount: graduatedCount ?? this.graduatedCount,
      canUndo: canUndo ?? this.canUndo,
    );
  }
}

class PopStudyController
    extends AutoDisposeFamilyNotifier<PopStudyState, String> {
  _UndoSnapshot? _undoSnapshot;

  @override
  PopStudyState build(String deckId) {
    _undoSnapshot = null;
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
    return PopStudyState(
      queue: queue,
      cardMap: cardMap,
      showBack: false,
      answeredCount: 0,
      popCount: popCount,
      graduatedCount: 0,
      canUndo: false,
    );
  }

  void reveal() {
    if (state.isDone) return;
    state = state.copyWith(showBack: true);
  }

  void reset() {
    _undoSnapshot = null;
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
    state = PopStudyState(
      queue: queue,
      cardMap: cardMap,
      showBack: false,
      answeredCount: 0,
      popCount: popCount,
      graduatedCount: 0,
      canUndo: false,
    );
  }

  void rate(ReviewRating rating) {
    if (state.isDone) return;
    final card = state.queue.first;

    _undoSnapshot = _UndoSnapshot(
      card: card,
      queue: List.of(state.queue),
      cardMap: Map.of(state.cardMap),
      answeredCount: state.answeredCount,
      graduatedCount: state.graduatedCount,
    );

    final updated = Sm2Scheduler.applyRating(card, rating);
    final newAnsweredCount = state.answeredCount + 1;
    final nextInterval = Sm2Scheduler.previewInterval(card, rating);
    final graduates =
        (rating == ReviewRating.good || rating == ReviewRating.easy) &&
            nextInterval.inDays >= 1;

    var newQueue = state.queue.skip(1).toList();
    var newGraduatedCount = state.graduatedCount;

    if (graduates) {
      newGraduatedCount++;
    } else if (rating == ReviewRating.again || rating == ReviewRating.hard) {
      if (newAnsweredCount < state.popCount) {
        newQueue.add(updated);
      }
    }

    final newCardMap = Map<String, CardModel>.of(state.cardMap)
      ..[updated.id] = updated;

    state = state.copyWith(
      queue: newQueue,
      cardMap: newCardMap,
      showBack: false,
      answeredCount: newAnsweredCount,
      graduatedCount: newGraduatedCount,
      canUndo: true,
    );

    ref.read(deckRepositoryProvider.notifier).updateCardFull(arg, updated);
  }

  void undo() {
    final snapshot = _undoSnapshot;
    if (snapshot == null) return;
    _undoSnapshot = null;
    ref.read(deckRepositoryProvider.notifier).updateCardFull(arg, snapshot.card);
    state = PopStudyState(
      queue: snapshot.queue,
      cardMap: snapshot.cardMap,
      showBack: true,
      answeredCount: snapshot.answeredCount,
      popCount: state.popCount,
      graduatedCount: snapshot.graduatedCount,
      canUndo: false,
    );
  }

  void again() => rate(ReviewRating.again);
  void good() => rate(ReviewRating.good);

  /// Re-fetches the current card from the repository, preserving the queue
  /// and answered count. Use after the user edits the card mid-session.
  void syncCurrentCardFromRepo() {
    if (state.queue.isEmpty) return;
    final current = state.queue.first;
    final repo = ref.read(deckRepositoryProvider.notifier);
    final fresh = repo
        .getDeck(arg)
        .cards
        .firstWhere((c) => c.id == current.id, orElse: () => current);
    final newQueue = [fresh, ...state.queue.skip(1)];
    final newCardMap = Map<String, CardModel>.of(state.cardMap)
      ..[fresh.id] = fresh;
    state = state.copyWith(queue: newQueue, cardMap: newCardMap);
  }
}

final popStudyProvider = NotifierProvider.autoDispose
    .family<PopStudyController, PopStudyState, String>(
  PopStudyController.new,
);
