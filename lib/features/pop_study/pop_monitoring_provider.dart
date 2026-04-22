import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pop_study_controller.dart';
import '../../routing/router.dart';
import '../home/selected_deck_provider.dart';
import 'deck_pop_settings.dart';
import 'native_pop_monitoring.dart';
import 'pop_metrics.dart';
import 'pop_models.dart';
import 'pop_settings.dart';
import 'pop_study_active_provider.dart';

class PopMonitoringManager {
  PopMonitoringManager(this._ref, this._nativeBridge);

  final Ref _ref;
  final NativePopMonitoringBridge _nativeBridge;

  StreamSubscription<NativePopMonitoringEvent>? _eventSubscription;
  bool _syncInProgress = false;
  bool _syncPending = false;

  void start() {
    _eventSubscription = _nativeBridge.eventStream().listen(
      (event) {
        unawaited(_onNativeEvent(event));
      },
      onError: (error, stackTrace) {
        debugPrint('Native pop monitoring stream error: $error');
        unawaited(_syncNativeMonitoring());
      },
    );
    _ref.listen<bool>(
      popStudyActiveProvider,
      (_, __) => unawaited(_syncNativeMonitoring()),
      fireImmediately: true,
    );
    _ref.listen<String?>(
      selectedDeckProvider,
      (_, __) => unawaited(_syncNativeMonitoring()),
    );
    _ref.listen<PopSettings>(
      popSettingsProvider,
      (_, __) => unawaited(_syncNativeMonitoring()),
    );
  }

  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    unawaited(_nativeBridge.stopMonitoring());
  }

  Future<void> _syncNativeMonitoring() async {
    if (_syncInProgress) {
      _syncPending = true;
      return;
    }
    do {
      _syncPending = false;
      _syncInProgress = true;
      try {
        await _performSync();
      } finally {
        _syncInProgress = false;
      }
    } while (_syncPending);
  }

  Future<void> _performSync() async {
    final active = _ref.read(popStudyActiveProvider);
    if (!active) {
      await _nativeBridge.stopMonitoring();
      return;
    }
    final deckId = _ref.read(selectedDeckProvider);
    if (deckId == null || deckId.isEmpty) {
      await _nativeBridge.stopMonitoring();
      return;
    }
    final settings = _ref.read(effectivePopSettingsProvider(deckId));
    if (settings.packageNames.isEmpty && settings.customUrls.isEmpty) {
      await _nativeBridge.stopMonitoring();
      return;
    }
    final started = await _nativeBridge.startMonitoring(
      NativePopMonitoringConfig(
        packageNames: settings.packageNames,
        customUrls: settings.customUrls,
        intervalMinutes: settings.intervalMinutes,
        popCount: settings.popCount,
        deckId: deckId,
      ),
    );
    if (started) return;

    final status = await _nativeBridge.getPermissionStatus();
    if (status['accessibilityEnabled'] != true) {
      await _nativeBridge.openAccessibilitySettings();
    } else {
      await _nativeBridge.openUsageAccessSettings();
    }
    await _ref.read(popStudyActiveProvider.notifier).setActive(false);
  }

  Future<void> _onNativeEvent(NativePopMonitoringEvent event) async {
    final now = event.occurredAt;

    switch (event.eventType) {
      case NativeEventType.tracking:
        // ログ出力
        debugPrint(
          '[PopMonitor] tracking | '
          'matched=${event.matchedTarget} | '
          'pkg=${event.packageName} | '
          'url=${event.url ?? "-"}',
        );
        await _ref.read(popMetricsProvider.notifier).recordTrackedEvent(
              matchedTarget: event.matchedTarget,
              at: now,
            );

      case NativeEventType.popupShown:
        debugPrint('[PopMonitor] popupShown');
        await _ref.read(popMetricsProvider.notifier).recordPopupShown(now);

      case NativeEventType.popupSnooze:
        debugPrint('[PopMonitor] popupSnooze');
        await _ref.read(popMetricsProvider.notifier).recordPopupSnooze();

      case NativeEventType.popupStart:
        debugPrint('[PopMonitor] popupStart deckId=${event.deckId}');
        await _ref.read(popMetricsProvider.notifier).recordPopupStart(now);
        final deckId = event.deckId;
        if (deckId == null || deckId.isEmpty) return;
        // プロバイダーを強制リセット
        _ref.invalidate(popStudyProvider(deckId));
        final router = _ref.read(routerProvider);
        router.go('/decks/$deckId/pop'); // クエリパラメータ不要

      case NativeEventType.unknown:
        debugPrint('[PopMonitor] unknown event type');
    }
  }
}

final nativePopMonitoringBridgeProvider = Provider<NativePopMonitoringBridge>(
  (_) => NativePopMonitoringBridge(),
);

final popMonitoringProvider = Provider<PopMonitoringManager>((ref) {
  final manager =
      PopMonitoringManager(ref, ref.read(nativePopMonitoringBridgeProvider));
  ref.listen<bool>(popStudyActiveProvider, (previous, next) {
    Future.microtask(() {
      final metrics = ref.read(popMetricsProvider.notifier);
      if (next && previous != true) {
        metrics.startSession(DateTime.now());
      } else if (!next && previous == true) {
        metrics.stopSession();
      }
    });
  }, fireImmediately: true);
  manager.start();
  ref.onDispose(manager.dispose);
  return manager;
});
