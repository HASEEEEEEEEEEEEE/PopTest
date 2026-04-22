import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:poptest/data/local/app_prefs.dart';
import 'package:poptest/features/pop_study/pop_models.dart';
import 'package:poptest/features/pop_study/pop_counts.dart';

void main() {
  group('PopSettings', () {
    test('defaults have correct values', () {
      final s = PopSettings.defaults();
      expect(s.packageNames, isEmpty);
      expect(s.customUrls, isEmpty);
      expect(s.intervalMinutes, PopSettings.defaultIntervalMinutes);
      expect(s.popCount, PopSettings.defaultPopCount);
    });

    test('copyWith overrides individual fields', () {
      final s = PopSettings.defaults().copyWith(
        packageNames: {'com.twitter.android'},
        intervalMinutes: 15,
        popCount: 5,
      );
      expect(s.packageNames, {'com.twitter.android'});
      expect(s.customUrls, isEmpty);
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
      final original = PopSettings.defaults().copyWith(
        packageNames: {'com.google.android.youtube'},
        intervalMinutes: 45,
      );
      final updated = original.copyWith(popCount: 7);
      expect(updated.packageNames, {'com.google.android.youtube'});
      expect(updated.intervalMinutes, 45);
      expect(updated.popCount, 7);
    });

    test('effectiveUrls includes derived URL patterns for known packages', () {
      final s = PopSettings.defaults().copyWith(
        packageNames: {'com.twitter.android'},
        customUrls: {'example.com'},
      );
      expect(s.effectiveUrls, containsAll(['twitter.com', 'x.com', 'example.com']));
    });
  });

  group('DeckPopSettings', () {
    test('defaults use global settings', () {
      final s = DeckPopSettings.defaults();
      expect(s.useGlobal, isTrue);
      expect(s.packageNames, isEmpty);
      expect(s.customUrls, isEmpty);
      expect(s.intervalMinutes, PopSettings.defaultIntervalMinutes);
      expect(s.popCount, PopSettings.defaultPopCount);
    });

    test('resolve returns global when useGlobal is true', () {
      final global = PopSettings.defaults().copyWith(
        packageNames: {'com.instagram.android'},
        intervalMinutes: 12,
        popCount: 5,
      );
      final deck = DeckPopSettings.defaults().copyWith(
        useGlobal: true,
        packageNames: {'com.twitter.android'},
        intervalMinutes: 99,
        popCount: 9,
      );
      final resolved = deck.resolve(global);
      expect(resolved.packageNames, global.packageNames);
      expect(resolved.customUrls, global.customUrls);
      expect(resolved.intervalMinutes, global.intervalMinutes);
      expect(resolved.popCount, global.popCount);
    });

    test('resolve returns deck overrides when useGlobal is false', () {
      final global = PopSettings.defaults();
      final deck = DeckPopSettings.defaults().copyWith(
        useGlobal: false,
        packageNames: {'com.google.android.youtube'},
        intervalMinutes: 25,
        popCount: 6,
      );
      final resolved = deck.resolve(global);
      expect(resolved.packageNames, {'com.google.android.youtube'});
      expect(resolved.customUrls, isEmpty);
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
      expect(s.packageNames, isEmpty);
      expect(s.customUrls, isEmpty);
      expect(s.intervalMinutes, PopSettings.defaultIntervalMinutes);
      expect(s.popCount, PopSettings.defaultPopCount);
    });

    test('setPopPackageNames / loadPopSettings round-trip', () async {
      const pkgs = {'com.google.android.youtube', 'com.twitter.android'};
      await prefs.setPopPackageNames(pkgs);
      final s = prefs.loadPopSettings();
      expect(s.packageNames, pkgs);
    });

    test('setPopPackageNames with empty set removes the stored value', () async {
      await prefs.setPopPackageNames({'com.twitter.android'});
      await prefs.setPopPackageNames({});
      final s = prefs.loadPopSettings();
      expect(s.packageNames, isEmpty);
    });

    test('setPopIntervalMinutes / loadPopSettings round-trip', () async {
      await prefs.setPopIntervalMinutes(10);
      expect(prefs.loadPopSettings().intervalMinutes, 10);
    });

    test('setPopCount / loadPopSettings round-trip', () async {
      await prefs.setPopCount(7);
      expect(prefs.loadPopSettings().popCount, 7);
    });

    test('setPopCustomUrls / loadPopSettings round-trip', () async {
      await prefs.setPopCustomUrls({'youtube.com', 'x.com/home'});
      final s = prefs.loadPopSettings();
      expect(s.customUrls, {'youtube.com', 'x.com/home'});
    });

    test('persisted out-of-range values are clamped on load', () async {
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

    test('legacy pop_services key is migrated to packageNames on first load',
        () async {
      SharedPreferences.setMockInitialValues({
        'pop_services': 'twitter,instagram',
      });
      final sp2 = await SharedPreferences.getInstance();
      final prefs2 = AppPrefs(sp2);
      final s = prefs2.loadPopSettings();
      expect(s.packageNames, contains('com.twitter.android'));
      expect(s.packageNames, contains('com.instagram.android'));
    });

    test('partial package subset is persisted and restored correctly',
        () async {
      const pkgs = {'com.google.android.youtube', 'com.zhiliaoapp.musically'};
      await prefs.setPopPackageNames(pkgs);
      final s = prefs.loadPopSettings();
      expect(s.packageNames, pkgs);
      expect(s.packageNames.contains('com.twitter.android'), isFalse);
    });
  });

  group('buildSessionQueue – sessionLimit', () {
    const testNewLimit = 10;

    CardModel newCard(String id) =>
        CardModel(id: id, front: '', back: '', state: CardState.newCard);
    CardModel learningCard(String id) =>
        CardModel(id: id, front: '', back: '', state: CardState.learning);
    CardModel reviewCard(String id) =>
        CardModel(id: id, front: '', back: '', state: CardState.review);

    test('sessionLimit caps total queue length', () {
      final cards = [
        learningCard('l1'),
        reviewCard('r1'),
        newCard('n1'),
        newCard('n2'),
      ];
      final queue =
          buildSessionQueue(cards: cards, newLimit: testNewLimit, sessionLimit: 2);
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
      final queue =
          buildSessionQueue(cards: cards, newLimit: testNewLimit, sessionLimit: 50);
      expect(queue.length, 2);
    });

    test('sessionLimit priority: learning before review before new', () {
      final cards = [
        newCard('n1'),
        newCard('n2'),
        reviewCard('r1'),
        learningCard('l1'),
      ];
      final queue =
          buildSessionQueue(cards: cards, newLimit: testNewLimit, sessionLimit: 2);
      expect(queue[0].state, CardState.learning);
      expect(queue[1].state, CardState.review);
    });
  });
}
