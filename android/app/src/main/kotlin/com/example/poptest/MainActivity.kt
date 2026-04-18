package com.example.poptest

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName,
        ).apply {
            setMethodCallHandler(::handleMethodCall)
        }

        eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName,
        ).apply {
            setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        PopMonitoringEventBus.setEventSink(events)
                    }

                    override fun onCancel(arguments: Any?) {
                        PopMonitoringEventBus.setEventSink(null)
                    }
                },
            )
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        PopMonitoringEventBus.setEventSink(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startMonitoring" -> {
                val args = call.arguments as? Map<*, *>
                val services = (args?.get("services") as? List<*>)
                    ?.mapNotNull { item -> item as? String }
                    ?: emptyList()
                val customUrls = (args?.get("customUrls") as? List<*>)
                    ?.mapNotNull { item -> item as? String }
                    ?: emptyList()
                val intervalMinutes = (args?.get("intervalMinutes") as? Number)?.toInt() ?: 30
                if (!hasRequiredPermissions(customUrls)) {
                    result.success(false)
                    return
                }
                UsageMonitorService.start(this, services, customUrls, intervalMinutes)
                result.success(true)
            }

            "stopMonitoring" -> {
                UsageMonitorService.stop(this)
                result.success(null)
            }

            "openUsageAccessSettings" -> {
                openUsageAccessSettings()
                result.success(null)
            }

            "openAccessibilitySettings" -> {
                openAccessibilitySettings()
                result.success(null)
            }

            "getMonitoringPermissionStatus" -> {
                result.success(
                    mapOf(
                        "usageAccess" to UsageMonitorService.isUsageAccessGranted(this),
                        "accessibilityEnabled" to AccessibilityMonitorService.isAccessibilityEnabled(this),
                    ),
                )
            }

            else -> result.notImplemented()
        }
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun hasRequiredPermissions(customUrls: List<String>): Boolean {
        val usageGranted = UsageMonitorService.isUsageAccessGranted(this)
        if (!usageGranted) return false
        val requiresAccessibilityPermission = customUrls.any { it.isNotBlank() }
        if (!requiresAccessibilityPermission) return true
        return AccessibilityMonitorService.isAccessibilityEnabled(this)
    }

    companion object {
        private const val methodChannelName = "poptest.pop_monitoring/methods"
        private const val eventChannelName = "poptest.pop_monitoring/events"
    }
}
