package com.pathlume.app.vps

import com.pathlume.app.data.remote.LocalizeRequest
import com.pathlume.app.data.remote.PathLumeApiService

class RealVpsProvider(
    private val apiService: PathLumeApiService
) : VpsProvider {

    override suspend fun localizeFrame(imageBase64: String, siteId: String): VPSPoseResult {
        val startTime = System.currentTimeMillis()
        try {
            val response = apiService.localizeFrame(LocalizeRequest(siteId = siteId, image = imageBase64))
            val latency = System.currentTimeMillis() - startTime

            if (response.isSuccessful && response.body() != null) {
                val body = response.body()!!
                if (body.localized && body.position != null) {
                    val pose = VPSPose(
                        position = body.position,
                        heading = body.heading ?: 0f,
                        floor = body.floor ?: 1,
                        accuracy = body.accuracy ?: 0.5f,
                        timestamp = System.currentTimeMillis()
                    )
                    val status = if (pose.accuracy <= 2.0f) VPSStatus.LOCALIZED else VPSStatus.LOW_CONFIDENCE
                    return VPSPoseResult(
                        isLocalized = true,
                        pose = pose,
                        status = status,
                        latencyMs = latency
                    )
                } else {
                    return VPSPoseResult(
                        isLocalized = false,
                        status = VPSStatus.SEARCHING,
                        message = body.message ?: "Frame unlocalized",
                        latencyMs = latency
                    )
                }
            } else {
                return VPSPoseResult(
                    isLocalized = false,
                    status = VPSStatus.ERROR,
                    message = "VPS HTTP Error (${response.code()}): ${response.message()}",
                    latencyMs = latency
                )
            }
        } catch (e: Exception) {
            val latency = System.currentTimeMillis() - startTime
            return VPSPoseResult(
                isLocalized = false,
                status = VPSStatus.ERROR,
                message = "Network error communicating with VPS: ${e.localizedMessage}",
                latencyMs = latency
            )
        }
    }
}
