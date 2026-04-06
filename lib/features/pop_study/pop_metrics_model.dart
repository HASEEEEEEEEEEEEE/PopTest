class PopMetrics {
  const PopMetrics({
    required this.trackedEventCount,
    required this.matchedEventCount,
    required this.matchedActiveSeconds,
    required this.popupShownCount,
    required this.popupStartCount,
    required this.popupSnoozeCount,
    required this.lastPopupAt,
    required this.lastStudyStartAt,
    required this.sessionStartedAt,
    required this.lastTrackedAt,
  });

  final int trackedEventCount;
  final int matchedEventCount;
  final int matchedActiveSeconds;
  final int popupShownCount;
  final int popupStartCount;
  final int popupSnoozeCount;
  final DateTime? lastPopupAt;
  final DateTime? lastStudyStartAt;
  final DateTime? sessionStartedAt;
  final DateTime? lastTrackedAt;

  PopMetrics copyWith({
    int? trackedEventCount,
    int? matchedEventCount,
    int? matchedActiveSeconds,
    int? popupShownCount,
    int? popupStartCount,
    int? popupSnoozeCount,
    DateTime? lastPopupAt,
    DateTime? lastStudyStartAt,
    DateTime? sessionStartedAt,
    DateTime? lastTrackedAt,
    bool clearLastPopupAt = false,
    bool clearLastStudyStartAt = false,
    bool clearSessionStartedAt = false,
    bool clearLastTrackedAt = false,
  }) {
    return PopMetrics(
      trackedEventCount: trackedEventCount ?? this.trackedEventCount,
      matchedEventCount: matchedEventCount ?? this.matchedEventCount,
      matchedActiveSeconds: matchedActiveSeconds ?? this.matchedActiveSeconds,
      popupShownCount: popupShownCount ?? this.popupShownCount,
      popupStartCount: popupStartCount ?? this.popupStartCount,
      popupSnoozeCount: popupSnoozeCount ?? this.popupSnoozeCount,
      lastPopupAt:
          clearLastPopupAt ? null : (lastPopupAt ?? this.lastPopupAt),
      lastStudyStartAt: clearLastStudyStartAt
          ? null
          : (lastStudyStartAt ?? this.lastStudyStartAt),
      sessionStartedAt: clearSessionStartedAt
          ? null
          : (sessionStartedAt ?? this.sessionStartedAt),
      lastTrackedAt:
          clearLastTrackedAt ? null : (lastTrackedAt ?? this.lastTrackedAt),
    );
  }

  factory PopMetrics.defaults() => const PopMetrics(
        trackedEventCount: 0,
        matchedEventCount: 0,
        matchedActiveSeconds: 0,
        popupShownCount: 0,
        popupStartCount: 0,
        popupSnoozeCount: 0,
        lastPopupAt: null,
        lastStudyStartAt: null,
        sessionStartedAt: null,
        lastTrackedAt: null,
      );
}
