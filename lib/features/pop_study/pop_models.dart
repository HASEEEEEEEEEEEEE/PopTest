/// Card states used by the spaced-repetition scheduler.
enum CardState { newCard, learning, review }

/// SNS services selectable for pop-study interruption.
enum PopService {
  twitter('Twitter / X'),
  instagram('Instagram'),
  youtube('YouTube'),
  tiktok('TikTok');

  const PopService(this.label);

  /// Human-readable Japanese-friendly label.
  final String label;
}

/// Immutable settings model for the pop-study feature.
class PopSettings {
  const PopSettings({
    required this.services,
    required this.intervalMinutes,
    required this.popCount,
  });

  // ── Defaults ───────────────────────────────────────────────────────────────

  static const int defaultIntervalMinutes = 30;
  static const int defaultPopCount = 3;

  // ── Validation bounds ──────────────────────────────────────────────────────

  static const int minIntervalMinutes = 1;
  static const int maxIntervalMinutes = 120;
  static const int minPopCount = 1;
  static const int maxPopCount = 10;

  // ── Fields ─────────────────────────────────────────────────────────────────

  /// SNS services for which pop-study is enabled. Empty = no interruption.
  final Set<PopService> services;

  /// Interval between pop-study sessions (minutes).
  final int intervalMinutes;

  /// Number of questions shown per pop-study session.
  final int popCount;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns a [PopSettings] with all values set to their defaults.
  factory PopSettings.defaults() => const PopSettings(
        services: {},
        intervalMinutes: defaultIntervalMinutes,
        popCount: defaultPopCount,
      );

  /// [intervalMinutes] and [popCount] are clamped to their valid ranges.
  PopSettings copyWith({
    Set<PopService>? services,
    int? intervalMinutes,
    int? popCount,
  }) {
    return PopSettings(
      services: services ?? this.services,
      intervalMinutes: (intervalMinutes ?? this.intervalMinutes)
          .clamp(minIntervalMinutes, maxIntervalMinutes),
      popCount:
          (popCount ?? this.popCount).clamp(minPopCount, maxPopCount),
    );
  }
}

/// Deck-level pop settings.
///
/// If [useGlobal] is true, deck-specific fields are ignored and global
/// [PopSettings] are used instead.
class DeckPopSettings {
  const DeckPopSettings({
    required this.useGlobal,
    required this.services,
    required this.intervalMinutes,
    required this.popCount,
  });

  final bool useGlobal;
  final Set<PopService> services;
  final int intervalMinutes;
  final int popCount;

  factory DeckPopSettings.defaults() => const DeckPopSettings(
        useGlobal: true,
        services: {},
        intervalMinutes: PopSettings.defaultIntervalMinutes,
        popCount: PopSettings.defaultPopCount,
      );

  DeckPopSettings copyWith({
    bool? useGlobal,
    Set<PopService>? services,
    int? intervalMinutes,
    int? popCount,
  }) {
    return DeckPopSettings(
      useGlobal: useGlobal ?? this.useGlobal,
      services: services ?? this.services,
      intervalMinutes: (intervalMinutes ?? this.intervalMinutes)
          .clamp(PopSettings.minIntervalMinutes, PopSettings.maxIntervalMinutes),
      popCount:
          (popCount ?? this.popCount).clamp(PopSettings.minPopCount, PopSettings.maxPopCount),
    );
  }

  PopSettings resolve(PopSettings global) {
    if (useGlobal) return global;
    return PopSettings(
      services: services,
      intervalMinutes: intervalMinutes,
      popCount: popCount,
    );
  }
}

/// Lightweight in-memory card model.
/// TODO: replace with Drift entity in issue #2.
class CardModel {
  const CardModel({
    required this.id,
    required this.front,
    required this.back,
    required this.state,
    this.dueAt,
  });

  final String id;
  final String front;
  final String back;
  final CardState state;
  final DateTime? dueAt;

  CardModel copyWith({
    String? id,
    String? front,
    String? back,
    CardState? state,
    DateTime? dueAt,
  }) {
    return CardModel(
      id: id ?? this.id,
      front: front ?? this.front,
      back: back ?? this.back,
      state: state ?? this.state,
      dueAt: dueAt ?? this.dueAt,
    );
  }
}
