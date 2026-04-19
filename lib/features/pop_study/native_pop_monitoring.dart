import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pop_models.dart';

class NativePopMonitoringConfig {
  const NativePopMonitoringConfig({
    required this.services,
    required this.customUrls,
    required this.intervalMinutes,
    required this.popCount,
    required this.deckId,
  });

  final Set<PopService> services;
  final Set<String> customUrls;
  final int intervalMinutes;
  final int popCount;
  final String deckId;

  Map<String, dynamic> toMap() {
    return {
      'services': services.map((service) => service.name).toList(),
      'customUrls': customUrls.toList(),
      'intervalMinutes': intervalMinutes,
      'popCount': popCount,
      'deckId': deckId,
    };
  }
}

enum NativeEventType { tracking, popupShown, popupSnooze, popupStart, unknown }

class NativePopMonitoringEvent {
  const NativePopMonitoringEvent({
    required this.eventType,
    required this.matchedTarget,
    required this.occurredAt,
    this.packageName,
    this.url,
    this.deckId,
  });

  final NativeEventType eventType;
  final bool matchedTarget;
  final String? packageName;
  final String? url;
  final String? deckId;
  final DateTime occurredAt;

  static NativePopMonitoringEvent? fromRaw(dynamic raw) {
    if (raw is! Map) return null;
    final matchedTarget = raw['matchedTarget'] == true;
    final packageNameRaw = raw['packageName'];
    final packageName = packageNameRaw is String ? packageNameRaw : null;
    final urlRaw = raw['url'];
    final url = urlRaw is String ? urlRaw : null;
    final deckIdRaw = raw['deckId'];
    final deckId = deckIdRaw is String ? deckIdRaw : null;
    final timestampRaw = raw['timestampMs'];
    if (timestampRaw is! int) return null;
    final eventTypeRaw = raw['eventType'] as String? ?? 'tracking';
    final eventType = switch (eventTypeRaw) {
      'tracking' => NativeEventType.tracking,
      'popupShown' => NativeEventType.popupShown,
      'popupSnooze' => NativeEventType.popupSnooze,
      'popupStart' => NativeEventType.popupStart,
      _ => NativeEventType.unknown,
    };
    return NativePopMonitoringEvent(
      eventType: eventType,
      matchedTarget: matchedTarget,
      packageName: packageName,
      url: url,
      deckId: deckId,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(timestampRaw),
    );
  }
}

class NativePopMonitoringBridge {
  static const _methodChannel = MethodChannel('poptest.pop_monitoring/methods');
  static const _eventChannel = EventChannel('poptest.pop_monitoring/events');

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

  Future<Map<String, bool>> getPermissionStatus() async {
    if (!Platform.isAndroid) {
      return const {'usageAccess': false, 'accessibilityEnabled': false};
    }
    try {
      final raw = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getMonitoringPermissionStatus',
      );
      if (raw == null) {
        return const {'usageAccess': false, 'accessibilityEnabled': false};
      }
      return {
        'usageAccess': raw['usageAccess'] == true,
        'accessibilityEnabled': raw['accessibilityEnabled'] == true,
      };
    } on MissingPluginException catch (error) {
      debugPrint('Permission status plugin missing: $error');
      return const {'usageAccess': false, 'accessibilityEnabled': false};
    } on PlatformException catch (error) {
      debugPrint('Failed to get permission status: $error');
      return const {'usageAccess': false, 'accessibilityEnabled': false};
    }
  }
}
