package com.pathlume.app.ar

import com.google.ar.core.Pose
import com.google.ar.core.TrackingState

data class ARPoseData(
    val positionX: Float,
    val positionY: Float,
    val positionZ: Float,
    val rotationX: Float,
    val rotationY: Float,
    val rotationZ: Float,
    val rotationW: Float,
    val trackingState: String,
    val timestamp: Long,
    val isMarkerPlaced: Boolean
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "position" to mapOf("x" to positionX, "y" to positionY, "z" to positionZ),
            "rotation" to mapOf("x" to rotationX, "y" to rotationY, "z" to rotationZ, "w" to rotationW),
            "trackingState" to trackingState,
            "timestamp" to timestamp,
            "isMarkerPlaced" to isMarkerPlaced
        )
    }
}

class ARPoseManager {
    fun extractPose(pose: Pose?, trackingState: TrackingState, isMarkerPlaced: Boolean): ARPoseData {
        if (pose == null) {
            return ARPoseData(0f, 0f, 0f, 0f, 0f, 0f, 1f, trackingState.name, System.currentTimeMillis(), isMarkerPlaced)
        }
        val translation = pose.translation
        val rotation = pose.rotationQuaternion

        val px = if (translation[0].isNaN() || translation[0].isInfinite()) 0f else translation[0]
        val py = if (translation[1].isNaN() || translation[1].isInfinite()) 0f else translation[1]
        val pz = if (translation[2].isNaN() || translation[2].isInfinite()) 0f else translation[2]

        val rx = if (rotation[0].isNaN() || rotation[0].isInfinite()) 0f else rotation[0]
        val ry = if (rotation[1].isNaN() || rotation[1].isInfinite()) 0f else rotation[1]
        val rz = if (rotation[2].isNaN() || rotation[2].isInfinite()) 0f else rotation[2]
        val rw = if (rotation[3].isNaN() || rotation[3].isInfinite()) 1f else rotation[3]

        return ARPoseData(
            positionX = px,
            positionY = py,
            positionZ = pz,
            rotationX = rx,
            rotationY = ry,
            rotationZ = rz,
            rotationW = rw,
            trackingState = trackingState.name,
            timestamp = System.currentTimeMillis(),
            isMarkerPlaced = isMarkerPlaced
        )
    }
}
