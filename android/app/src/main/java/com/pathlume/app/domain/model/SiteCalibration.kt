package com.pathlume.app.domain.model

import kotlinx.serialization.Serializable

@Serializable
data class SiteCalibrationDraft(
    val versionId: String, // e.g. "v1", "v2"
    val siteId: String,
    val translation: Vector3D = Vector3D(0f, 0f, 0f),
    val rotation: Vector3D = Vector3D(0f, 0f, 0f),
    val scale: Float = 1.0f,
    val floorHeightMeters: Float = 0.0f,
    val updatedAtMs: Long = System.currentTimeMillis(),
    val updatedBy: String = "Developer Tester"
)

object CalibrationVersionManager {
    private val calibrationHistory = mutableListOf(
        SiteCalibrationDraft(
            versionId = "v1",
            siteId = "controlled_test_site",
            translation = Vector3D(0f, 0f, 0f),
            rotation = Vector3D(0f, 0f, 0f),
            scale = 1.0f,
            floorHeightMeters = 0.0f
        )
    )

    fun getActiveCalibration(): SiteCalibrationDraft {
        return calibrationHistory.last()
    }

    fun getAllVersions(): List<SiteCalibrationDraft> {
        return calibrationHistory.toList()
    }

    fun createNewDraft(
        siteId: String,
        translation: Vector3D,
        rotation: Vector3D,
        scale: Float,
        floorHeight: Float,
        author: String = "Developer Tester"
    ): SiteCalibrationDraft {
        val nextVersionNumber = calibrationHistory.size + 1
        val newDraft = SiteCalibrationDraft(
            versionId = "v$nextVersionNumber",
            siteId = siteId,
            translation = translation,
            rotation = rotation,
            scale = scale,
            floorHeightMeters = floorHeight,
            updatedAtMs = System.currentTimeMillis(),
            updatedBy = author
        )
        calibrationHistory.add(newDraft)
        return newDraft
    }
}
