package com.example.poptest

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class UsageMonitorService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var scheduler: ScheduledExecutorService? = null
    private var scheduledFuture: ScheduledFuture<*>? = null

    private var targetPackages: Set<String> = emptySet()
    private var popCount: Int = defaultPopCount
    private var targetDeckId: String? = null
    private var popupIntervalMs: Long = defaultIntervalMinutes * 60_000L
    private var viewingMsForCurrentInterval: Long = 0L
    // elapsedRealtime ベース: 時刻変更・NTP同期の影響を受けない単調増加クロック
    private var lastTrackingElapsedMs: Long? = null
    private var lastKnownPackageName: String? = null

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
        BrowserUrlMonitorState.clear()
        super.onDestroy()
    }

    private fun startChecking() {
        stopChecking()
        scheduler = Executors.newSingleThreadScheduledExecutor()
        scheduledFuture = scheduler?.scheduleAtFixedRate(
            { mainHandler.post { emitForegroundMatchEvent() } },
            0L,
            checkIntervalMs,
            TimeUnit.MILLISECONDS,
        )
    }

    private fun stopChecking() {
        scheduledFuture?.cancel(false)
        scheduledFuture = null
        scheduler?.shutdown()
        scheduler = null
    }

    private fun updateTargets(intent: Intent) {
        val packageNames =
            intent.getStringArrayListExtra(extraPackageNames)?.toSet() ?: emptySet()
        val customUrls =
            intent.getStringArrayListExtra(extraCustomUrls)?.toSet() ?: emptySet()
        val intervalMinutes = intent.getIntExtra(extraIntervalMinutes, defaultIntervalMinutes)
        popCount = intent.getIntExtra(extraPopCount, defaultPopCount).coerceIn(1, maxPopCount)
        targetDeckId = intent.getStringExtra(extraDeckId)?.trim()?.takeIf { it.isNotEmpty() }
        popupIntervalMs = intervalMinutes.coerceAtLeast(1) * 60_000L
        lastKnownPackageName = null
        viewingMsForCurrentInterval = 0L
        lastTrackingElapsedMs = null
        targetPackages = packageNames
        BrowserUrlMonitorState.updateTargets(customUrls)
    }

    private fun emitForegroundMatchEvent() {
        val nowMs = System.currentTimeMillis()           // 壁時計: イベントタイムスタンプ用
        val nowElapsed = SystemClock.elapsedRealtime()   // 単調増加: 経過時間計算用
        val detectedPackage = readForegroundPackageName()

        if (detectedPackage != null) {
            lastKnownPackageName = detectedPackage
        }
        val packageName = lastKnownPackageName

        if (packageName == applicationContext.packageName) {
            lastTrackingElapsedMs = nowElapsed
            return
        }

        val packageMatched = packageName != null && targetPackages.contains(packageName)
        val urlMatched = BrowserUrlMonitorState.isMatchedForForegroundPackage(packageName)
        val matchedTarget = packageMatched || urlMatched
        val currentUrl = BrowserUrlMonitorState.latestUrlForForegroundPackage(packageName)

        android.util.Log.d(
            "PopMonitor",
            "tracking | matched=$matchedTarget | pkg=$packageName | url=${currentUrl ?: "-"}",
        )

        updateViewingSeconds(matchedTarget, nowElapsed)
        maybeStartPopStudy(nowMs)
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

    private fun updateViewingSeconds(matchedTarget: Boolean, nowElapsed: Long) {
        val previous = lastTrackingElapsedMs
        lastTrackingElapsedMs = nowElapsed
        if (!matchedTarget || previous == null) return
        val rawElapsedMs = (nowElapsed - previous).coerceAtLeast(0L)
        val maxAllowedMs = (checkIntervalMs * maxElapsedMultiplier).coerceAtLeast(1L)
        val elapsedMs = rawElapsedMs.coerceAtMost(maxAllowedMs)
        if (elapsedMs <= 0L) return
        viewingMsForCurrentInterval += elapsedMs
    }

    private fun maybeStartPopStudy(nowMs: Long) {
        val deckId = targetDeckId ?: return
        if (deckId.isBlank()) return
        if (viewingMsForCurrentInterval < popupIntervalMs) return
        viewingMsForCurrentInterval = 0L
        PopMonitoringEventBus.emit(
            mapOf(
                "eventType" to eventTypePopupShown,
                "matchedTarget" to true,
                "timestampMs" to nowMs,
                "deckId" to deckId,
            ),
        )
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            action = actionStartPopStudy
            putExtra(extraDeckId, deckId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(launchIntent)
    }

    private fun readForegroundPackageName(): String? {
        if (!isUsageAccessGranted(this)) return null
        val usageStats = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return null
        val end = System.currentTimeMillis()
        val begin = end - 24 * 60 * 60 * 1000L
        val events = usageStats.queryEvents(begin, end)
        val event = UsageEvents.Event()

        data class PkgState(var resumedAt: Long, var pausedAt: Long)
        val states = mutableMapOf<String, PkgState>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val type = event.eventType
            if (type != UsageEvents.Event.ACTIVITY_RESUMED &&
                type != UsageEvents.Event.ACTIVITY_PAUSED) continue
            val pkg = event.packageName ?: continue
            val s = states.getOrPut(pkg) { PkgState(0L, 0L) }
            if (type == UsageEvents.Event.ACTIVITY_RESUMED) {
                if (event.timeStamp > s.resumedAt) s.resumedAt = event.timeStamp
            } else {
                if (event.timeStamp > s.pausedAt) s.pausedAt = event.timeStamp
            }
        }

        return states.entries
            .filter { it.value.resumedAt > it.value.pausedAt }
            .maxByOrNull { it.value.resumedAt }
            ?.key
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
        val manager =
            getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
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
        private const val extraPackageNames = "packageNames"
        private const val extraCustomUrls = "customUrls"
        private const val extraIntervalMinutes = "intervalMinutes"
        private const val extraPopCount = "popCount"
        const val extraDeckId = "deckId"
        const val actionStartPopStudy = "com.example.poptest.action.START_POP_STUDY"

        private const val notificationId = 4001
        private const val notificationChannelId = "poptest_monitoring"

        private const val checkIntervalMs = 1_000L
        private const val defaultIntervalMinutes = 30
        private const val defaultPopCount = 1
        private const val maxPopCount = 50
        private const val maxElapsedMultiplier = 2L

        private const val eventTypeTracking = "tracking"
        private const val eventTypePopupShown = "popupShown"

        fun start(
            context: Context,
            packageNames: List<String>,
            customUrls: List<String>,
            intervalMinutes: Int,
            popCount: Int,
            deckId: String,
        ) {
            val intent = Intent(context, UsageMonitorService::class.java)
                .setAction(actionStart)
                .putStringArrayListExtra(extraPackageNames, ArrayList(packageNames))
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
            try {
                val appOps = context.getSystemService(Context.APP_OPS_SERVICE)
                    as? android.app.AppOpsManager
                if (appOps != null) {
                    val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                        appOps.unsafeCheckOpNoThrow(
                            android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                            android.os.Process.myUid(),
                            context.packageName,
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        appOps.checkOpNoThrow(
                            android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                            android.os.Process.myUid(),
                            context.packageName,
                        )
                    }
                    if (mode == android.app.AppOpsManager.MODE_ALLOWED) return true
                }
            } catch (_: Exception) {}
            return try {
                val usageStats = context.getSystemService(Context.USAGE_STATS_SERVICE)
                    as? UsageStatsManager ?: return false
                val end = System.currentTimeMillis()
                val stats = usageStats.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY,
                    end - 7 * 24 * 60 * 60 * 1000L,
                    end,
                )
                !stats.isNullOrEmpty()
            } catch (_: Exception) { false }
        }
    }
}
