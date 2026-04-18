import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routing/router.dart';
import '../home/selected_deck_provider.dart';
import 'deck_pop_settings.dart';
import 'native_pop_monitoring.dart';
import 'pop_metrics.dart';
import 'pop_models.dart';
import 'pop_settings.dart';
import 'pop_study_active_provider.dart';

/// Starts/stops Android native monitoring and opens pop sessions in Flutter.
class PopMonitoringManager {
  PopMonitoringManager(this._ref, this._nativeBridge);

  final Ref _ref;
  final NativePopMonitoringBridge _nativeBridge;

  StreamSubscription<NativePopMonitoringEvent>? _eventSubscription;
  StreamSubscription<String>? _startPopStudySubscription;
  bool _syncInProgress = false;
  bool _syncPending = false;

  void start() {
    _eventSubscription = _nativeBridge.eventStream().listen(
      (event) {
        unawaited(_onNativeEvent(event));
      },
      onError: (error, stackTrace) {
        debugPrint('Native pop monitoring stream error: $error');
        debugPrint('$stackTrace');
        unawaited(_syncNativeMonitoring());
      },
    );
    _startPopStudySubscription = _nativeBridge.startPopStudyStream().listen(
      (deckId) {
        unawaited(_openPopStudyDeck(deckId));
      },
      onError: (error, stackTrace) {
        debugPrint('Native startPopStudy stream error: $error');
        debugPrint('$stackTrace');
      },
    );
    unawaited(_consumePendingStartDeck());
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
    _startPopStudySubscription?.cancel();
    _eventSubscription = null;
    _startPopStudySubscription = null;
    unawaited(_nativeBridge.stopMonitoring());
    _nativeBridge.dispose();
  }

  Future<void> _syncNativeMonitoring() async {
    if (_syncInProgress) {
      _syncPending = true;
      return;
    }
    // Coalesce rapid state changes into sequential syncs and always apply
    // the latest monitoring configuration.
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
    if (settings.services.isEmpty && settings.customUrls.isEmpty) {
      await _nativeBridge.stopMonitoring();
      return;
    }
    final started = await _nativeBridge.startMonitoring(
      NativePopMonitoringConfig(
        deckId: deckId,
        services: settings.services,
        customUrls: settings.customUrls,
        intervalMinutes: settings.intervalMinutes,
        popCount: settings.popCount,
      ),
    );
    if (started) return;

    final status = await _nativeBridge.getPermissionStatus();
    final hasUsageAccess = status['usageAccess'] == true;
    final hasAccessibility = status['accessibilityEnabled'] == true;
    final hasOverlay = status['overlayEnabled'] == true;
    if (!hasUsageAccess) {
      await _nativeBridge.openUsageAccessSettings();
    } else if (!hasAccessibility) {
      await _nativeBridge.openAccessibilitySettings();
    } else if (!hasOverlay) {
      await _nativeBridge.openOverlaySettings();
    }
    await _ref.read(popStudyActiveProvider.notifier).setActive(false);
  }

  Future<void> _onNativeEvent(NativePopMonitoringEvent event) async {
    final active = _ref.read(popStudyActiveProvider);
    if (!active) return;

    if (event.type == NativePopMonitoringEventType.popupShown) {
      await _ref.read(popMetricsProvider.notifier).recordPopupShown(event.occurredAt);
      return;
    }
    if (event.type == NativePopMonitoringEventType.popupSnooze) {
      await _ref.read(popMetricsProvider.notifier).recordPopupSnooze();
      return;
    }
    if (event.type == NativePopMonitoringEventType.popupStart) {
      await _ref.read(popMetricsProvider.notifier).recordPopupStart(event.occurredAt);
      return;
    }

    final deckId = _ref.read(selectedDeckProvider);
    if (deckId == null || deckId.isEmpty) return;
    final settings = _ref.read(effectivePopSettingsProvider(deckId));
    final hasTargets =
        settings.services.isNotEmpty || settings.customUrls.isNotEmpty;
    if (!hasTargets) return;

    await _ref
        .read(popMetricsProvider.notifier)
        .recordTrackedEvent(matchedTarget: event.matchedTarget, at: event.occurredAt);
  }

  Future<void> _consumePendingStartDeck() async {
    final deckId = await _nativeBridge.consumePendingStartDeckId();
    if (deckId == null || deckId.isEmpty) return;
    await _openPopStudyDeck(deckId);
  }

  Future<void> _openPopStudyDeck(String deckId) async {
    final router = _ref.read(routerProvider);
    final path = '/decks/$deckId/pop';
    if (router.routeInformationProvider.value.uri.path == path) return;
    router.go(path);
  }
}

final nativePopMonitoringBridgeProvider = Provider<NativePopMonitoringBridge>(
  (_) => NativePopMonitoringBridge(),
);

// 修正後
final popMonitoringProvider = Provider<PopMonitoringManager>((ref) {
  final manager =
      PopMonitoringManager(ref, ref.read(nativePopMonitoringBridgeProvider));
  ref.listen<bool>(popStudyActiveProvider, (previous, next) {
    Future.microtask(() {
      // ← ここで囲む
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
