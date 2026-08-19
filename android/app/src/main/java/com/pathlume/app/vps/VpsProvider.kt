package com.pathlume.app.vps

import com.pathlume.app.domain.model.Vector3D

enum class VPSStatus {
    UNAVAILABLE,
    INITIALIZING,
    SEARCHING,
    LOCALIZED,
    LOW_CONFIDENCE,
    TEMPORARILY_LOST,
    ERROR
}

data class VPSPose(
    val position: Vector3D,
    val heading: Float,
    val floor: Int,
    val accuracy: Float, // in meters
    val timestamp: Long = System.currentTimeMillis()
)

interface VpsProvider {
    suspend fun localizeFrame(imageBase64: String, siteId: String): VPSPoseResult
}

data class VPSPoseResult(
    val isLocalized: Boolean,
    val pose: VPSPose? = null,
    val status: VPSStatus = VPSStatus.SEARCHING,
    val message: String? = null,
    val latencyMs: Long = 0
)
