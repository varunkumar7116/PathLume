package com.pathlume.app.ar

import android.content.Context
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Camera
import com.google.ar.core.Frame
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.UnavailableException
import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.localization.ARCorePose
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class ARCoreStatus {
    UNINITIALIZED,
    CHECKING_AVAILABILITY,
    SUPPORTED,
    UNSUPPORTED,
    PERMISSION_DENIED,
    SESSION_ACTIVE,
    TRACKING,
    PAUSED,
    ERROR
}

class ARCoreSessionManager(private val context: Context) {

    private var arSession: Session? = null
    private val _status = MutableStateFlow(ARCoreStatus.UNINITIALIZED)
    val status: StateFlow<ARCoreStatus> = _status.asStateFlow()

    private val _currentPose = MutableStateFlow<ARCorePose?>(null)
    val currentPose: StateFlow<ARCorePose?> = _currentPose.asStateFlow()

    fun checkArCoreSupport(): Boolean {
        _status.value = ARCoreStatus.CHECKING_AVAILABILITY
        val availability = ArCoreApk.getInstance().checkAvailability(context)
        return if (availability.isSupported) {
            _status.value = ARCoreStatus.SUPPORTED
            true
        } else {
            _status.value = ARCoreStatus.UNSUPPORTED
            false
        }
    }

    fun initSession(): Session? {
        if (arSession != null) return arSession

        try {
            val session = Session(context)
            this.arSession = session
            _status.value = ARCoreStatus.SESSION_ACTIVE
            return session
        } catch (e: UnavailableException) {
            e.printStackTrace()
            _status.value = ARCoreStatus.UNSUPPORTED
        } catch (e: Exception) {
            e.printStackTrace()
            _status.value = ARCoreStatus.ERROR
        }
        return null
    }

    fun updateFrame(frame: Frame) {
        val camera = frame.camera
        val trackingState = camera.trackingState

        if (trackingState == TrackingState.TRACKING) {
            _status.value = ARCoreStatus.TRACKING
            val pose = camera.pose
            val translation = pose.translation
            val newPose = ARCorePose(
                position = Vector3D(translation[0], translation[1], translation[2]),
                heading = extractYawDegrees(pose.rotationQuaternion),
                timestamp = System.currentTimeMillis()
            )
            _currentPose.value = newPose
        } else if (trackingState == TrackingState.PAUSED) {
            _status.value = ARCoreStatus.PAUSED
        }
    }

    fun pause() {
        try {
            arSession?.pause()
            _status.value = ARCoreStatus.PAUSED
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun resume() {
        try {
            arSession?.resume()
            _status.value = ARCoreStatus.SESSION_ACTIVE
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun destroy() {
        try {
            arSession?.close()
            arSession = null
            _status.value = ARCoreStatus.UNINITIALIZED
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun extractYawDegrees(q: FloatArray): Float {
        // Extract yaw angle from Quaternion (x, y, z, w)
        val qx = q[0]
        val qy = q[1]
        val qz = q[2]
        val qw = q[3]
        val sinyCosp = 2.0 * (qw * qz + qx * qy)
        val cosyCosp = 1.0 - 2.0 * (qy * qy + qz * qz)
        val yawRad = Math.atan2(sinyCosp, cosyCosp)
        var yawDeg = Math.toDegrees(yawRad).toFloat()
        if (yawDeg < 0) yawDeg += 360f
        return yawDeg
    }
}
