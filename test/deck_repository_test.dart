import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:poptest/data/local/app_prefs.dart';
import 'package:poptest/features/pop_study/pop_models.dart';
import 'package:poptest/features/pop_study/pop_repository.dart';

void main() {
  group('DeckRepository', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [appPrefsProvider.overrideWithValue(AppPrefs(sp))],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('renameDeck updates deck name', () async {
      final repo = container.read(deckRepositoryProvider.notifier);
      await repo.renameDeck('1', '新しい名前');
      expect(container.read(deckRepositoryProvider)['1']?.name, '新しい名前');
    });

    test('addCard appends a new card', () async {
      final repo = container.read(deckRepositoryProvider.notifier);
      final before = container.read(deckRepositoryProvider)['1']!.cards.length;
      await repo.addCard('1', 'front', 'back');
      final after = container.read(deckRepositoryProvider)['1']!.cards.length;
      expect(after, before + 1);
    });

    test('updateCard changes front/back and state', () async {
      final repo = container.read(deckRepositoryProvider.notifier);
      final card = container.read(deckRepositoryProvider)['1']!.cards.first;
      await repo.updateCard('1', card.id,
          front: 'F', back: 'B', stateValue: CardState.review);
      final updated = container
          .read(deckRepositoryProvider)['1']!
          .cards
          .firstWhere((c) => c.id == card.id);
      expect(updated.front, 'F');
      expect(updated.back, 'B');
      expect(updated.state, CardState.review);
    });

    test('deleteCard removes card', () async {
      final repo = container.read(deckRepositoryProvider.notifier);
      final card = container.read(deckRepositoryProvider)['1']!.cards.first;
      await repo.deleteCard('1', card.id);
      final exists = container
          .read(deckRepositoryProvider)['1']!
          .cards
          .any((c) => c.id == card.id);
      expect(exists, isFalse);
    });

    test('resetCardState sets target card to newCard', () async {
      final repo = container.read(deckRepositoryProvider.notifier);
      final card = container.read(deckRepositoryProvider)['1']!.cards.first;
      await repo.updateCard('1', card.id, stateValue: CardState.review);
      await repo.resetCardState('1', card.id);
      final updated = container
          .read(deckRepositoryProvider)['1']!
          .cards
          .firstWhere((c) => c.id == card.id);
      expect(updated.state, CardState.newCard);
    });

    test('resetAllCardStates sets all cards to newCard', () async {
      final repo = container.read(deckRepositoryProvider.notifier);
      await repo.resetAllCardStates('1');
      expect(
        container
            .read(deckRepositoryProvider)['1']!
            .cards
            .every((c) => c.state == CardState.newCard),
        isTrue,
      );
    });
  });
}
