import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pop_models.dart';

class NativePopMonitoringConfig {
  const NativePopMonitoringConfig({
    required this.deckId,
    required this.services,
    required this.customUrls,
    required this.intervalMinutes,
    required this.popCount,
  });

  final String deckId;
  final Set<PopService> services;
  final Set<String> customUrls;
  final int intervalMinutes;
  final int popCount;

  Map<String, dynamic> toMap() {
    return {
      'deckId': deckId,
      'services': services.map((service) => service.name).toList(),
      'customUrls': customUrls.toList(),
      'intervalMinutes': intervalMinutes,
      'popCount': popCount,
    };
  }
}

enum NativePopMonitoringEventType {
  tracking,
  popupShown,
  popupSnooze,
  popupStart,
}

class NativePopMonitoringEvent {
  const NativePopMonitoringEvent({
    required this.type,
    required this.matchedTarget,
    required this.occurredAt,
    this.packageName,
    this.deckId,
  });

  final NativePopMonitoringEventType type;
  final bool matchedTarget;
  final String? packageName;
  final String? deckId;
  final DateTime occurredAt;

  static NativePopMonitoringEvent? fromRaw(dynamic raw) {
    if (raw is! Map) return null;
    final type = switch (raw['eventType']) {
      'popupShown' => NativePopMonitoringEventType.popupShown,
      'popupSnooze' => NativePopMonitoringEventType.popupSnooze,
      'popupStart' => NativePopMonitoringEventType.popupStart,
      _ => NativePopMonitoringEventType.tracking,
    };
    final matchedTarget = raw['matchedTarget'] == true;
    final packageNameRaw = raw['packageName'];
    final packageName = packageNameRaw is String ? packageNameRaw : null;
    final deckIdRaw = raw['deckId'];
    final deckId = deckIdRaw is String ? deckIdRaw : null;
    final timestampRaw = raw['timestampMs'];
    if (timestampRaw is! int) return null;
    return NativePopMonitoringEvent(
      type: type,
      matchedTarget: matchedTarget,
      packageName: packageName,
      deckId: deckId,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(timestampRaw),
    );
  }
}

class NativePopMonitoringBridge {
  static const _methodChannel = MethodChannel('poptest.pop_monitoring/methods');
  static const _eventChannel = EventChannel('poptest.pop_monitoring/events');

  final _startPopStudyController = StreamController<String>.broadcast();

  NativePopMonitoringBridge() {
    _ensureMethodHandler();
  }

  Stream<String> startPopStudyStream() => _startPopStudyController.stream;

  void _ensureMethodHandler() {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method != 'startPopStudy') return;
      final raw = call.arguments;
      if (raw is! Map) return;
      final deckId = raw['deckId'];
      if (deckId is! String || deckId.isEmpty) return;
      _startPopStudyController.add(deckId);
    });
  }

  Stream<NativePopMonitoringEvent> eventStream() async* {
    if (!Platform.isAndroid) return;
    try {
      await for (final raw in _eventChannel.receiveBroadcastStream()) {
        final event = NativePopMonitoringEvent.fromRaw(raw);
        if (event == null) continue;
        yield event;
      }
    } on MissingPluginException catch (error) {
      debugPrint('Native pop monitoring plugin missing: $error');
      return;
    } on PlatformException catch (error) {
      debugPrint('Native pop monitoring event stream failed: $error');
      return;
    }
  }

  Future<bool> startMonitoring(NativePopMonitoringConfig config) async {
    if (!Platform.isAndroid) return false;
    try {
      final started = await _methodChannel.invokeMethod<bool>(
        'startMonitoring',
        config.toMap(),
      );
      return started ?? false;
    } on MissingPluginException catch (error) {
      debugPrint('Native pop monitoring start plugin missing: $error');
      return false;
    } on PlatformException catch (error) {
      debugPrint('Native pop monitoring start failed: $error');
      return false;
    }
  }

  Future<void> stopMonitoring() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('stopMonitoring');
    } on MissingPluginException catch (error) {
      debugPrint('Native pop monitoring stop plugin missing: $error');
      return;
    } on PlatformException catch (error) {
      debugPrint('Native pop monitoring stop failed: $error');
      return;
    }
  }

  Future<void> openUsageAccessSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('openUsageAccessSettings');
    } on MissingPluginException catch (error) {
      debugPrint('Usage access settings plugin missing: $error');
      return;
    } on PlatformException catch (error) {
      debugPrint('Failed to open usage access settings: $error');
      return;
    }
  }

  Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('openAccessibilitySettings');
    } on MissingPluginException catch (error) {
      debugPrint('Accessibility settings plugin missing: $error');
      return;
    } on PlatformException catch (error) {
      debugPrint('Failed to open accessibility settings: $error');
      return;
    }
  }

  Future<bool> checkOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final enabled =
          await _methodChannel.invokeMethod<bool>('checkOverlayPermission');
      return enabled ?? false;
    } on MissingPluginException catch (error) {
      debugPrint('Overlay permission plugin missing: $error');
      return false;
    } on PlatformException catch (error) {
      debugPrint('Failed to check overlay permission: $error');
      return false;
    }
  }

  Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('openOverlaySettings');
    } on MissingPluginException catch (error) {
      debugPrint('Overlay settings plugin missing: $error');
      return;
    } on PlatformException catch (error) {
      debugPrint('Failed to open overlay settings: $error');
      return;
    }
  }

  Future<String?> consumePendingStartDeckId() async {
    if (!Platform.isAndroid) return null;
    try {
      final deckId =
          await _methodChannel.invokeMethod<String>('consumePendingStartDeckId');
      return (deckId == null || deckId.isEmpty) ? null : deckId;
    } on MissingPluginException catch (error) {
      debugPrint('Pending start deck plugin missing: $error');
      return null;
    } on PlatformException catch (error) {
      debugPrint('Failed to consume pending start deck: $error');
      return null;
    }
  }

  Future<Map<String, bool>> getPermissionStatus() async {
    if (!Platform.isAndroid) {
      return const {
        'usageAccess': false,
        'accessibilityEnabled': false,
        'overlayEnabled': false,
      };
    }
    try {
      final raw = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getMonitoringPermissionStatus',
      );
      if (raw == null) {
        return const {
          'usageAccess': false,
          'accessibilityEnabled': false,
          'overlayEnabled': false,
        };
      }
      return {
        'usageAccess': raw['usageAccess'] == true,
        'accessibilityEnabled': raw['accessibilityEnabled'] == true,
        'overlayEnabled': raw['overlayEnabled'] == true,
      };
    } on MissingPluginException catch (error) {
      debugPrint('Permission status plugin missing: $error');
      return const {
        'usageAccess': false,
        'accessibilityEnabled': false,
        'overlayEnabled': false,
      };
    } on PlatformException catch (error) {
      debugPrint('Failed to get permission status: $error');
      return const {
        'usageAccess': false,
        'accessibilityEnabled': false,
        'overlayEnabled': false,
      };
    }
  }

  void dispose() {
    _startPopStudyController.close();
  }
}
