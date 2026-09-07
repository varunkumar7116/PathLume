package com.pathlume.app.ar

import android.content.Context
import android.util.Log
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Pose
import com.google.ar.core.TrackingState

class ARCoreManager(private val context: Context) {
    companion object {
        private const val TAG = "PATHLUME_AR"
    }

    val sessionManager = ARSessionManager(context)
    val poseManager = ARPoseManager()
    val anchorManager = ARAnchorManager()
    val coordinateSystem = ARCoordinateSystem()
    val renderer = ARRenderer()
    val augmentedImageManager = ARAugmentedImageManager()
    val depthManager = ARDepthManager()

    var isARSupported: Boolean = false
        private set

    var isSessionActive: Boolean = false
        private set

    @Volatile
    var latestPoseData: ARPoseData? = null
        private set

    fun checkARAvailability(): Boolean {
        return try {
            val availability = ArCoreApk.getInstance().checkAvailability(context)
            isARSupported = availability.isSupported
            Log.i(TAG, "PATHLUME_AR CHECK_AVAILABILITY supported=$isARSupported")
            isARSupported
        } catch (t: Throwable) {
            Log.e(TAG, "PATHLUME_AR CHECK_AVAILABILITY_FAILED", t)
            isARSupported = false
            false
        }
    }

    fun startARCoreSession(): Boolean {
        return try {
            if (sessionManager.arSession == null) {
                val session = sessionManager.createSession() ?: return false
                val config = session.config
                augmentedImageManager.setupAugmentedImageDatabase(session, config)
                depthManager.configureDepthMode(session, config)
                session.configure(config)
                renderer.setSession(session)
            }
            val resumed = sessionManager.resumeSession()
            if (!resumed) return false

            renderer.onFrameUpdateListener = { frame, session ->
                val camera = frame.camera
                latestPoseData = poseManager.extractPose(
                    camera.pose,
                    camera.trackingState,
                    anchorManager.hasActiveAnchor()
                )
                augmentedImageManager.processFrame(frame)
                depthManager.processFrame(frame)
                renderer.activeAnchors = anchorManager.getActiveAnchors()
            }

            isSessionActive = true
            Log.i(TAG, "PATHLUME_AR SESSION_STARTED")
            true
        } catch (t: Throwable) {
            Log.e(TAG, "PATHLUME_AR SESSION_START_FAILED", t)
            isSessionActive = false
            false
        }
    }

    fun resumeARCoreSession() {
        if (isSessionActive) {
            Log.i(TAG, "PATHLUME_AR SESSION_RESUMED")
            sessionManager.resumeSession()
        }
    }

    fun pauseARCoreSession() {
        Log.i(TAG, "PATHLUME_AR SESSION_PAUSED")
        sessionManager.pauseSession()
    }

    fun stopARCoreSession() {
        Log.i(TAG, "PATHLUME_AR SESSION_STOPPED")
        isSessionActive = false
        anchorManager.clearAnchors()
        sessionManager.destroySession()
        latestPoseData = null
    }

    fun placeTestMarker(): Boolean {
        val session = sessionManager.arSession ?: return false
        return try {
            val lastPose = latestPoseData
            val pose = if (lastPose != null) {
                Pose.makeTranslation(lastPose.positionX, lastPose.positionY - 0.1f, lastPose.positionZ - 0.5f)
            } else {
                Pose.makeTranslation(0f, -0.1f, -1.0f)
            }
            val anchor = anchorManager.createAnchorAtPose(session, pose)
            anchor != null
        } catch (t: Throwable) {
            Log.e(TAG, "placeTestMarker failed safely", t)
            false
        }
    }

    fun addNodeAnchor(x: Float, y: Float, z: Float): Boolean {
        Log.i(TAG, "PATHLUME_AR ANCHOR_CREATE_START pos=($x, $y, $z)")
        val session = sessionManager.arSession
        if (session == null) {
            Log.w(TAG, "PATHLUME_AR ANCHOR_CREATE_FAILED reason=null_session")
            return false
        }
        return try {
            val lastPose = latestPoseData
            Log.i(TAG, "PATHLUME_AR ANCHOR_CREATE_PRE_CHECK tracking_state=${lastPose?.trackingState ?: "UNKNOWN"}")

            val existing = anchorManager.getActiveAnchors().find { a ->
                val p = a.pose
                val dx = p.tx() - x
                val dy = p.ty() - y
                val dz = p.tz() - z
                (dx * dx + dy * dy + dz * dz) < 0.0025f
            }
            if (existing != null) {
                renderer.activeAnchors = anchorManager.getActiveAnchors()
                Log.i(TAG, "PATHLUME_AR ANCHOR_EXISTS pos=($x, $y, $z) count=${anchorManager.getActiveAnchors().size}")
                return true
            }

            val pose = Pose.makeTranslation(x, y, z)
            val anchor = anchorManager.createAnchorAtPose(session, pose)
            if (anchor != null) {
                renderer.activeAnchors = anchorManager.getActiveAnchors()
                val currentTracking = getTrackingState()
                Log.i(TAG, "PATHLUME_AR ANCHOR_CREATED id=${anchor.hashCode()} total_count=${anchorManager.getActiveAnchors().size}")
                Log.i(TAG, "PATHLUME_AR TRACKING_AFTER_ANCHOR state=$currentTracking")
                true
            } else {
                Log.w(TAG, "PATHLUME_AR ANCHOR_CREATE_FAILED pos=($x, $y, $z)")
                false
            }
        } catch (t: Throwable) {
            Log.e(TAG, "PATHLUME_AR ANCHOR_CREATE_EXCEPTION pos=($x, $y, $z)", t)
            false
        }
    }

    fun resetSession() {
        anchorManager.clearAnchors()
    }

    fun getCurrentPose(): ARPoseData? {
        return latestPoseData ?: ARPoseData(
            0f, 0f, 0f, 0f, 0f, 0f, 1f,
            TrackingState.STOPPED.name,
            System.currentTimeMillis(),
            anchorManager.hasActiveAnchor()
        )
    }

    fun getTrackingState(): String {
        return latestPoseData?.trackingState ?: TrackingState.STOPPED.name
    }

    fun requestQRPose(): Map<String, Any>? {
        val lastPose = latestPoseData ?: return null
        if (lastPose.trackingState != TrackingState.TRACKING.name) return null

        val imagePose = augmentedImageManager.latestImagePoseData

        return mapOf(
            "poseAvailable" to true,
            "poseSource" to (if (imagePose != null) "augmentedImage" to imagePose else "nativeArCore"),
            "pose" to lastPose.toMap(),
            "timestamp" to System.currentTimeMillis()
        )
    }

    fun setNavigationRoute(points: List<FloatArray>, destination: FloatArray?) {
        renderer.setNavigationRoute(points, destination)
    }

    fun clearNavigationRoute() {
        renderer.clearNavigationRoute()
    }

    fun getCameraDiagnostics(): Map<String, Any> {
        val session = sessionManager.arSession
        val config = try { session?.cameraConfig } catch (e: Exception) { null }
        val focusMode = try { session?.config?.focusMode?.name } catch (e: Exception) { "AUTO" }

        val diag = mutableMapOf<String, Any>(
            "cameraConfigResolution" to "${config?.textureSize?.width ?: 0}x${config?.textureSize?.height ?: 0}",
            "cameraConfigImageSize" to "${config?.imageSize?.width ?: 0}x${config?.imageSize?.height ?: 0}",
            "cameraConfigFps" to "${config?.fpsRange?.lower ?: 30}-${config?.fpsRange?.upper ?: 30}",
            "focusMode" to (focusMode ?: "AUTO"),
            "trackingState" to getTrackingState(),
            "anchorCount" to anchorManager.getActiveAnchors().size
        )

        diag.putAll(depthManager.getDepthDiagnostics())
        augmentedImageManager.latestImagePoseData?.let {
            diag["augmentedImage"] = it
        }

        return diag
    }
}
