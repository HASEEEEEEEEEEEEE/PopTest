import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pop_models.dart';

/// An installed app returned from the native side.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    this.iconBytes,
  });

  final String packageName;
  final String label;
  final Uint8List? iconBytes;
}

/// Riverpod provider that fetches installed apps once and caches the result.
final installedAppsProvider = FutureProvider<List<InstalledApp>>((ref) async {
  return NativePopMonitoringBridge.getInstalledApps();
});

class NativePopMonitoringConfig {
  const NativePopMonitoringConfig({
    required this.packageNames,
    required this.customUrls,
    required this.intervalMinutes,
    required this.popCount,
    required this.deckId,
  });

  final Set<String> packageNames;
  final Set<String> customUrls;
  final int intervalMinutes;
  final int popCount;
  final String deckId;

  /// Effective URLs include [customUrls] plus those derived from known packages.
  Set<String> get _effectiveUrls {
    final urls = Set<String>.of(customUrls);
    for (final pkg in packageNames) {
      urls.addAll(knownPackageUrlPatterns[pkg] ?? const {});
    }
    return urls;
  }

  Map<String, dynamic> toMap() {
    return {
      'packageNames': packageNames.toList(),
      'customUrls': _effectiveUrls.toList(),
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
    final packageName =
        raw['packageName'] is String ? raw['packageName'] as String : null;
    final url = raw['url'] is String ? raw['url'] as String : null;
    final deckId = raw['deckId'] is String ? raw['deckId'] as String : null;
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
  static const _methodChannel =
      MethodChannel('poptest.pop_monitoring/methods');
  static const _eventChannel =
      EventChannel('poptest.pop_monitoring/events');

  /// Returns the list of user-launchable installed apps with their icons.
  static Future<List<InstalledApp>> getInstalledApps() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _methodChannel
          .invokeMethod<List<dynamic>>('getInstalledApps');
      if (raw == null) return const [];
      return raw.whereType<Map>().map((m) {
        final iconRaw = m['icon'] as String?;
        Uint8List? iconBytes;
        if (iconRaw != null) {
          try {
            iconBytes = base64Decode(iconRaw);
          } catch (_) {}
        }
        return InstalledApp(
          packageName: (m['packageName'] as String?) ?? '',
          label: (m['label'] as String?) ?? '',
          iconBytes: iconBytes,
        );
      }).where((a) => a.packageName.isNotEmpty).toList();
    } on MissingPluginException catch (e) {
      debugPrint('getInstalledApps plugin missing: $e');
      return const [];
    } on PlatformException catch (e) {
      debugPrint('getInstalledApps failed: $e');
      return const [];
    }
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
    } on PlatformException catch (error) {
      debugPrint('Native pop monitoring stop failed: $error');
    }
  }

  Future<void> openUsageAccessSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('openUsageAccessSettings');
    } on MissingPluginException catch (e) {
      debugPrint('Usage access settings plugin missing: $e');
    } on PlatformException catch (e) {
      debugPrint('Failed to open usage access settings: $e');
    }
  }

  Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('openAccessibilitySettings');
    } on MissingPluginException catch (e) {
      debugPrint('Accessibility settings plugin missing: $e');
    } on PlatformException catch (e) {
      debugPrint('Failed to open accessibility settings: $e');
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
    } on MissingPluginException catch (e) {
      debugPrint('Permission status plugin missing: $e');
      return const {
        'usageAccess': false,
        'accessibilityEnabled': false,
        'overlayEnabled': false,
      };
    } on PlatformException catch (e) {
      debugPrint('Failed to get permission status: $e');
      return const {
        'usageAccess': false,
        'accessibilityEnabled': false,
        'overlayEnabled': false,
      };
    }
  }

  Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<void>('openOverlaySettings');
    } on MissingPluginException catch (e) {
      debugPrint('Overlay settings plugin missing: $e');
    } on PlatformException catch (e) {
      debugPrint('Failed to open overlay settings: $e');
    }
  }
}
