import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_prefs.dart';

/// Notifier that tracks whether pop-study monitoring mode is active.
///
/// The active state is persisted via [AppPrefs] so it survives app restarts.
class PopStudyActiveNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(appPrefsProvider).popStudyActive;

  Future<void> setActive(bool value) async {
    state = value;
    await ref.read(appPrefsProvider).setPopStudyActive(value);
  }

  Future<void> toggle() => setActive(!state);
}

final popStudyActiveProvider =
    NotifierProvider<PopStudyActiveNotifier, bool>(
  PopStudyActiveNotifier.new,
);
