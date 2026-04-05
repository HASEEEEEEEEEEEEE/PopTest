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

  DeckData copyWith({
    String? deckId,
    String? name,
    List<CardModel>? cards,
  }) {
    return DeckData(
      deckId: deckId ?? this.deckId,
      name: name ?? this.name,
      cards: cards ?? this.cards,
    );
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
    final initial = _initialDecks(prefs);
    // Overlay persisted card states on top of the hard-coded defaults.
    return {
      for (final entry in initial.entries)
        entry.key: _applyPersistedStates(entry.value, prefs),
    };
  }

  // ── Public helpers ─────────────────────────────────────────────────────────

  List<DeckData> getAll() => state.values.toList();

  DeckData getDeck(String deckId) {
    if (state.isEmpty) {
      return DeckData(deckId: deckId, name: '', cards: const []);
    }
    return state[deckId] ?? state.values.first;
  }

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

  Future<void> renameDeck(String deckId, String newName) async {
    final deck = state[deckId];
    if (deck == null) return;
    final updated = deck.copyWith(name: newName.trim());
    state = Map.of(state)..[deckId] = updated;
    await ref.read(appPrefsProvider).setDeckName(deckId, updated.name);
  }

  Future<void> addCard(String deckId, String front, String back) async {
    final deck = state[deckId];
    if (deck == null) return;
    final newCard = CardModel(
      id: '${deckId}-${DateTime.now().microsecondsSinceEpoch}',
      front: front.trim(),
      back: back.trim(),
      state: CardState.newCard,
    );
    final cards = [...deck.cards, newCard];
    state = Map.of(state)..[deckId] = deck.copyWith(cards: cards);
    await ref.read(appPrefsProvider).setDeckCards(deckId, cards);
  }

  Future<void> updateCard(
    String deckId,
    String cardId, {
    String? front,
    String? back,
    CardState? stateValue,
  }) async {
    final deck = state[deckId];
    if (deck == null) return;
    final cards = deck.cards
        .map((c) => c.id == cardId
            ? c.copyWith(
                front: front?.trim() ?? c.front,
                back: back?.trim() ?? c.back,
                state: stateValue ?? c.state,
              )
            : c)
        .toList();
    state = Map.of(state)..[deckId] = deck.copyWith(cards: cards);
    await ref.read(appPrefsProvider).setDeckCards(deckId, cards);
  }

  Future<void> deleteCard(String deckId, String cardId) async {
    final deck = state[deckId];
    if (deck == null) return;
    final cards = deck.cards.where((c) => c.id != cardId).toList();
    state = Map.of(state)..[deckId] = deck.copyWith(cards: cards);
    await ref.read(appPrefsProvider).setDeckCards(deckId, cards);
  }

  Future<void> resetCardState(String deckId, String cardId) async {
    await updateCard(deckId, cardId, stateValue: CardState.newCard);
  }

  Future<void> resetAllCardStates(String deckId) async {
    final deck = state[deckId];
    if (deck == null) return;
    final cards =
        deck.cards.map((c) => c.copyWith(state: CardState.newCard)).toList();
    state = Map.of(state)..[deckId] = deck.copyWith(cards: cards);
    final prefs = ref.read(appPrefsProvider);
    await prefs.setDeckCards(deckId, cards);
    for (final card in cards) {
      await prefs.setCardState(deckId, card.id, CardState.newCard);
    }
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

  static Map<String, DeckData> _initialDecks(AppPrefs prefs) {
    final defaults = <String, DeckData>{
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
    return {
      for (final entry in defaults.entries)
        entry.key: DeckData(
          deckId: entry.value.deckId,
          name: prefs.getDeckName(entry.key) ?? entry.value.name,
          cards: prefs.getDeckCards(entry.key) ?? entry.value.cards,
        ),
    };
  }
}

final deckRepositoryProvider =
    NotifierProvider<DeckRepository, Map<String, DeckData>>(
  DeckRepository.new,
);
