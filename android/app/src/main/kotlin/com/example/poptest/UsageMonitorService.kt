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
            "youtube"   -> setOf("youtube.com", "youtu.be")
            "twitter"   -> setOf("twitter.com", "x.com")
            "instagram" -> setOf("instagram.com")
            "tiktok"    -> setOf("tiktok.com")
            else        -> emptySet()
        }
    }
    

    private fun emitForegroundMatchEvent() {
        val packageName = readForegroundPackageName()
        val packageMatched = packageName != null && targetPackages.contains(packageName)
        val urlMatched = BrowserUrlMonitorState.isMatchedForForegroundPackage(packageName)
        val matchedTarget = packageMatched || urlMatched
        val currentUrl = BrowserUrlMonitorState.latestUrlForForegroundPackage(packageName)
        PopMonitoringEventBus.emit(
            mapOf(
                "matchedTarget" to matchedTarget,
                "packageName" to packageName,
                "urlMatched" to urlMatched,
                "url" to currentUrl,
                "timestampMs" to System.currentTimeMillis(),
            ),
        )
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

        private const val notificationId = 4001
        private const val notificationChannelId = "poptest_monitoring"

        private const val minCheckIntervalMs = 15_000L
        private const val defaultCheckIntervalMs = 60_000L
        private const val maxCheckIntervalMs = 120_000L
        private const val defaultIntervalMinutes = 30
        private const val usageWindowMs = 15_000L

        fun start(
            context: Context,
            services: List<String>,
            customUrls: List<String>,
            intervalMinutes: Int,
        ) {
            val intent = Intent(context, UsageMonitorService::class.java)
                .setAction(actionStart)
                .putStringArrayListExtra(extraServices, ArrayList(services))
                .putStringArrayListExtra(extraCustomUrls, ArrayList(customUrls))
                .putExtra(extraIntervalMinutes, intervalMinutes)
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
