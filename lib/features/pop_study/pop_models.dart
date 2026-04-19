/// Card states used by the spaced-repetition scheduler.
enum CardState { newCard, learning, review }

/// SNS services selectable for pop-study interruption.
enum PopService {
  twitter('Twitter / X'),
  instagram('Instagram'),
  youtube('YouTube'),
  tiktok('TikTok');

  const PopService(this.label);
  final String label;
}

/// Review quality ratings (SM-2 algorithm).
enum ReviewRating {
  again, // 完全に忘れた
  hard, // 難しかった
  good, // 覚えていた
  easy, // 簡単だった
}

class PopSettings {
  const PopSettings({
    required this.services,
    required this.customUrls,
    required this.intervalMinutes,
    required this.popCount,
  });

  static const int defaultIntervalMinutes = 30;
  static const int defaultPopCount = 3;
  static const int minIntervalMinutes = 1;
  static const int maxIntervalMinutes = 120;
  static const int minPopCount = 1;
  static const int maxPopCount = 10;

  final Set<PopService> services;
  final Set<String> customUrls;
  final int intervalMinutes;
  final int popCount;

  factory PopSettings.defaults() => const PopSettings(
        services: {},
        customUrls: {},
        intervalMinutes: defaultIntervalMinutes,
        popCount: defaultPopCount,
      );

  PopSettings copyWith({
    Set<PopService>? services,
    Set<String>? customUrls,
    int? intervalMinutes,
    int? popCount,
  }) {
    return PopSettings(
      services: services ?? this.services,
      customUrls: customUrls ?? this.customUrls,
      intervalMinutes: (intervalMinutes ?? this.intervalMinutes)
          .clamp(minIntervalMinutes, maxIntervalMinutes),
      popCount: (popCount ?? this.popCount).clamp(minPopCount, maxPopCount),
    );
  }
}

class DeckPopSettings {
  const DeckPopSettings({
    required this.useGlobal,
    required this.services,
    required this.customUrls,
    required this.intervalMinutes,
    required this.popCount,
  });

  final bool useGlobal;
  final Set<PopService> services;
  final Set<String> customUrls;
  final int intervalMinutes;
  final int popCount;

  factory DeckPopSettings.defaults() => const DeckPopSettings(
        useGlobal: true,
        services: {},
        customUrls: {},
        intervalMinutes: PopSettings.defaultIntervalMinutes,
        popCount: PopSettings.defaultPopCount,
      );

  DeckPopSettings copyWith({
    bool? useGlobal,
    Set<PopService>? services,
    Set<String>? customUrls,
    int? intervalMinutes,
    int? popCount,
  }) {
    return DeckPopSettings(
      useGlobal: useGlobal ?? this.useGlobal,
      services: services ?? this.services,
      customUrls: customUrls ?? this.customUrls,
      intervalMinutes: (intervalMinutes ?? this.intervalMinutes).clamp(
          PopSettings.minIntervalMinutes, PopSettings.maxIntervalMinutes),
      popCount: (popCount ?? this.popCount)
          .clamp(PopSettings.minPopCount, PopSettings.maxPopCount),
    );
  }

  PopSettings resolve(PopSettings global) {
    if (useGlobal) return global;
    return PopSettings(
      services: services,
      customUrls: customUrls,
      intervalMinutes: intervalMinutes,
      popCount: popCount,
    );
  }
}

/// Card model with SM-2 spaced-repetition fields.
class CardModel {
  const CardModel({
    required this.id,
    required this.front,
    required this.back,
    required this.state,
    this.dueAt,
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    this.lapses = 0,
  });

  final String id;
  final String front;
  final String back;
  final CardState state;

  /// 次回復習予定日時（null=未スケジュール）
  final DateTime? dueAt;

  /// 次の復習まで何日か（SM-2）
  final int intervalDays;

  /// 難易度係数（SM-2、初期値2.5、最小1.3）
  final double easeFactor;

  /// 連続正解回数（SM-2）
  final int repetitions;

  /// 忘却回数（統計用）
  final int lapses;

  CardModel copyWith({
    String? id,
    String? front,
    String? back,
    CardState? state,
    DateTime? dueAt,
    int? intervalDays,
    double? easeFactor,
    int? repetitions,
    int? lapses,
    bool clearDueAt = false,
  }) {
    return CardModel(
      id: id ?? this.id,
      front: front ?? this.front,
      back: back ?? this.back,
      state: state ?? this.state,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
      repetitions: repetitions ?? this.repetitions,
      lapses: lapses ?? this.lapses,
    );
  }
}
