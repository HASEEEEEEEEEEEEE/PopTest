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
    await _persist(state.copyWith(sessionStartedAt: startedAt));
  }

  Future<void> stopSession() async {
    await _persist(state.copyWith(clearSessionStartedAt: true));
  }

  Future<void> recordPopupShown(DateTime at) async {
    await _persist(state.copyWith(
      popupShownCount: state.popupShownCount + 1,
      lastPopupAt: at,
    ));
  }

  Future<void> recordTrackedEvent({required bool matchedTarget}) async {
    await _persist(state.copyWith(
      trackedEventCount: state.trackedEventCount + 1,
      matchedEventCount:
          state.matchedEventCount + (matchedTarget ? 1 : 0),
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
