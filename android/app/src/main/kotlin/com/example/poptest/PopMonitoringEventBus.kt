package com.example.poptest

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object PopMonitoringEventBus {
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
                    pendingEvents.removeFirst()
                }
                pendingEvents.addLast(event)
            }
        }
    }
}
