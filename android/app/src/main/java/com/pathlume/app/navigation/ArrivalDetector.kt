package com.pathlume.app.navigation

import com.pathlume.app.domain.model.Destination
import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.localization.WorldCoordinateManager

object ArrivalDetector {
    private const val ARRIVAL_RADIUS_METERS = 2.5f

    /**
     * Determines if user has reached destination by checking proximity AND floor level matching.
     */
    fun hasArrived(
        userPosition: Vector3D,
        userFloor: Int,
        destination: Destination,
        destinationFloorLevel: Int
    ): Boolean {
        // Must match floor level first
        if (userFloor != destinationFloorLevel) return false

        val distance = WorldCoordinateManager.distanceMeters(userPosition, destination.position)
        return distance <= ARRIVAL_RADIUS_METERS
    }
}
