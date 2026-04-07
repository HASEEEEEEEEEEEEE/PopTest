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
            mainHandler.postDelayed(this, checkIntervalMs)
        }
    }

    private var targetPackages: Set<String> = emptySet()

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
        targetPackages = services
            .flatMap { service -> packagesForService(service) }
            .toSet()
    }

    private fun emitForegroundMatchEvent() {
        val packageName = readForegroundPackageName()
        val matchedTarget = packageName != null && targetPackages.contains(packageName)
        PopMonitoringEventBus.emit(
            mapOf(
                "matchedTarget" to matchedTarget,
                "packageName" to packageName,
                "timestampMs" to System.currentTimeMillis(),
            ),
        )
    }

    private fun readForegroundPackageName(): String? {
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

        private const val notificationId = 4001
        private const val notificationChannelId = "poptest_monitoring"

        private const val checkIntervalMs = 5_000L
        private const val usageWindowMs = 15_000L

        fun start(context: Context, services: List<String>) {
            val intent = Intent(context, UsageMonitorService::class.java)
                .setAction(actionStart)
                .putStringArrayListExtra(extraServices, ArrayList(services))
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
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
                    "com.vanced.android.youtube",
                    "app.rvx.android.youtube",
                )

                "tiktok" -> setOf("com.zhiliaoapp.musically", "com.ss.android.ugc.trill")
                else -> emptySet()
            }
        }
    }
}
