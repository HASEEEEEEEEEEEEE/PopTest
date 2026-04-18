package com.example.poptest

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class UsageMonitorService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val checker = object : Runnable {
        override fun run() {
            emitForegroundMatchEvent()
            mainHandler.postDelayed(this, currentCheckIntervalMs)
        }
    }

    private var targetPackages: Set<String> = emptySet()
    private var currentCheckIntervalMs: Long = defaultCheckIntervalMs
    private var popCount: Int = defaultPopCount
    private var targetDeckId: String? = null
    private var popupIntervalSeconds: Int = defaultIntervalMinutes * 60
    private var viewingSecondsForCurrentInterval: Int = 0
    private var lastTrackingAtMs: Long? = null
    private var overlayView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            actionStart -> {
                updateTargets(intent)
                startForeground(notificationId, buildNotification())
                startChecking()
            }

            actionStop -> {
                stopChecking()
                stopForegroundCompat()
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopChecking()
        dismissOverlay()
        BrowserUrlMonitorState.clear()
        super.onDestroy()
    }

    private fun startChecking() {
        mainHandler.removeCallbacks(checker)
        mainHandler.post(checker)
    }

    private fun stopChecking() {
        mainHandler.removeCallbacks(checker)
    }

    private fun updateTargets(intent: Intent) {
        val services =
            intent.getStringArrayListExtra(extraServices)?.toSet() ?: emptySet()
        val customUrls =
            intent.getStringArrayListExtra(extraCustomUrls)?.toSet() ?: emptySet()
        val intervalMinutes = intent.getIntExtra(extraIntervalMinutes, defaultIntervalMinutes)
        popCount = intent.getIntExtra(extraPopCount, defaultPopCount).coerceIn(1, maxPopCount)
        targetDeckId = intent.getStringExtra(extraDeckId)?.trim()?.takeIf { it.isNotEmpty() }
        popupIntervalSeconds = intervalMinutes.coerceAtLeast(1) * 60
        viewingSecondsForCurrentInterval = 0
        lastTrackingAtMs = null
        dismissOverlay()
        currentCheckIntervalMs = resolveCheckIntervalMs(intervalMinutes)
        targetPackages = services
            .flatMap { service -> packagesForService(service) }
            .toSet()
        // サービスに対応するブラウザURLパターンを自動追加
        val serviceUrls = services.flatMap { urlPatternsForService(it) }.toSet()
        BrowserUrlMonitorState.updateTargets(customUrls + serviceUrls)
    }

    // 追加するメソッド（packagesForService の隣に置く）
    private fun urlPatternsForService(service: String): Set<String> {
        return when (service) {
            "youtube"   -> setOf("youtube.com", "youtu.be", "m.youtube.com")
            "twitter"   -> setOf("twitter.com", "x.com")
            "instagram" -> setOf("instagram.com")
            "tiktok"    -> setOf("tiktok.com")
            else        -> emptySet()
        }
    }
    

    private fun emitForegroundMatchEvent() {
        val nowMs = System.currentTimeMillis()
        val packageName = readForegroundPackageName()
        val packageMatched = packageName != null && targetPackages.contains(packageName)
        val urlMatched = BrowserUrlMonitorState.isMatchedForForegroundPackage(packageName)
        val matchedTarget = packageMatched || urlMatched
        val currentUrl = BrowserUrlMonitorState.latestUrlForForegroundPackage(packageName)
        updateViewingSeconds(matchedTarget, nowMs)
        maybeShowOverlay(nowMs)
        PopMonitoringEventBus.emit(
            mapOf(
                "eventType" to eventTypeTracking,
                "matchedTarget" to matchedTarget,
                "packageName" to packageName,
                "urlMatched" to urlMatched,
                "url" to currentUrl,
                "timestampMs" to nowMs,
            ),
        )
    }

    private fun updateViewingSeconds(matchedTarget: Boolean, nowMs: Long) {
        val previous = lastTrackingAtMs
        lastTrackingAtMs = nowMs
        if (!matchedTarget || previous == null) return
        val rawElapsedSeconds = ((nowMs - previous).coerceAtLeast(0L) / 1000L).toInt()
        val maxAllowedElapsedSeconds =
            ((currentCheckIntervalMs * maxElapsedMultiplier) / 1000L).toInt().coerceAtLeast(1)
        val elapsedSeconds = rawElapsedSeconds.coerceAtMost(maxAllowedElapsedSeconds)
        if (elapsedSeconds <= 0) return
        viewingSecondsForCurrentInterval += elapsedSeconds
    }

    private fun maybeShowOverlay(nowMs: Long) {
        if (overlayView != null) return
        if (targetDeckId.isNullOrBlank()) return
        if (viewingSecondsForCurrentInterval < popupIntervalSeconds) return
        if (!Settings.canDrawOverlays(this)) return
        viewingSecondsForCurrentInterval = 0
        showOverlay(targetDeckId!!, popCount)
        PopMonitoringEventBus.emit(
            mapOf(
                "eventType" to eventTypePopupShown,
                "matchedTarget" to true,
                "timestampMs" to nowMs,
                "deckId" to targetDeckId,
            ),
        )
    }

    private fun showOverlay(deckId: String, popCount: Int) {
        if (overlayView != null) return
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 40, 48, 32)
            setBackgroundColor(Color.argb(242, 33, 33, 33))
            elevation = 18f
        }
        val title = TextView(this).apply {
            text = "ポップ学習"
            setTextColor(Color.WHITE)
            textSize = 19f
            setPadding(0, 0, 0, 12)
        }
        val message = TextView(this).apply {
            text = "学習のタイミングです。$popCount問の学習を開始します。"
            setTextColor(Color.WHITE)
            textSize = 15f
            setPadding(0, 0, 0, 20)
        }
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }
        val snoozeButton = Button(this).apply {
            text = "後で"
            setOnClickListener {
                dismissOverlay()
                PopMonitoringEventBus.emit(
                    mapOf(
                        "eventType" to eventTypePopupSnooze,
                        "matchedTarget" to false,
                        "timestampMs" to System.currentTimeMillis(),
                    ),
                )
            }
        }
        val startButton = Button(this).apply {
            text = "開始"
            setOnClickListener {
                dismissOverlay()
                PopMonitoringEventBus.emit(
                    mapOf(
                        "eventType" to eventTypePopupStart,
                        "matchedTarget" to false,
                        "timestampMs" to System.currentTimeMillis(),
                        "deckId" to deckId,
                    ),
                )
                val launchIntent = Intent(this@UsageMonitorService, MainActivity::class.java).apply {
                    action = actionStartPopStudy
                    putExtra(extraDeckId, deckId)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                startActivity(launchIntent)
            }
        }
        actions.addView(snoozeButton)
        actions.addView(startButton)
        container.addView(title)
        container.addView(message)
        container.addView(actions)
        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = 120
        }
        windowManager.addView(container, layoutParams)
        overlayView = container
    }

    private fun dismissOverlay() {
        val view = overlayView ?: return
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        runCatching { windowManager?.removeView(view) }
        overlayView = null
    }

    private fun readForegroundPackageName(): String? {
        if (!isUsageAccessGranted(this)) return null
        val usageStats = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return null
        val end = System.currentTimeMillis()
        val begin = end - usageWindowMs
        val events = usageStats.queryEvents(begin, end)
        val event = UsageEvents.Event()
        var latestPackage: String? = null
        var latestTimestamp = 0L
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (!isForegroundEvent(event)) continue
            if (event.timeStamp < latestTimestamp) continue
            latestTimestamp = event.timeStamp
            latestPackage = event.packageName
        }
        return latestPackage
    }

    private fun isForegroundEvent(event: UsageEvents.Event): Boolean {
        return when (event.eventType) {
            UsageEvents.Event.MOVE_TO_FOREGROUND -> true
            UsageEvents.Event.ACTIVITY_RESUMED -> Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
            else -> false
        }
    }

    private fun buildNotification(): Notification {
        createNotificationChannelIfNeeded()
        return NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("PopTest")
            .setContentText("SNS監視中")
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        val channel = NotificationChannel(
            notificationChannelId,
            "PopTest Monitoring",
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    companion object {
        private const val actionStart = "com.example.poptest.action.START_MONITORING"
        private const val actionStop = "com.example.poptest.action.STOP_MONITORING"
        private const val extraServices = "services"
        private const val extraCustomUrls = "customUrls"
        private const val extraIntervalMinutes = "intervalMinutes"
        private const val extraPopCount = "popCount"
        const val extraDeckId = "deckId"

        const val actionStartPopStudy = "com.example.poptest.action.START_POP_STUDY"

        private const val notificationId = 4001
        private const val notificationChannelId = "poptest_monitoring"

        private const val minCheckIntervalMs = 5_000L
        private const val defaultCheckIntervalMs = 10_000L
        private const val maxCheckIntervalMs = 30_000L
        private const val defaultIntervalMinutes = 30
        private const val defaultPopCount = 1
        private const val maxPopCount = 50
        private const val usageWindowMs = 15_000L
        private const val maxElapsedMultiplier = 2L

        private const val eventTypeTracking = "tracking"
        private const val eventTypePopupShown = "popupShown"
        private const val eventTypePopupSnooze = "popupSnooze"
        private const val eventTypePopupStart = "popupStart"

        fun start(
            context: Context,
            services: List<String>,
            customUrls: List<String>,
            intervalMinutes: Int,
            popCount: Int,
            deckId: String,
        ) {
            val intent = Intent(context, UsageMonitorService::class.java)
                .setAction(actionStart)
                .putStringArrayListExtra(extraServices, ArrayList(services))
                .putStringArrayListExtra(extraCustomUrls, ArrayList(customUrls))
                .putExtra(extraIntervalMinutes, intervalMinutes)
                .putExtra(extraPopCount, popCount)
                .putExtra(extraDeckId, deckId)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            BrowserUrlMonitorState.clear()
            val intent = Intent(context, UsageMonitorService::class.java).setAction(actionStop)
            context.startService(intent)
        }

        fun isUsageAccessGranted(context: Context): Boolean {
            val usageStats = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
                ?: return false
            val end = System.currentTimeMillis()
            val begin = end - usageWindowMs
            val stats = usageStats.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                begin,
                end,
            )
            return !stats.isNullOrEmpty()
        }

        private fun packagesForService(service: String): Set<String> {
            return when (service) {
                "twitter" -> setOf("com.twitter.android")
                "instagram" -> setOf("com.instagram.android")
                "youtube" -> setOf(
                    "com.google.android.youtube",
                    "app.rvx.android.youtube",
                )

                "tiktok" -> setOf("com.zhiliaoapp.musically", "com.ss.android.ugc.trill")
                else -> emptySet()
            }
        }

        private fun resolveCheckIntervalMs(intervalMinutes: Int): Long {
            val derived = intervalMinutes.coerceAtLeast(1).toLong() * 60_000L
            return derived.coerceIn(minCheckIntervalMs, maxCheckIntervalMs)
        }
    }
}
