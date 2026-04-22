package com.example.poptest

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.provider.Settings
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private val pendingStartDeckLock = Any()
    private var pendingStartDeckId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consumeStartPopStudyIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeStartPopStudyIntent(intent)
    }

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
                val packageNames = (args?.get("packageNames") as? List<*>)
                    ?.mapNotNull { it as? String }
                    ?: emptyList()
                val customUrls = (args?.get("customUrls") as? List<*>)
                    ?.mapNotNull { it as? String }
                    ?: emptyList()
                val intervalMinutes = (args?.get("intervalMinutes") as? Number)?.toInt() ?: 30
                val popCount = (args?.get("popCount") as? Number)?.toInt() ?: 1
                val deckId = (args?.get("deckId") as? String)?.trim().orEmpty()
                if (!hasRequiredPermissions()) {
                    result.success(false)
                    return
                }
                UsageMonitorService.start(
                    this, packageNames, customUrls, intervalMinutes, popCount, deckId,
                )
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

            "checkOverlayPermission" -> {
                result.success(Settings.canDrawOverlays(this))
            }

            "openOverlaySettings" -> {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    android.net.Uri.parse("package:$packageName"),
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.success(null)
            }

            "consumePendingStartDeckId" -> {
                result.success(consumePendingStartDeckId())
            }

            "getMonitoringPermissionStatus" -> {
                result.success(
                    mapOf(
                        "usageAccess" to UsageMonitorService.isUsageAccessGranted(this),
                        "accessibilityEnabled" to AccessibilityMonitorService.isAccessibilityEnabled(this),
                        "overlayEnabled" to Settings.canDrawOverlays(this),
                    ),
                )
            }

            "moveTaskToBack" -> {
                moveTaskToBack(true)
                result.success(null)
            }

            "getInstalledApps" -> {
                try {
                    val pm = packageManager
                    val appList = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                    val resultList = appList.mapNotNull { appInfo ->
                        // Only include apps that have a launcher entry (user-visible apps).
                        val hasLauncher =
                            pm.getLaunchIntentForPackage(appInfo.packageName) != null
                        if (!hasLauncher) return@mapNotNull null
                        val label = pm.getApplicationLabel(appInfo).toString()
                        val iconBase64 = try {
                            val drawable = pm.getApplicationIcon(appInfo.packageName)
                            val bmp = drawableToBitmap(drawable)
                            val baos = ByteArrayOutputStream()
                            bmp.compress(Bitmap.CompressFormat.PNG, 85, baos)
                            bmp.recycle()
                            Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
                        } catch (_: Exception) {
                            null
                        }
                        mapOf(
                            "packageName" to appInfo.packageName,
                            "label" to label,
                            "icon" to iconBase64,
                        )
                    }.sortedBy { it["label"] as String }
                    result.success(resultList)
                } catch (e: Exception) {
                    result.error("GET_APPS_ERROR", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            canvas.drawBitmap(drawable.bitmap, null,
                android.graphics.Rect(0, 0, size, size), null)
        } else {
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
        }
        return bitmap
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

    private fun hasRequiredPermissions(): Boolean {
        if (!UsageMonitorService.isUsageAccessGranted(this)) return false
        if (!AccessibilityMonitorService.isAccessibilityEnabled(this)) return false
        return Settings.canDrawOverlays(this)
    }

    private fun consumeStartPopStudyIntent(intent: Intent?) {
        if (intent?.action != UsageMonitorService.actionStartPopStudy) return
        val deckId = intent.getStringExtra(UsageMonitorService.extraDeckId)?.trim().orEmpty()
        if (deckId.isEmpty()) return
        synchronized(pendingStartDeckLock) {
            pendingStartDeckId = deckId
        }
        methodChannel?.invokeMethod(
            "startPopStudy",
            mapOf("deckId" to deckId),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    synchronized(pendingStartDeckLock) {
                        if (pendingStartDeckId == deckId) pendingStartDeckId = null
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit
                override fun notImplemented() = Unit
            },
        )
    }

    private fun consumePendingStartDeckId(): String? {
        synchronized(pendingStartDeckLock) {
            val deckId = pendingStartDeckId
            pendingStartDeckId = null
            return deckId
        }
    }

    companion object {
        private const val methodChannelName = "poptest.pop_monitoring/methods"
        private const val eventChannelName = "poptest.pop_monitoring/events"
    }
}
