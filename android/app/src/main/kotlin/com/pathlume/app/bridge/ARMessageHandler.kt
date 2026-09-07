package com.pathlume.app.bridge

import android.os.Handler
import android.os.Looper
import com.pathlume.app.ar.ARCoreManager
import io.flutter.plugin.common.EventChannel

class ARMessageHandler(private val arCoreManager: ARCoreManager) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isStreaming = false

    private val updateRunnable = object : Runnable {
        override fun run() {
            if (isStreaming) {
                val poseData = arCoreManager.getCurrentPose()
                if (poseData != null) {
                    val eventMap = mapOf(
                        "trackingState" to poseData.trackingState,
                        "pose" to poseData.toMap()
                    )
                    eventSink?.success(eventMap)
                }
                mainHandler.postDelayed(this, 100) // 10Hz Flutter UI status update stream
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        this.isStreaming = true
        mainHandler.post(updateRunnable)
    }

    override fun onCancel(arguments: Any?) {
        this.isStreaming = false
        this.eventSink = null
        mainHandler.removeCallbacks(updateRunnable)
    }
}
