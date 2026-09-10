package com.pathlume.app.ar

import android.app.Activity
import android.content.Context
import android.util.Log
import com.google.ar.core.ArCoreApk
import com.google.ar.core.CameraConfig
import com.google.ar.core.CameraConfigFilter
import com.google.ar.core.Config
import com.google.ar.core.Session

class ARSessionManager(private val context: Context) {
    companion object {
        private const val TAG = "PATHLUME_AR"
    }

    var arSession: Session? = null
        private set

    fun createSession(): Session? {
        return try {
            if (context is Activity) {
                var userRequestedInstall = true
                when (ArCoreApk.getInstance().requestInstall(context, userRequestedInstall)) {
                    ArCoreApk.InstallStatus.INSTALL_REQUESTED -> {
                        Log.i(TAG, "PATHLUME_AR INSTALL_REQUESTED")
                        return null
                    }
                    ArCoreApk.InstallStatus.INSTALLED -> {}
                }
            }
            val session = Session(context)

            // Select highest resolution supported rear camera config
            try {
                val filter = CameraConfigFilter(session).apply {
                    facingDirection = CameraConfig.FacingDirection.BACK
                }
                val configs = session.getSupportedCameraConfigs(filter)
                val bestConfig = configs.maxByOrNull { config ->
                    val texArea = config.textureSize.width * config.textureSize.height
                    val imgArea = config.imageSize.width * config.imageSize.height
                    texArea * 10 + imgArea
                }
                if (bestConfig != null) {
                    session.cameraConfig = bestConfig
                    Log.i(TAG, "PATHLUME_AR CAMERA_CONFIG_SELECTED resolution=${bestConfig.textureSize.width}x${bestConfig.textureSize.height} img=${bestConfig.imageSize.width}x${bestConfig.imageSize.height} fps=${bestConfig.fpsRange.lower}-${bestConfig.fpsRange.upper}")
                }
            } catch (e: Exception) {
                Log.w(TAG, "PATHLUME_AR CAMERA_CONFIG_SELECTION_FAILED", e)
            }

            val config = Config(session).apply {
                focusMode = Config.FocusMode.AUTO
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                lightEstimationMode = Config.LightEstimationMode.AMBIENT_INTENSITY
            }
            session.configure(config)
            Log.i(TAG, "PATHLUME_AR CAMERA_FOCUS_CONFIGURED focusMode=AUTO")
            arSession = session
            session
        } catch (t: Throwable) {
            Log.e(TAG, "PATHLUME_AR SESSION_CREATE_FAILED", t)
            arSession = null
            null
        }
    }

    fun resumeSession(): Boolean {
        return try {
            val session = arSession
            if (session != null) {
                session.resume()
                try {
                    val config = session.config
                    config.focusMode = Config.FocusMode.AUTO
                    session.configure(config)
                    Log.i(TAG, "PATHLUME_AR CAMERA_FOCUS_CONFIGURED_ON_RESUME focusMode=AUTO")
                } catch (e: Exception) {
                    Log.w(TAG, "PATHLUME_AR CAMERA_FOCUS_CONFIG_FAILED_ON_RESUME", e)
                }
                Log.i(TAG, "PATHLUME_AR CAMERA_SESSION_RESUMED")
            }
            true
        } catch (t: Throwable) {
            Log.e(TAG, "PATHLUME_AR SESSION_RESUME_FAILED", t)
            false
        }
    }

    fun pauseSession() {
        try {
            arSession?.pause()
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to pause ARCore Session safely", t)
        }
    }

    fun destroySession() {
        try {
            arSession?.close()
            arSession = null
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to destroy ARCore Session safely", t)
            arSession = null
        }
    }
}


