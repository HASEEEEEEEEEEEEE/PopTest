import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_prefs.dart';

/// Persists the deck ID that is used for pop-study from the home screen.
///
/// Null means "not yet selected".
class SelectedDeckNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(appPrefsProvider).selectedDeckId;

  Future<void> select(String? deckId) async {
    state = deckId;
    await ref.read(appPrefsProvider).setSelectedDeckId(deckId);
  }
}

final selectedDeckProvider =
    NotifierProvider<SelectedDeckNotifier, String?>(SelectedDeckNotifier.new);
