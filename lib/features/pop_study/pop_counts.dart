import 'pop_models.dart';

/// Aggregate counts for an iterable of cards.
({int nNew, int nLearning, int nReview, int total}) countAll(
    Iterable<CardModel> cards) {
  var nNew = 0;
  var nLearning = 0;
  var nReview = 0;
  for (final c in cards) {
    switch (c.state) {
      case CardState.newCard:
        nNew++;
      case CardState.learning:
        nLearning++;
      case CardState.review:
        nReview++;
    }
  }
  return (
    nNew: nNew,
    nLearning: nLearning,
    nReview: nReview,
    total: nNew + nLearning + nReview,
  );
}

/// Build the initial session queue for a deck.
/// Order: learning → review → new (capped at [newLimit]).
/// If [sessionLimit] is provided, the total queue length is also capped.
List<CardModel> buildSessionQueue({
  required List<CardModel> cards,
  required int newLimit,
  int? sessionLimit,
}) {
  final learning = cards.where((c) => c.state == CardState.learning).toList();
  // TODO: filter review by dueAt <= now when Drift is integrated.
  final review = cards.where((c) => c.state == CardState.review).toList();
  final news =
      cards.where((c) => c.state == CardState.newCard).take(newLimit).toList();
  final full = [...learning, ...review, ...news];
  if (sessionLimit != null && sessionLimit > 0 && full.length > sessionLimit) {
    return full.take(sessionLimit).toList();
  }
  return full;
}
