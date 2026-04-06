import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routing/router.dart';
import '../home/selected_deck_provider.dart';
import 'deck_pop_settings.dart';
import 'pop_metrics.dart';
import 'pop_models.dart';
import 'pop_study_active_provider.dart';

/// Collects lightweight user activity signals used for pop-study monitoring.
class PopActivityNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void record() => state = state + 1;
}

final popActivityProvider =
    NotifierProvider<PopActivityNotifier, int>(PopActivityNotifier.new);

/// Starts/stops user-activity-based pop monitoring and opens pop sessions.
class PopMonitoringManager {
  PopMonitoringManager(this._ref);

  final Ref _ref;
  bool _popupOpen = false;
  Timer? _debounceTimer;

  void start() {
    _ref.listen<int>(popActivityProvider, (previous, next) {
      if (previous == next) return;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 400), _tick);
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  Future<void> _tick() async {
    final active = _ref.read(popStudyActiveProvider);
    if (!active || _popupOpen) return;

    final deckId = _ref.read(selectedDeckProvider);
    if (deckId == null || deckId.isEmpty) return;

    final settings = _ref.read(effectivePopSettingsProvider(deckId));
    final hasTargets =
        settings.services.isNotEmpty || settings.customUrls.isNotEmpty;
    if (!hasTargets) return;
    final uri = _readLocationUri();
    final hasWebContext = uri.host.isNotEmpty;
    final serviceMatched = settings.services.isNotEmpty &&
        (_isServiceMatched(uri, settings.services) || !hasWebContext);
    final urlMatched = settings.customUrls.isNotEmpty &&
        _isCustomUrlMatched(uri.toString(), settings.customUrls);
    final matchedTarget = serviceMatched || urlMatched;
    final now = DateTime.now();
    await _ref
        .read(popMetricsProvider.notifier)
        .recordTrackedEvent(matchedTarget: matchedTarget, at: now);
    if (!matchedTarget) return;
    final locationPath = uri.path;
    final popPath = '/decks/$deckId/pop';
    if (locationPath == popPath) return;

    final interval = Duration(minutes: settings.intervalMinutes);
    final metrics = _ref.read(popMetricsProvider);
    if (!hasReachedNextStudyTime(metrics, interval, now)) {
      return;
    }

    await _ref.read(popMetricsProvider.notifier).recordPopupShown(now);
    _popupOpen = true;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) {
      _popupOpen = false;
      return;
    }
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ポップ学習'),
          content: Text('学習のタイミングです。${settings.popCount}問の学習を開始します。'),
          actions: [
            TextButton(
              onPressed: () {
                _ref.read(popMetricsProvider.notifier).recordPopupSnooze();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('後で'),
            ),
            FilledButton(
              onPressed: () {
                _ref
                    .read(popMetricsProvider.notifier)
                    .recordPopupStart(DateTime.now());
                Navigator.of(dialogContext).pop();
                final router = _ref.read(routerProvider);
                router.go('/decks/$deckId/pop');
              },
              child: const Text('開始'),
            ),
          ],
        );
      },
    );
    _popupOpen = false;
  }

  Uri _readLocationUri() {
    final router = _ref.read(routerProvider);
    return router.routeInformationProvider.value.uri;
  }

  bool _isServiceMatched(Uri uri, Set<PopService> services) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final full = uri.toString().toLowerCase();
    for (final service in services) {
      if (_matchesService(service, host: host, path: path, full: full)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesService(
    PopService service, {
    required String host,
    required String path,
    required String full,
  }) {
    switch (service) {
      case PopService.twitter:
        return host == 'x.com' ||
            host.endsWith('.x.com') ||
            host == 'twitter.com' ||
            host.endsWith('.twitter.com') ||
            path.contains('/tweet') ||
            path.contains('/tweets') ||
            full.contains('://x.com/') ||
            full.contains('://twitter.com/');
      case PopService.instagram:
        return host == 'instagram.com' ||
            host.endsWith('.instagram.com') ||
            full.contains('://instagram.com/');
      case PopService.youtube:
        return host == 'youtube.com' ||
            host.endsWith('.youtube.com') ||
            host == 'youtu.be' ||
            full.contains('://youtube.com/') ||
            full.contains('://youtu.be/');
      case PopService.tiktok:
        return host == 'tiktok.com' ||
            host.endsWith('.tiktok.com') ||
            full.contains('://tiktok.com/');
    }
  }

  bool _isCustomUrlMatched(String url, Set<String> patterns) {
    final lowerUrl = url.toLowerCase();
    for (final pattern in patterns) {
      if (lowerUrl.contains(pattern.toLowerCase())) return true;
    }
    return false;
  }
}

final popMonitoringProvider = Provider<PopMonitoringManager>((ref) {
  final manager = PopMonitoringManager(ref);
  ref.listen<bool>(popStudyActiveProvider, (previous, next) {
    final metrics = ref.read(popMetricsProvider.notifier);
    if (next && previous != true) {
      metrics.startSession(DateTime.now());
    } else if (!next && previous == true) {
      metrics.stopSession();
    }
  }, fireImmediately: true);
  manager.start();
  ref.onDispose(manager.dispose);
  return manager;
});
