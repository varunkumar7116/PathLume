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

enum class VpsState {
    VPS_DISABLED,
    VPS_SEARCHING,
    VPS_LOCALIZING,
    VPS_LOCALIZED,
    VPS_LOW_CONFIDENCE,
    VPS_LOST,
    VPS_ERROR
}

data class VPSPose(
    val position: Vector3D,
    val heading: Float = 0f,
    val pitch: Float = 0f,
    val roll: Float = 0f,
    val floor: Int = 1,
    val accuracy: Float = 0.5f,
    val confidence: Float = 0.85f,
    val timestamp: Long = System.currentTimeMillis()
)

data class VPSPoseResult(
    val isLocalized: Boolean,
    val pose: VPSPose? = null,
    val status: VPSStatus = VPSStatus.SEARCHING,
    val message: String? = null,
    val latencyMs: Long = 0L,
    val providerName: String = "Immersal VPS Engine"
)

data class VpsProviderConfig(
    val siteId: String,
    val mapId: String,
    val providerName: String = "Immersal",
    val endpointUrl: String = "https://pathlume-9d8e9.web.app/api/vps/localize",
    val confidenceThreshold: Float = 0.80f,
    val maxAcceptableLatencyMs: Long = 2500L,
    val isEnabled: Boolean = true
)

interface VpsProvider {
    suspend fun localizeFrame(imageBase64: String, siteId: String): VPSPoseResult
}

class ImmersalVpsProvider(
    private val realVpsProvider: RealVpsProvider? = null
) : VpsProvider {
    override suspend fun localizeFrame(imageBase64: String, siteId: String): VPSPoseResult {
        if (realVpsProvider != null) {
            return realVpsProvider.localizeFrame(imageBase64, siteId)
        }
        return VPSPoseResult(
            isLocalized = false,
            status = VPSStatus.UNAVAILABLE,
            message = "VPS BLOCKED — REAL PROVIDER CONFIGURATION REQUIRED",
            providerName = "Immersal VPS Engine"
        )
    }
}

class GoogleGeospatialVpsProvider : VpsProvider {
    override suspend fun localizeFrame(imageBase64: String, siteId: String): VPSPoseResult {
        return VPSPoseResult(
            isLocalized = false,
            status = VPSStatus.UNAVAILABLE,
            message = "Google Geospatial VPS requires active ARCore Geospatial API token configuration.",
            providerName = "Google Geospatial VPS"
        )
    }
}

class UnavailableVpsProvider : VpsProvider {
    override suspend fun localizeFrame(imageBase64: String, siteId: String): VPSPoseResult {
        return VPSPoseResult(
            isLocalized = false,
            status = VPSStatus.UNAVAILABLE,
            message = "VPS BLOCKED — REAL PROVIDER CONFIGURATION REQUIRED",
            providerName = "Unavailable VPS Provider"
        )
    }
}
