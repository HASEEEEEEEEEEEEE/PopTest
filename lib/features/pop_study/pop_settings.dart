import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_prefs.dart';
import 'pop_models.dart';

/// Riverpod notifier that loads / persists [PopSettings] via [AppPrefs].
class PopSettingsNotifier extends Notifier<PopSettings> {
  @override
  PopSettings build() => ref.read(appPrefsProvider).loadPopSettings();

  /// Updates the set of selected services and persists the change.
  Future<void> setServices(Set<PopService> services) async {
    state = state.copyWith(services: services);
    await ref.read(appPrefsProvider).setPopServices(state.services);
  }

  Future<void> setCustomUrls(Set<String> customUrls) async {
    state = state.copyWith(customUrls: customUrls);
    await ref.read(appPrefsProvider).setPopCustomUrls(state.customUrls);
  }

  Future<void> addCustomUrl(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return;
    final updated = Set<String>.of(state.customUrls)..add(url);
    await setCustomUrls(updated);
  }

  Future<void> removeCustomUrl(String url) async {
    final updated = Set<String>.of(state.customUrls)..remove(url);
    await setCustomUrls(updated);
  }

  /// Toggles [service] in/out of the selected set and persists the change.
  Future<void> toggleService(PopService service) async {
    final updated = Set<PopService>.of(state.services);
    if (updated.contains(service)) {
      updated.remove(service);
    } else {
      updated.add(service);
    }
    await setServices(updated);
  }

  /// Updates the interval (minutes) and persists the change.
  Future<void> setIntervalMinutes(int minutes) async {
    state = state.copyWith(intervalMinutes: minutes);
    await ref
        .read(appPrefsProvider)
        .setPopIntervalMinutes(state.intervalMinutes);
  }

  /// Updates the per-session question count and persists the change.
  Future<void> setPopCount(int count) async {
    state = state.copyWith(popCount: count);
    await ref.read(appPrefsProvider).setPopCount(state.popCount);
  }
}

final popSettingsProvider =
    NotifierProvider<PopSettingsNotifier, PopSettings>(
  PopSettingsNotifier.new,
);
