import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/pop_study/pop_models.dart';

/// Thin wrapper around [SharedPreferences] for app-level persistence.
///
/// Stores:
/// * The ID of the deck selected for pop-study (nullable).
/// * Per-card learning states, keyed by `card_state_{deckId}_{cardId}`.
class AppPrefs {
  AppPrefs(this._prefs);

  final SharedPreferences _prefs;

  // ── Selected deck ──────────────────────────────────────────────────────────

  static const _keySelectedDeck = 'selected_deck_id';

  String? get selectedDeckId => _prefs.getString(_keySelectedDeck);

  Future<void> setSelectedDeckId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keySelectedDeck);
    } else {
      await _prefs.setString(_keySelectedDeck, id);
    }
  }

  // ── Card states ────────────────────────────────────────────────────────────

  static const _prefixCardState = 'card_state_';

  String _cardStateKey(String deckId, String cardId) =>
      '$_prefixCardState${deckId}_$cardId';

  CardState? getCardState(String deckId, String cardId) {
    final raw = _prefs.getString(_cardStateKey(deckId, cardId));
    return raw == null ? null : _parseCardState(raw);
  }

  Future<void> setCardState(
      String deckId, String cardId, CardState state) async {
    await _prefs.setString(
        _cardStateKey(deckId, cardId), _serializeCardState(state));
  }

  /// Returns a map of cardId → persisted [CardState] for all given [cardIds].
  /// Cards with no saved state are omitted (caller uses the model default).
  Map<String, CardState> loadCardStates(
      String deckId, Iterable<String> cardIds) {
    final result = <String, CardState>{};
    for (final cardId in cardIds) {
      final s = getCardState(deckId, cardId);
      if (s != null) result[cardId] = s;
    }
    return result;
  }

  // ── Serialization helpers ──────────────────────────────────────────────────

  static String _serializeCardState(CardState state) => switch (state) {
        CardState.newCard => 'new',
        CardState.learning => 'learning',
        CardState.review => 'review',
      };

  static CardState _parseCardState(String raw) => switch (raw) {
        'learning' => CardState.learning,
        'review' => CardState.review,
        _ => CardState.newCard, // default / forward-compat
      };
}

/// Must be overridden in [main] with a real [AppPrefs] instance.
final appPrefsProvider = Provider<AppPrefs>(
  (ref) => throw UnimplementedError(
      'appPrefsProvider must be overridden in main()'),
);
