import 'package:flutter_test/flutter_test.dart';

import 'package:poptest/features/pop_study/pop_models.dart';
import 'package:poptest/features/pop_study/pop_counts.dart';

void main() {
  group('CardState transitions', () {
    test('copyWith changes state from newCard to learning', () {
      const card = CardModel(
          id: 'c1', front: 'front', back: 'back', state: CardState.newCard);
      final updated = card.copyWith(state: CardState.learning);
      expect(updated.state, CardState.learning);
      expect(updated.id, card.id);
    });

    test('copyWith changes state from learning to review', () {
      const card = CardModel(
          id: 'c1', front: 'front', back: 'back', state: CardState.learning);
      final updated = card.copyWith(state: CardState.review);
      expect(updated.state, CardState.review);
    });

    test('copyWith preserves unchanged fields', () {
      const original = CardModel(
          id: 'c1', front: 'f', back: 'b', state: CardState.newCard);
      final updated = original.copyWith(state: CardState.review);
      expect(updated.id, original.id);
      expect(updated.front, original.front);
      expect(updated.back, original.back);
    });
  });

  group('countDue', () {
    final now = DateTime.now();
    final past = now.subtract(const Duration(hours: 1));
    final future = now.add(const Duration(days: 2));

    test('returns zeros for empty list', () {
      final counts = countDue([], now);
      expect(counts.nNew, 0);
      expect(counts.nLearning, 0);
      expect(counts.nReview, 0);
      expect(counts.total, 0);
    });

    test('counts each state correctly; future review excluded', () {
      final cards = [
        const CardModel(id: '1', front: '', back: '', state: CardState.newCard),
        const CardModel(id: '2', front: '', back: '', state: CardState.newCard),
        const CardModel(id: '3', front: '', back: '', state: CardState.learning),
        CardModel(id: '4', front: '', back: '', state: CardState.review, dueAt: past),
        CardModel(id: '5', front: '', back: '', state: CardState.review, dueAt: future),
      ];
      final counts = countDue(cards, now);
      expect(counts.nNew, 2);
      expect(counts.nLearning, 1);
      expect(counts.nReview, 1);
      expect(counts.nScheduled, 1); // future review card
      expect(counts.total, 5);
    });
  });

  group('buildSessionQueue', () {
    final newCard = (String id) =>
        CardModel(id: id, front: '', back: '', state: CardState.newCard);
    final learningCard = (String id) =>
        CardModel(id: id, front: '', back: '', state: CardState.learning);
    final reviewCard = (String id) =>
        CardModel(id: id, front: '', back: '', state: CardState.review);

    test('order is learning → review → new', () {
      final cards = [
        newCard('n1'),
        reviewCard('r1'),
        learningCard('l1'),
      ];
      final queue = buildSessionQueue(cards: cards, newLimit: 10);
      expect(queue[0].state, CardState.learning);
      expect(queue[1].state, CardState.review);
      expect(queue[2].state, CardState.newCard);
    });

    test('new cards are capped at newLimit', () {
      final cards = List.generate(5, (i) => newCard('n$i'));
      final queue = buildSessionQueue(cards: cards, newLimit: 3);
      expect(queue.length, 3);
    });

    test('new cards cap does not affect learning/review', () {
      final cards = [
        learningCard('l1'),
        reviewCard('r1'),
        newCard('n1'),
        newCard('n2'),
        newCard('n3'),
      ];
      final queue = buildSessionQueue(cards: cards, newLimit: 1);
      expect(queue.length, 3); // 1 learning + 1 review + 1 new
    });
  });
}
