import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_prefs.dart';
import 'pop_models.dart';

class PopSettingsNotifier extends Notifier<PopSettings> {
  @override
  PopSettings build() => ref.read(appPrefsProvider).loadPopSettings();

  Future<void> setPackageNames(Set<String> packageNames) async {
    state = state.copyWith(packageNames: packageNames);
    await ref.read(appPrefsProvider).setPopPackageNames(state.packageNames);
  }

  Future<void> addPackage(String packageName) async {
    final updated = Set<String>.of(state.packageNames)..add(packageName);
    await setPackageNames(updated);
  }

  Future<void> removePackage(String packageName) async {
    final updated = Set<String>.of(state.packageNames)..remove(packageName);
    await setPackageNames(updated);
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

  Future<void> setIntervalMinutes(int minutes) async {
    state = state.copyWith(intervalMinutes: minutes);
    await ref.read(appPrefsProvider).setPopIntervalMinutes(state.intervalMinutes);
  }

  Future<void> setPopCount(int count) async {
    state = state.copyWith(popCount: count);
    await ref.read(appPrefsProvider).setPopCount(state.popCount);
  }
}

final popSettingsProvider =
    NotifierProvider<PopSettingsNotifier, PopSettings>(
  PopSettingsNotifier.new,
);
