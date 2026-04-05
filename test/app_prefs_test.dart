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
  });
}
