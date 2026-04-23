import '../../core/scheduler/scheduler.dart';
import 'pop_models.dart';

/// Aggregate counts for an iterable of cards.
/// 復習中は dueAt <= now のみ。dueAt > now の review カードは nScheduled（復習予定）。
({int nNew, int nLearning, int nReview, int nScheduled, int total}) countDue(
    Iterable<CardModel> cards, DateTime now) {
  var nNew = 0;
  var nLearning = 0;
  var nReview = 0;
  var nScheduled = 0;
  for (final c in cards) {
    switch (c.state) {
      case CardState.newCard:
        nNew++;
      case CardState.learning:
        nLearning++;
      case CardState.review:
        if (Sm2Scheduler.isDue(c, now)) {
          nReview++;
        } else {
          nScheduled++;
        }
    }
  }
  return (
    nNew: nNew,
    nLearning: nLearning,
    nReview: nReview,
    nScheduled: nScheduled,
    total: nNew + nLearning + nReview + nScheduled,
  );
}

/// Build the initial session queue for a deck.
/// Order: learning → due review → new (capped at [newLimit]).
/// If [sessionLimit] is provided, the total queue length is also capped.
List<CardModel> buildSessionQueue({
  required List<CardModel> cards,
  required int newLimit,
  int? sessionLimit,
}) {
  final now = DateTime.now();
  final learning = cards.where((c) => c.state == CardState.learning).toList();
  final review = cards
      .where((c) => c.state == CardState.review && Sm2Scheduler.isDue(c, now))
      .toList();
  final news =
      cards.where((c) => c.state == CardState.newCard).take(newLimit).toList();
  final full = [...learning, ...review, ...news];
  if (sessionLimit != null && sessionLimit > 0 && full.length > sessionLimit) {
    return full.take(sessionLimit).toList();
  }
  return full;
}
