package com.pathlume.app.localization

import com.pathlume.app.domain.model.CoordinateSystemConfig
import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.vps.VPSPose

/**
 * Handles explicit mathematical transformations into the canonical SITE WORLD COORDINATE SYSTEM.
 */
object WorldCoordinateManager {

    /**
     * Transforms raw GLB model coordinate into Site World coordinate.
     */
    fun transformGLBToSite(glbPoint: Vector3D, config: CoordinateSystemConfig): Vector3D {
        val scaledX = glbPoint.x * config.scale
        val scaledY = glbPoint.y * config.scale
        val scaledZ = glbPoint.z * config.scale

        return Vector3D(
            x = scaledX + config.translation.x,
            y = scaledY + config.translation.y,
            z = scaledZ + config.translation.z
        )
    }

    /**
     * Transforms raw VPS pose into Site World pose.
     */
    fun transformVPSToSite(rawVPSPose: VPSPose, config: CoordinateSystemConfig): VPSPose {
        val sitePos = transformGLBToSite(rawVPSPose.position, config)
        val siteHeading = (rawVPSPose.heading + config.rotation.y + 360f) % 360f

        return rawVPSPose.copy(
            position = sitePos,
            heading = siteHeading
        )
    }

    /**
     * Calculates Euclidean distance in meters between two Site World points.
     */
    fun distanceMeters(p1: Vector3D, p2: Vector3D): Float {
        val dx = (p1.x - p2.x).toDouble()
        val dy = (p1.y - p2.y).toDouble()
        val dz = (p1.z - p2.z).toDouble()
        return Math.sqrt(dx * dx + dy * dy + dz * dz).toFloat()
    }
}
