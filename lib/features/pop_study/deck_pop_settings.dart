import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_prefs.dart';
import 'pop_models.dart';
import 'pop_settings.dart';

class DeckPopSettingsNotifier
    extends AutoDisposeFamilyNotifier<DeckPopSettings, String> {
  @override
  DeckPopSettings build(String deckId) =>
      ref.read(appPrefsProvider).loadDeckPopSettings(deckId);

  Future<void> _persist(DeckPopSettings next) async {
    state = next;
    await ref.read(appPrefsProvider).setDeckPopSettings(arg, next);
  }

  Future<void> setUseGlobal(bool value) async {
    await _persist(state.copyWith(useGlobal: value));
  }

  Future<void> toggleService(PopService service) async {
    final updated = Set<PopService>.of(state.services);
    if (updated.contains(service)) {
      updated.remove(service);
    } else {
      updated.add(service);
    }
    await _persist(state.copyWith(services: updated));
  }

  Future<void> setIntervalMinutes(int minutes) async {
    await _persist(state.copyWith(intervalMinutes: minutes));
  }

  Future<void> setPopCount(int count) async {
    await _persist(state.copyWith(popCount: count));
  }
}

final deckPopSettingsProvider = NotifierProvider.autoDispose
    .family<DeckPopSettingsNotifier, DeckPopSettings, String>(
  DeckPopSettingsNotifier.new,
);

final effectivePopSettingsProvider =
    Provider.autoDispose.family<PopSettings, String>((ref, deckId) {
  final global = ref.watch(popSettingsProvider);
  final deck = ref.watch(deckPopSettingsProvider(deckId));
  return deck.resolve(global);
});
