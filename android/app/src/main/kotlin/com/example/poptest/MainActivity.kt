package com.example.poptest

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName,
        ).setMethodCallHandler(::handleMethodCall)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName,
        ).setStreamHandler(
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

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startMonitoring" -> {
                val args = call.arguments as? Map<*, *>
                val services = (args?.get("services") as? List<*>)
                    ?.mapNotNull { item -> item as? String }
                    ?: emptyList()
                if (!UsageMonitorService.isUsageAccessGranted(this)) {
                    result.success(false)
                    return
                }
                UsageMonitorService.start(this, services)
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

            else -> result.notImplemented()
        }
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    companion object {
        private const val methodChannelName = "poptest.pop_monitoring/methods"
        private const val eventChannelName = "poptest.pop_monitoring/events"
    }
}
