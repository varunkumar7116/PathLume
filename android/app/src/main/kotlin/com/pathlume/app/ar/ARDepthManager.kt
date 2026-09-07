package com.pathlume.app.ar

import android.util.Log
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Session

class ARDepthManager {
    companion object {
        private const val TAG = "PATHLUME_AR"
    }

    var isDepthSupported: Boolean = false
        private set
    var isDepthAvailable: Boolean = false
        private set

    fun configureDepthMode(session: Session, config: Config): Boolean {
        return try {
            val supported = session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
            isDepthSupported = supported

            if (supported) {
                config.depthMode = Config.DepthMode.AUTOMATIC
                Log.i(TAG, "PATHLUME_AR DEPTH_MODE_AUTOMATIC_ENABLED")
            } else {
                config.depthMode = Config.DepthMode.DISABLED
                Log.i(TAG, "PATHLUME_AR DEPTH_MODE_UNSUPPORTED_DISABLED")
            }
            true
        } catch (t: Throwable) {
            Log.e(TAG, "PATHLUME_AR DEPTH_CONFIG_FAILED", t)
            isDepthSupported = false
            config.depthMode = Config.DepthMode.DISABLED
            false
        }
    }

    fun processFrame(frame: Frame) {
        if (!isDepthSupported) {
            isDepthAvailable = false
            return
        }

        try {
            val depthImage = frame.acquireDepthImage16Bits()
            isDepthAvailable = true
            depthImage.close()
        } catch (t: Throwable) {
            isDepthAvailable = false
        }
    }

    fun getDepthDiagnostics(): Map<String, Any> {
        return mapOf(
            "depthSupported" to isDepthSupported,
            "depthAvailable" to isDepthAvailable
        )
    }
}
