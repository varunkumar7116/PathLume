package com.pathlume.app.vps

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class VpsLocalizationManager(
    private val vpsProvider: VpsProvider
) {
    private val _status = MutableStateFlow(VPSStatus.INITIALIZING)
    val status: StateFlow<VPSStatus> = _status.asStateFlow()

    private val _currentPose = MutableStateFlow<VPSPose?>(null)
    val currentPose: StateFlow<VPSPose?> = _currentPose.asStateFlow()

    private val _lastLatencyMs = MutableStateFlow(0L)
    val lastLatencyMs: StateFlow<Long> = _lastLatencyMs.asStateFlow()

    private var lastSuccessfulPoseTimestamp = 0L
    private val lostTimeoutMs = 8000L

    suspend fun processCameraFrame(imageBase64: String, siteId: String): VPSPoseResult {
        if (_status.value == VPSStatus.UNAVAILABLE) {
            return VPSPoseResult(isLocalized = false, status = VPSStatus.UNAVAILABLE, message = "VPS Provider Unavailable")
        }

        _status.value = VPSStatus.SEARCHING
        val result = vpsProvider.localizeFrame(imageBase64, siteId)
        _lastLatencyMs.value = result.latencyMs

        if (result.isLocalized && result.pose != null) {
            _currentPose.value = result.pose
            _status.value = result.status
            lastSuccessfulPoseTimestamp = System.currentTimeMillis()
        } else {
            val now = System.currentTimeMillis()
            if (lastSuccessfulPoseTimestamp > 0 && (now - lastSuccessfulPoseTimestamp) < lostTimeoutMs) {
                _status.value = VPSStatus.TEMPORARILY_LOST
            } else {
                _status.value = result.status
            }
        }

        return result
    }

    fun setStatus(status: VPSStatus) {
        _status.value = status
    }
}
