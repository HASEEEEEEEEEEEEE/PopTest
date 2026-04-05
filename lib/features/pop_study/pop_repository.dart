import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pop_models.dart';

/// A single deck with its cards.
class DeckData {
  DeckData({required this.deckId, required this.name, required this.cards});

  final String deckId;
  final String name;
  final List<CardModel> cards;

  int get cardCount => cards.length;

  /// Fraction of cards that are in [CardState.review] state (rough progress).
  double get progress {
    if (cards.isEmpty) return 0;
    final done = cards.where((c) => c.state == CardState.review).length;
    return done / cards.length;
  }
}

/// In-memory deck repository.
/// TODO: replace with Drift database in issue #2.
class DeckRepository {
  DeckRepository()
      : _decks = {
          '1': DeckData(
            deckId: '1',
            name: '日本語基礎',
            cards: [
              const CardModel(
                  id: '1-1',
                  front: 'apple',
                  back: 'りんご',
                  state: CardState.newCard),
              const CardModel(
                  id: '1-2',
                  front: 'book',
                  back: '本',
                  state: CardState.newCard),
              const CardModel(
                  id: '1-3',
                  front: 'cat',
                  back: '猫',
                  state: CardState.learning),
              const CardModel(
                  id: '1-4',
                  front: 'dog',
                  back: '犬',
                  state: CardState.review),
              const CardModel(
                  id: '1-5',
                  front: 'egg',
                  back: '卵',
                  state: CardState.review),
              const CardModel(
                  id: '1-6',
                  front: 'fish',
                  back: '魚',
                  state: CardState.newCard),
            ],
          ),
          '2': DeckData(
            deckId: '2',
            name: 'JLPT N5 単語',
            cards: [
              const CardModel(
                  id: '2-1',
                  front: '水',
                  back: 'water / みず',
                  state: CardState.newCard),
              const CardModel(
                  id: '2-2',
                  front: '火',
                  back: 'fire / ひ',
                  state: CardState.learning),
              const CardModel(
                  id: '2-3',
                  front: '山',
                  back: 'mountain / やま',
                  state: CardState.review),
              const CardModel(
                  id: '2-4',
                  front: '川',
                  back: 'river / かわ',
                  state: CardState.newCard),
              const CardModel(
                  id: '2-5',
                  front: '空',
                  back: 'sky / そら',
                  state: CardState.newCard),
            ],
          ),
        };

  final Map<String, DeckData> _decks;

  List<DeckData> getAll() => _decks.values.toList();

  DeckData getDeck(String deckId) =>
      _decks[deckId] ?? _decks.values.first;
}

final deckRepositoryProvider = Provider<DeckRepository>((ref) {
  return DeckRepository();
});
