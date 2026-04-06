import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:poptest/data/local/app_prefs.dart';
import 'package:poptest/features/pop_study/pop_models.dart';
import 'package:poptest/features/pop_study/pop_counts.dart';

void main() {
  group('PopSettings', () {
    test('defaults have correct values', () {
      final s = PopSettings.defaults();
      expect(s.services, isEmpty);
      expect(s.intervalMinutes, PopSettings.defaultIntervalMinutes);
      expect(s.popCount, PopSettings.defaultPopCount);
    });

    test('copyWith overrides individual fields', () {
      final s = PopSettings.defaults()
          .copyWith(services: {PopService.twitter}, intervalMinutes: 15, popCount: 5);
      expect(s.services, {PopService.twitter});
      expect(s.intervalMinutes, 15);
      expect(s.popCount, 5);
    });

    test('intervalMinutes is clamped to valid range', () {
      final tooLow = PopSettings.defaults().copyWith(intervalMinutes: 0);
      expect(tooLow.intervalMinutes, PopSettings.minIntervalMinutes);

      final tooHigh = PopSettings.defaults().copyWith(intervalMinutes: 9999);
      expect(tooHigh.intervalMinutes, PopSettings.maxIntervalMinutes);
    });

    test('popCount is clamped to valid range', () {
      final tooLow = PopSettings.defaults().copyWith(popCount: 0);
      expect(tooLow.popCount, PopSettings.minPopCount);

      final tooHigh = PopSettings.defaults().copyWith(popCount: 999);
      expect(tooHigh.popCount, PopSettings.maxPopCount);
    });

    test('copyWith preserves unchanged fields', () {
      final original = PopSettings.defaults()
          .copyWith(services: {PopService.youtube}, intervalMinutes: 45);
      final updated = original.copyWith(popCount: 7);
      expect(updated.services, {PopService.youtube});
      expect(updated.intervalMinutes, 45);
      expect(updated.popCount, 7);
    });
  });

  group('DeckPopSettings', () {
    test('defaults use global settings', () {
      final s = DeckPopSettings.defaults();
      expect(s.useGlobal, isTrue);
      expect(s.services, isEmpty);
      expect(s.intervalMinutes, PopSettings.defaultIntervalMinutes);
      expect(s.popCount, PopSettings.defaultPopCount);
    });

    test('resolve returns global when useGlobal is true', () {
      final global = PopSettings.defaults().copyWith(
        services: {PopService.instagram},
        intervalMinutes: 12,
        popCount: 5,
      );
      final deck = DeckPopSettings.defaults().copyWith(
        useGlobal: true,
        services: {PopService.twitter},
        intervalMinutes: 99,
        popCount: 9,
      );
      final resolved = deck.resolve(global);
      expect(resolved.services, global.services);
      expect(resolved.intervalMinutes, global.intervalMinutes);
      expect(resolved.popCount, global.popCount);
    });

    test('resolve returns deck overrides when useGlobal is false', () {
      final global = PopSettings.defaults();
      final deck = DeckPopSettings.defaults().copyWith(
        useGlobal: false,
        services: {PopService.youtube},
        intervalMinutes: 25,
        popCount: 6,
      );
      final resolved = deck.resolve(global);
      expect(resolved.services, {PopService.youtube});
      expect(resolved.intervalMinutes, 25);
      expect(resolved.popCount, 6);
    });
  });

  group('AppPrefs – pop settings', () {
    late AppPrefs prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      prefs = AppPrefs(sp);
    });

    test('loadPopSettings returns defaults when nothing is stored', () {
      final s = prefs.loadPopSettings();
      expect(s.services, isEmpty);
      expect(s.intervalMinutes, PopSettings.defaultIntervalMinutes);
      expect(s.popCount, PopSettings.defaultPopCount);
    });

    test('setPopServices / loadPopSettings round-trips all services', () async {
      final all = PopService.values.toSet();
      await prefs.setPopServices(all);
      final s = prefs.loadPopSettings();
      expect(s.services, all);
    });

    test('setPopServices with empty set removes the stored value', () async {
      await prefs.setPopServices({PopService.twitter});
      await prefs.setPopServices({});
      final s = prefs.loadPopSettings();
      expect(s.services, isEmpty);
    });

    test('setPopIntervalMinutes / loadPopSettings round-trip', () async {
      await prefs.setPopIntervalMinutes(10);
      expect(prefs.loadPopSettings().intervalMinutes, 10);
    });

    test('setPopCount / loadPopSettings round-trip', () async {
      await prefs.setPopCount(7);
      expect(prefs.loadPopSettings().popCount, 7);
    });

    test('persisted out-of-range values are clamped on load', () async {
      // Write invalid raw values directly to simulate future data migration.
      SharedPreferences.setMockInitialValues({
        'pop_interval_minutes': 0,
        'pop_count': 99,
      });
      final sp2 = await SharedPreferences.getInstance();
      final prefs2 = AppPrefs(sp2);
      final s = prefs2.loadPopSettings();
      expect(s.intervalMinutes, PopSettings.minIntervalMinutes);
      expect(s.popCount, PopSettings.maxPopCount);
    });

    test('unknown service name in stored string is silently dropped', () async {
      SharedPreferences.setMockInitialValues({
        'pop_services': 'twitter,unknown_future_service,instagram',
      });
      final sp2 = await SharedPreferences.getInstance();
      final prefs2 = AppPrefs(sp2);
      final s = prefs2.loadPopSettings();
      expect(s.services, {PopService.twitter, PopService.instagram});
    });

    test('partial service subset is persisted and restored correctly',
        () async {
      await prefs.setPopServices({PopService.youtube, PopService.tiktok});
      final s = prefs.loadPopSettings();
      expect(s.services, {PopService.youtube, PopService.tiktok});
      expect(s.services.contains(PopService.twitter), isFalse);
    });
  });

  group('buildSessionQueue – sessionLimit', () {
    const testNewLimit = 10;

    final newCard = (String id) =>
        CardModel(id: id, front: '', back: '', state: CardState.newCard);
    final learningCard = (String id) =>
        CardModel(id: id, front: '', back: '', state: CardState.learning);
    final reviewCard = (String id) =>
        CardModel(id: id, front: '', back: '', state: CardState.review);

    test('sessionLimit caps total queue length', () {
      final cards = [
        learningCard('l1'),
        reviewCard('r1'),
        newCard('n1'),
        newCard('n2'),
      ];
      final queue = buildSessionQueue(
          cards: cards, newLimit: testNewLimit, sessionLimit: 2);
      expect(queue.length, 2);
    });

    test('sessionLimit null applies no total cap', () {
      final cards = [
        learningCard('l1'),
        reviewCard('r1'),
        newCard('n1'),
      ];
      final queue = buildSessionQueue(
          cards: cards, newLimit: testNewLimit, sessionLimit: null);
      expect(queue.length, 3);
    });

    test('sessionLimit larger than available cards does not pad', () {
      final cards = [newCard('n1'), newCard('n2')];
      final queue = buildSessionQueue(
          cards: cards, newLimit: testNewLimit, sessionLimit: 50);
      expect(queue.length, 2);
    });

    test('sessionLimit priority: learning before review before new', () {
      final cards = [
        newCard('n1'),
        newCard('n2'),
        reviewCard('r1'),
        learningCard('l1'),
      ];
      final queue = buildSessionQueue(
          cards: cards, newLimit: testNewLimit, sessionLimit: 2);
      expect(queue[0].state, CardState.learning);
      expect(queue[1].state, CardState.review);
    });
  });
}
