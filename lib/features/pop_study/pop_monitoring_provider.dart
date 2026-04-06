import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routing/router.dart';
import '../home/selected_deck_provider.dart';
import 'deck_pop_settings.dart';
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

  void start() {
    _ref.listen<int>(popActivityProvider, (previous, next) {
      if (previous == next) return;
      _tick();
    });
  }

  void dispose() {}

  Future<void> _tick() async {
    final active = _ref.read(popStudyActiveProvider);
    if (!active || _popupOpen) return;

    final deckId = _ref.read(selectedDeckProvider);
    if (deckId == null || deckId.isEmpty) return;

    final settings = _ref.read(effectivePopSettingsProvider(deckId));
    if (settings.services.isEmpty) return;

    final location = _readLocation();
    if (location.contains('/pop')) return;

    final now = DateTime.now();
    final interval = Duration(minutes: settings.intervalMinutes);
    final last = _ref.read(_lastPopupAtProvider);
    if (last != null && now.difference(last) < interval) {
      return;
    }

    _ref.read(_lastPopupAtProvider.notifier).state = now;
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('後で'),
            ),
            FilledButton(
              onPressed: () {
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

  String _readLocation() {
    final router = _ref.read(routerProvider);
    return router.routeInformationProvider.value.uri.toString();
  }
}

final _lastPopupAtProvider = StateProvider<DateTime?>((ref) => null);

final popMonitoringProvider = Provider<void>((ref) {
  final manager = PopMonitoringManager(ref);
  ref.listen<bool>(popStudyActiveProvider, (previous, next) {
    if (!next) {
      ref.read(_lastPopupAtProvider.notifier).state = null;
    }
  });
  manager.start();
  ref.onDispose(manager.dispose);
});
