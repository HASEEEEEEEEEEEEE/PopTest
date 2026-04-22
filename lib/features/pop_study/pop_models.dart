/// Card states used by the spaced-repetition scheduler.
enum CardState { newCard, learning, review }

/// Review quality ratings (SM-2 algorithm).
enum ReviewRating {
  again, // 完全に忘れた
  hard, // 難しかった
  good, // 覚えていた
  easy, // 簡単だった
}

/// URL patterns associated with well-known social-media packages.
/// When a package is selected for monitoring, its URL patterns are
/// automatically included so browser-based access is also tracked.
const Map<String, Set<String>> knownPackageUrlPatterns = {
  'com.google.android.youtube': {'youtube.com', 'youtu.be', 'm.youtube.com'},
  'app.rvx.android.youtube': {'youtube.com', 'youtu.be', 'm.youtube.com'},
  'com.twitter.android': {'twitter.com', 'x.com'},
  'com.instagram.android': {'instagram.com'},
  'com.zhiliaoapp.musically': {'tiktok.com'},
  'com.ss.android.ugc.trill': {'tiktok.com'},
};

class PopSettings {
  const PopSettings({
    required this.packageNames,
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

  final Set<String> packageNames;
  final Set<String> customUrls;
  final int intervalMinutes;
  final int popCount;

  /// All URL patterns to monitor: [customUrls] + those derived from [packageNames].
  Set<String> get effectiveUrls {
    final urls = Set<String>.of(customUrls);
    for (final pkg in packageNames) {
      urls.addAll(knownPackageUrlPatterns[pkg] ?? const {});
    }
    return urls;
  }

  factory PopSettings.defaults() => const PopSettings(
        packageNames: {},
        customUrls: {},
        intervalMinutes: defaultIntervalMinutes,
        popCount: defaultPopCount,
      );

  PopSettings copyWith({
    Set<String>? packageNames,
    Set<String>? customUrls,
    int? intervalMinutes,
    int? popCount,
  }) {
    return PopSettings(
      packageNames: packageNames ?? this.packageNames,
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
    required this.packageNames,
    required this.customUrls,
    required this.intervalMinutes,
    required this.popCount,
  });

  final bool useGlobal;
  final Set<String> packageNames;
  final Set<String> customUrls;
  final int intervalMinutes;
  final int popCount;

  factory DeckPopSettings.defaults() => const DeckPopSettings(
        useGlobal: true,
        packageNames: {},
        customUrls: {},
        intervalMinutes: PopSettings.defaultIntervalMinutes,
        popCount: PopSettings.defaultPopCount,
      );

  DeckPopSettings copyWith({
    bool? useGlobal,
    Set<String>? packageNames,
    Set<String>? customUrls,
    int? intervalMinutes,
    int? popCount,
  }) {
    return DeckPopSettings(
      useGlobal: useGlobal ?? this.useGlobal,
      packageNames: packageNames ?? this.packageNames,
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
      packageNames: packageNames,
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
  final DateTime? dueAt;
  final int intervalDays;
  final double easeFactor;
  final int repetitions;
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
