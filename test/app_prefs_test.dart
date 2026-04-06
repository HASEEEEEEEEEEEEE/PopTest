import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:poptest/data/local/app_prefs.dart';
import 'package:poptest/features/pop_study/pop_models.dart';

void main() {
  group('AppPrefs', () {
    late AppPrefs prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      prefs = AppPrefs(sp);
    });

    // ── selectedDeckId ──────────────────────────────────────────────────────

    test('selectedDeckId is null when nothing is stored', () {
      expect(prefs.selectedDeckId, isNull);
    });

    test('setSelectedDeckId persists the value', () async {
      await prefs.setSelectedDeckId('deck-1');
      expect(prefs.selectedDeckId, 'deck-1');
    });

    test('setSelectedDeckId(null) removes the stored value', () async {
      await prefs.setSelectedDeckId('deck-1');
      await prefs.setSelectedDeckId(null);
      expect(prefs.selectedDeckId, isNull);
    });

    // ── card state ──────────────────────────────────────────────────────────

    test('getCardState returns null when nothing is stored', () {
      expect(prefs.getCardState('d1', 'c1'), isNull);
    });

    test('setCardState / getCardState round-trips all states', () async {
      for (final state in CardState.values) {
        await prefs.setCardState('d1', 'c1', state);
        expect(prefs.getCardState('d1', 'c1'), state);
      }
    });

    test('loadCardStates returns only cards with persisted state', () async {
      await prefs.setCardState('d1', 'c1', CardState.learning);
      await prefs.setCardState('d1', 'c3', CardState.review);

      final result = prefs.loadCardStates('d1', ['c1', 'c2', 'c3']);

      expect(result['c1'], CardState.learning);
      expect(result.containsKey('c2'), isFalse); // no saved state
      expect(result['c3'], CardState.review);
    });

    test('card states from different decks do not collide', () async {
      await prefs.setCardState('d1', 'c1', CardState.learning);
      await prefs.setCardState('d2', 'c1', CardState.review);

      expect(prefs.getCardState('d1', 'c1'), CardState.learning);
      expect(prefs.getCardState('d2', 'c1'), CardState.review);
    });

    test('unknown stored value falls back to newCard', () async {
      // Simulate a future format written to prefs that we don't recognise.
      SharedPreferences.setMockInitialValues(
          {'card_state_d1_c1': 'unknown_future_value'});
      final sp2 = await SharedPreferences.getInstance();
      final prefs2 = AppPrefs(sp2);
      expect(prefs2.getCardState('d1', 'c1'), CardState.newCard);
    });

    // ── popStudyActive ──────────────────────────────────────────────────────

    test('popStudyActive is false when nothing is stored', () {
      expect(prefs.popStudyActive, isFalse);
    });

    test('setPopStudyActive persists true', () async {
      await prefs.setPopStudyActive(true);
      expect(prefs.popStudyActive, isTrue);
    });

    test('setPopStudyActive persists false after true', () async {
      await prefs.setPopStudyActive(true);
      await prefs.setPopStudyActive(false);
      expect(prefs.popStudyActive, isFalse);
    });

    test('deck pop settings round-trip', () async {
      const deckId = 'd1';
      final settings = DeckPopSettings(
        useGlobal: false,
        services: {PopService.twitter, PopService.youtube},
        customUrls: {'youtube.com/shorts'},
        intervalMinutes: 9,
        popCount: 4,
      );
      await prefs.setDeckPopSettings(deckId, settings);
      final loaded = prefs.loadDeckPopSettings(deckId);
      expect(loaded.useGlobal, isFalse);
      expect(loaded.services, {PopService.twitter, PopService.youtube});
      expect(loaded.customUrls, {'youtube.com/shorts'});
      expect(loaded.intervalMinutes, 9);
      expect(loaded.popCount, 4);
    });

    test('deck name round-trip', () async {
      await prefs.setDeckName('d1', 'My Deck');
      expect(prefs.getDeckName('d1'), 'My Deck');
    });

    test('deck cards round-trip', () async {
      final cards = [
        const CardModel(
          id: '1',
          front: 'a|b',
          back: r'c\d',
          state: CardState.learning,
        ),
        const CardModel(
          id: '2',
          front: 'front2',
          back: 'back2',
          state: CardState.review,
        ),
      ];
      await prefs.setDeckCards('d1', cards);
      final loaded = prefs.getDeckCards('d1');
      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded[0].front, 'a|b');
      expect(loaded[0].back, r'c\d');
      expect(loaded[0].state, CardState.learning);
      expect(loaded[1].state, CardState.review);
    });
  });
}
