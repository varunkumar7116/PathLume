package com.pathlume.app.localization

import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.vps.VPSPose
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class ARCorePose(
    val position: Vector3D,
    val heading: Float,
    val timestamp: Long = System.currentTimeMillis()
)

data class FusedPose(
    val position: Vector3D,
    val heading: Float,
    val floor: Int,
    val accuracy: Float,
    val driftMeters: Float,
    val vpsLastUpdatedMs: Long,
    val status: FusedPoseStatus,
    val timestamp: Long = System.currentTimeMillis()
)

enum class FusedPoseStatus {
    ACTIVE,
    DRIFTING,
    WEAK_SIGNAL,
    LOST
}

class PoseFusionManager {
    private val _fusedPose = MutableStateFlow(
        FusedPose(
            position = Vector3D(0f, 0f, 0f),
            heading = 0f,
            floor = 1,
            accuracy = 1.0f,
            driftMeters = 0f,
            vpsLastUpdatedMs = 0L,
            status = FusedPoseStatus.WEAK_SIGNAL
        )
    )
    val fusedPose: StateFlow<FusedPose> = _fusedPose.asStateFlow()

    private var lastArCorePose: ARCorePose? = null
    private val blendFactor = 0.3f // Weight of VPS correction
    private val maxTeleportDistanceMeters = 5.0f

    /**
     * Applies continuous relative motion tracking updates from ARCore.
     */
    fun updateARCoreMotion(newArCorePose: ARCorePose) {
        val lastAr = lastArCorePose
        if (lastAr == null) {
            lastArCorePose = newArCorePose
            return
        }

        val dx = newArCorePose.position.x - lastAr.position.x
        val dy = newArCorePose.position.y - lastAr.position.y
        val dz = newArCorePose.position.z - lastAr.position.z
        val dh = newArCorePose.heading - lastAr.heading

        lastArCorePose = newArCorePose

        val current = _fusedPose.value
        val newPos = Vector3D(
            x = current.position.x + dx,
            y = current.position.y + dy,
            z = current.position.z + dz
        )
        val newHeading = (current.heading + dh + 360f) % 360f

        _fusedPose.value = current.copy(
            position = newPos,
            heading = newHeading,
            timestamp = System.currentTimeMillis()
        )
    }

    /**
     * Applies absolute low-frequency VPS pose correction.
     */
    fun applyVPSCorrection(vpsPose: VPSPose) {
        val current = _fusedPose.value
        val now = System.currentTimeMillis()
        val isFirstUpdate = current.vpsLastUpdatedMs == 0L

        val drift = WorldCoordinateManager.distanceMeters(current.position, vpsPose.position)

        val blendedPos: Vector3D
        val blendedHeading: Float

        if (drift > maxTeleportDistanceMeters || isFirstUpdate) {
            // Immediate snap
            blendedPos = vpsPose.position
            blendedHeading = vpsPose.heading
        } else {
            // Lerp blending
            blendedPos = Vector3D(
                x = current.position.x + (vpsPose.position.x - current.position.x) * blendFactor,
                y = current.position.y + (vpsPose.position.y - current.position.y) * blendFactor,
                z = current.position.z + (vpsPose.position.z - current.position.z) * blendFactor
            )
            var dh = vpsPose.heading - current.heading
            if (dh > 180f) dh -= 360f
            if (dh < -180f) dh += 360f
            blendedHeading = (current.heading + dh * blendFactor + 360f) % 360f
        }

        val status = if (vpsPose.accuracy <= 2.0f) FusedPoseStatus.ACTIVE else FusedPoseStatus.DRIFTING

        _fusedPose.value = FusedPose(
            position = blendedPos,
            heading = blendedHeading,
            floor = vpsPose.floor,
            accuracy = vpsPose.accuracy,
            driftMeters = Math.round(drift * 100f) / 100f,
            vpsLastUpdatedMs = now,
            status = status,
            timestamp = now
        )
    }
}
