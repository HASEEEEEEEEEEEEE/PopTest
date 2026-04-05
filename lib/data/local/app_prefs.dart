import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/pop_study/pop_models.dart';

/// Thin wrapper around [SharedPreferences] for app-level persistence.
///
/// Stores:
/// * The ID of the deck selected for pop-study (nullable).
/// * Per-card learning states, keyed by `card_state_{deckId}_{cardId}`.
/// * Pop-study settings: target services, interval, and per-session count.
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
        'new' => CardState.newCard,
        'learning' => CardState.learning,
        'review' => CardState.review,
        _ => CardState.newCard, // forward-compat fallback
      };

  // ── Pop-study settings ─────────────────────────────────────────────────────

  static const _keyPopServices = 'pop_services';
  static const _keyPopIntervalMinutes = 'pop_interval_minutes';
  static const _keyPopCount = 'pop_count';
  static const _prefixDeckPopUseGlobal = 'deck_pop_use_global_';
  static const _prefixDeckPopServices = 'deck_pop_services_';
  static const _prefixDeckPopIntervalMinutes = 'deck_pop_interval_minutes_';
  static const _prefixDeckPopCount = 'deck_pop_count_';
  static const _prefixDeckName = 'deck_name_';
  static const _prefixDeckCards = 'deck_cards_';

  /// Loads all pop-study settings, falling back to [PopSettings.defaults].
  PopSettings loadPopSettings() {
    final serviceNames = _prefs.getString(_keyPopServices);
    final services = serviceNames == null || serviceNames.isEmpty
        ? const <PopService>{}
        : serviceNames
            .split(',')
            .map(_parsePopService)
            .whereType<PopService>()
            .toSet();

    final intervalMinutes = _prefs.getInt(_keyPopIntervalMinutes) ??
        PopSettings.defaultIntervalMinutes;
    final popCount =
        _prefs.getInt(_keyPopCount) ?? PopSettings.defaultPopCount;

    return PopSettings(
      services: services,
      intervalMinutes: intervalMinutes.clamp(
          PopSettings.minIntervalMinutes, PopSettings.maxIntervalMinutes),
      popCount:
          popCount.clamp(PopSettings.minPopCount, PopSettings.maxPopCount),
    );
  }

  Future<void> setPopServices(Set<PopService> services) async {
    if (services.isEmpty) {
      await _prefs.remove(_keyPopServices);
    } else {
      await _prefs.setString(
          _keyPopServices, services.map(_serializePopService).join(','));
    }
  }

  Future<void> setPopIntervalMinutes(int minutes) async {
    await _prefs.setInt(_keyPopIntervalMinutes, minutes);
  }

  Future<void> setPopCount(int count) async {
    await _prefs.setInt(_keyPopCount, count);
  }

  DeckPopSettings loadDeckPopSettings(String deckId) {
    final useGlobal = _prefs.getBool('$_prefixDeckPopUseGlobal$deckId') ?? true;
    final serviceNames = _prefs.getString('$_prefixDeckPopServices$deckId');
    final services = serviceNames == null || serviceNames.isEmpty
        ? const <PopService>{}
        : serviceNames
            .split(',')
            .map(_parsePopService)
            .whereType<PopService>()
            .toSet();
    final intervalMinutes = _prefs.getInt('$_prefixDeckPopIntervalMinutes$deckId') ??
        PopSettings.defaultIntervalMinutes;
    final popCount =
        _prefs.getInt('$_prefixDeckPopCount$deckId') ?? PopSettings.defaultPopCount;

    return DeckPopSettings(
      useGlobal: useGlobal,
      services: services,
      intervalMinutes: intervalMinutes.clamp(
          PopSettings.minIntervalMinutes, PopSettings.maxIntervalMinutes),
      popCount:
          popCount.clamp(PopSettings.minPopCount, PopSettings.maxPopCount),
    );
  }

  Future<void> setDeckPopSettings(String deckId, DeckPopSettings settings) async {
    await _prefs.setBool('$_prefixDeckPopUseGlobal$deckId', settings.useGlobal);
    if (settings.services.isEmpty) {
      await _prefs.remove('$_prefixDeckPopServices$deckId');
    } else {
      await _prefs.setString('$_prefixDeckPopServices$deckId',
          settings.services.map(_serializePopService).join(','));
    }
    await _prefs.setInt(
        '$_prefixDeckPopIntervalMinutes$deckId', settings.intervalMinutes);
    await _prefs.setInt('$_prefixDeckPopCount$deckId', settings.popCount);
  }

  Future<void> setDeckName(String deckId, String name) async {
    await _prefs.setString('$_prefixDeckName$deckId', name);
  }

  String? getDeckName(String deckId) => _prefs.getString('$_prefixDeckName$deckId');

  Future<void> setDeckCards(String deckId, List<CardModel> cards) async {
    final rows = cards
        .map((c) => jsonEncode({
              'id': c.id,
              'front': c.front,
              'back': c.back,
              'state': _serializeCardState(c.state),
            }))
        .toList();
    await _prefs.setStringList('$_prefixDeckCards$deckId', rows);
  }

  List<CardModel>? getDeckCards(String deckId) {
    final rows = _prefs.getStringList('$_prefixDeckCards$deckId');
    if (rows == null) return null;
    final cards = <CardModel>[];
    for (final row in rows) {
      dynamic decoded;
      try {
        decoded = jsonDecode(row);
      } catch (_) {
        continue;
      }
      if (decoded is! Map<String, dynamic>) continue;
      final id = decoded['id'];
      final front = decoded['front'];
      final back = decoded['back'];
      final state = decoded['state'];
      if (id is! String || front is! String || back is! String || state is! String) {
        continue;
      }
      cards.add(CardModel(
        id: id,
        front: front,
        back: back,
        state: _parseCardState(state),
      ));
    }
    return cards;
  }

  static String _serializePopService(PopService s) => s.name;

  static PopService? _parsePopService(String raw) {
    for (final s in PopService.values) {
      if (s.name == raw) return s;
    }
    return null; // forward-compat: unknown values are silently dropped
  }

  // ── Pop-study active state ─────────────────────────────────────────────────

  static const _keyPopStudyActive = 'pop_study_active';

  /// Whether pop-study monitoring mode is currently enabled.
  bool get popStudyActive => _prefs.getBool(_keyPopStudyActive) ?? false;

  Future<void> setPopStudyActive(bool active) async {
    await _prefs.setBool(_keyPopStudyActive, active);
  }
}

/// Must be overridden in [main] with a real [AppPrefs] instance.
final appPrefsProvider = Provider<AppPrefs>(
  (ref) => throw UnimplementedError(
      'appPrefsProvider must be overridden in main()'),
);
