import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_prefs.dart';
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

/// Deck repository backed by in-memory state + [AppPrefs] persistence.
///
/// State is `Map<deckId, DeckData>`. Watchers rebuild whenever any deck's
/// card states are updated via [updateCardState].
///
/// TODO: replace with Drift database in issue #2.
class DeckRepository extends Notifier<Map<String, DeckData>> {
  @override
  Map<String, DeckData> build() {
    final prefs = ref.read(appPrefsProvider);
    final initial = _initialDecks();
    // Overlay persisted card states on top of the hard-coded defaults.
    return {
      for (final entry in initial.entries)
        entry.key: _applyPersistedStates(entry.value, prefs),
    };
  }

  // ── Public helpers ─────────────────────────────────────────────────────────

  List<DeckData> getAll() => state.values.toList();

  DeckData getDeck(String deckId) =>
      state[deckId] ?? state.values.first;

  /// Updates a single card's state both in memory and in [AppPrefs].
  void updateCardState(
      String deckId, String cardId, CardModel updatedCard) {
    final deck = state[deckId];
    if (deck == null) return;
    final cards =
        deck.cards.map((c) => c.id == cardId ? updatedCard : c).toList();
    state = Map.of(state)
      ..[deckId] = DeckData(
          deckId: deck.deckId, name: deck.name, cards: cards);
    // Persist asynchronously (fire-and-forget; errors are non-fatal).
    ref
        .read(appPrefsProvider)
        .setCardState(deckId, cardId, updatedCard.state);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  DeckData _applyPersistedStates(DeckData deck, AppPrefs prefs) {
    final saved = prefs.loadCardStates(
        deck.deckId, deck.cards.map((c) => c.id));
    if (saved.isEmpty) return deck;
    return DeckData(
      deckId: deck.deckId,
      name: deck.name,
      cards: deck.cards
          .map((c) =>
              saved.containsKey(c.id) ? c.copyWith(state: saved[c.id]) : c)
          .toList(),
    );
  }

  static Map<String, DeckData> _initialDecks() => {
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
}

final deckRepositoryProvider =
    NotifierProvider<DeckRepository, Map<String, DeckData>>(
  DeckRepository.new,
);
