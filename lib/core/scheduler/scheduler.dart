import '../../features/pop_study/pop_models.dart';

/// SM-2ベースの間隔反復スケジューラ。
class Sm2Scheduler {
  static const double minEaseFactor = 1.3;
  static const double defaultEaseFactor = 2.5;

  /// 学習ステップ（分単位）: 1回目の正解 → 10分後に再出題。
  static const List<int> learningStepsMinutes = [1, 10];

  /// 卒業後の最初の間隔（日）: 正解×2 または 簡単×1 で卒業
  static const int graduatingIntervalDays = 1;

  /// カードに対してレビュー結果を適用し、更新後のカードを返す。
  static CardModel applyRating(
    CardModel card,
    ReviewRating rating, {
    DateTime? now,
  }) {
    // もう一度 → 初期状態（newCard）に完全リセット
    if (rating == ReviewRating.again) {
      return card.copyWith(
        state: CardState.newCard,
        repetitions: 0,
        intervalDays: 0,
        dueAt: null,
      );
    }
    final reviewTime = now ?? DateTime.now();
    return switch (card.state) {
      CardState.newCard => _applyToNew(card, rating, reviewTime),
      CardState.learning => _applyToLearning(card, rating, reviewTime),
      CardState.review => _applyToReview(card, rating, reviewTime),
    };
  }

  static CardModel _applyToNew(
    CardModel card,
    ReviewRating rating,
    DateTime now,
  ) {
    return _applyToLearning(
      card.copyWith(state: CardState.learning, repetitions: 0),
      rating,
      now,
    );
  }

  static CardModel _applyToLearning(
    CardModel card,
    ReviewRating rating,
    DateTime now,
  ) {
    switch (rating) {
      case ReviewRating.again:
        // 上位で処理済みのため到達しない
        return card;
      case ReviewRating.hard:
        // 前のステップに戻す（タイミングを早める）
        final step = learningStepsMinutes.first;
        return card.copyWith(
          state: CardState.learning,
          repetitions: 0,
          dueAt: now.add(Duration(minutes: step)),
        );
      case ReviewRating.good:
        // 次のステップへ or 卒業（正解×2で卒業）
        final nextStep = card.repetitions + 1;
        if (nextStep >= learningStepsMinutes.length) {
          return card.copyWith(
            state: CardState.review,
            repetitions: 0,
            intervalDays: graduatingIntervalDays,
            dueAt: now.add(const Duration(days: graduatingIntervalDays)),
          );
        }
        return card.copyWith(
          state: CardState.learning,
          repetitions: nextStep,
          dueAt: now.add(Duration(minutes: learningStepsMinutes[nextStep])),
        );
      case ReviewRating.easy:
        // 即卒業（1日後）
        return card.copyWith(
          state: CardState.review,
          repetitions: 0,
          intervalDays: graduatingIntervalDays,
          dueAt: now.add(const Duration(days: graduatingIntervalDays)),
        );
    }
  }

  static CardModel _applyToReview(
    CardModel card,
    ReviewRating rating,
    DateTime now,
  ) {
    switch (rating) {
      case ReviewRating.again:
        // 上位で処理済みのため到達しない
        return card;
      case ReviewRating.hard:
        // インターバルを短縮（現在の75%、最低1日）
        final newEase = (card.easeFactor - 0.15).clamp(minEaseFactor, 99.0);
        final newInterval = (card.intervalDays * 0.75).ceil().clamp(1, 36500);
        return card.copyWith(
          intervalDays: newInterval,
          easeFactor: newEase,
          dueAt: now.add(Duration(days: newInterval)),
        );
      case ReviewRating.good:
        final newInterval =
            (card.intervalDays * card.easeFactor).ceil().clamp(1, 36500);
        return card.copyWith(
          intervalDays: newInterval,
          repetitions: card.repetitions + 1,
          dueAt: now.add(Duration(days: newInterval)),
        );
      case ReviewRating.easy:
        final newEase = card.easeFactor + 0.15;
        final newInterval =
            (card.intervalDays * card.easeFactor * 1.3).ceil().clamp(1, 36500);
        return card.copyWith(
          intervalDays: newInterval,
          easeFactor: newEase,
          repetitions: card.repetitions + 1,
          dueAt: now.add(Duration(days: newInterval)),
        );
    }
  }

  /// カードが今復習対象か判定
  static bool isDue(CardModel card, DateTime now) {
    switch (card.state) {
      case CardState.newCard:
        return true;
      case CardState.learning:
      case CardState.review:
        final due = card.dueAt;
        if (due == null) return true;
        return !due.isAfter(now);
    }
  }

  /// 次回の間隔をプレビュー（UI表示用）
  static Duration previewInterval(
    CardModel card,
    ReviewRating rating, {
    DateTime? now,
  }) {
    final reviewTime = now ?? DateTime.now();
    if (rating == ReviewRating.again) {
      return Duration.zero;
    }
    final predicted = applyRating(card, rating, now: reviewTime);
    final due = predicted.dueAt;
    if (due == null) return Duration.zero;
    return due.difference(reviewTime);
  }
}
