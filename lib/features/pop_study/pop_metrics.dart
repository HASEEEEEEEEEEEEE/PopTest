import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_prefs.dart';
import 'pop_metrics_model.dart';

class PopMetricsNotifier extends Notifier<PopMetrics> {
  @override
  PopMetrics build() => ref.read(appPrefsProvider).loadPopMetrics();

  Future<void> _persist(PopMetrics next) async {
    state = next;
    await ref.read(appPrefsProvider).setPopMetrics(next);
  }

  Future<void> startSession(DateTime startedAt) async {
    await _persist(state.copyWith(
      sessionStartedAt: startedAt,
      lastTrackedAt: startedAt,
      clearLastStudyStartAt: true,
      clearLastPopupAt: true,
      matchedActiveSeconds: 0,
      clearViewingSeconds: true,
    ));
  }

  Future<void> stopSession() async {
    await _persist(state.copyWith(
      clearSessionStartedAt: true,
      clearLastTrackedAt: true,
      clearViewingSeconds: true,
    ));
  }

  Future<void> recordPopupShown(DateTime at) async {
    await _persist(state.copyWith(
      popupShownCount: state.popupShownCount + 1,
      lastPopupAt: at,
      clearViewingSeconds: true,
    ));
  }

  Future<void> recordTrackedEvent({
    required bool matchedTarget,
    required DateTime at,
  }) async {
    final since = state.lastTrackedAt ?? state.sessionStartedAt;
    final elapsed = since == null ? 0 : max(0, at.difference(since).inSeconds);
    final increment = matchedTarget && elapsed > 0 ? elapsed : 0;
    await _persist(state.copyWith(
      trackedEventCount: state.trackedEventCount + 1,
      matchedEventCount: state.matchedEventCount + (matchedTarget ? 1 : 0),
      matchedActiveSeconds: state.matchedActiveSeconds + increment,
      viewingSecondsForCurrentInterval:
          state.viewingSecondsForCurrentInterval + increment,
      lastTrackedAt: at,
    ));
  }

  Future<void> recordPopupStart(DateTime at) async {
    await _persist(state.copyWith(
      popupStartCount: state.popupStartCount + 1,
      lastStudyStartAt: at,
    ));
  }

  Future<void> recordPopupSnooze() async {
    await _persist(state.copyWith(
      popupSnoozeCount: state.popupSnoozeCount + 1,
    ));
  }
}

final popMetricsProvider = NotifierProvider<PopMetricsNotifier, PopMetrics>(
  PopMetricsNotifier.new,
);

bool hasReachedNextStudyTime(
  PopMetrics metrics,
  Duration interval,
  DateTime now,
) {
  if (metrics.sessionStartedAt == null) return false;
  return metrics.viewingSecondsForCurrentInterval >= interval.inSeconds;
}

String formatDurationAsMinutesSeconds(Duration duration) {
  final total = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
