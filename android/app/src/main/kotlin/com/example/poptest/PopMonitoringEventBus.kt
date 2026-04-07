package com.example.poptest

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel

object PopMonitoringEventBus {
    private const val logTag = "PopMonitoringEventBus"
    // Cap pending events while Flutter listener is disconnected.
    // 64 keeps memory bounded while preserving recent foreground samples.
    private const val maxPendingEvents = 64

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingEvents = ArrayDeque<Map<String, Any?>>()
    private var eventSink: EventChannel.EventSink? = null

    @Synchronized
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink == null) return
        while (pendingEvents.isNotEmpty()) {
            sink.success(pendingEvents.removeFirst())
        }
    }

    fun emit(event: Map<String, Any?>) {
        mainHandler.post {
            synchronized(this) {
                val sink = eventSink
                if (sink != null) {
                    sink.success(event)
                    return@synchronized
                }
                if (pendingEvents.size >= maxPendingEvents) {
                    // Keep memory bounded; old events can be safely dropped because
                    // Flutter enforces popup timing with persisted metrics.
                    Log.w(logTag, "Dropping stale pending monitoring event due to full queue.")
                    pendingEvents.removeFirst()
                }
                pendingEvents.addLast(event)
            }
        }
    }
}
