package com.pathlume.app.navigation

import com.pathlume.app.data.remote.NavigationNodeData
import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.localization.WorldCoordinateManager

object OffRouteDetector {
    private const val OFF_ROUTE_THRESHOLD_METERS = 2.0f

    /**
     * Evaluates if user's fused position has strayed >2.0 meters from the current route corridor.
     */
    fun isOffRoute(userPosition: Vector3D, route: List<NavigationNodeData>): Boolean {
        if (route.isEmpty()) return false
        val minDistance = distanceToRouteCorridor(userPosition, route)
        return minDistance > OFF_ROUTE_THRESHOLD_METERS
    }

    fun distanceToRouteCorridor(userPosition: Vector3D, route: List<NavigationNodeData>): Float {
        if (route.isEmpty()) return Float.MAX_VALUE
        if (route.size == 1) {
            val node = route[0]
            return WorldCoordinateManager.distanceMeters(userPosition, Vector3D(node.x, node.y, node.z))
        }

        var minDistance = Float.MAX_VALUE
        for (i in 0 until route.size - 1) {
            val p1 = Vector3D(route[i].x, route[i].y, route[i].z)
            val p2 = Vector3D(route[i + 1].x, route[i + 1].y, route[i + 1].z)
            val dist = distanceToSegment(userPosition, p1, p2)
            if (dist < minDistance) {
                minDistance = dist
            }
        }
        return minDistance
    }

    private fun distanceToSegment(p: Vector3D, a: Vector3D, b: Vector3D): Float {
        val ab = Vector3D(b.x - a.x, b.y - a.y, b.z - a.z)
        val ap = Vector3D(p.x - a.x, p.y - a.y, p.z - a.z)
        val ab2 = ab.x * ab.x + ab.y * ab.y + ab.z * ab.z
        if (ab2 == 0f) return WorldCoordinateManager.distanceMeters(p, a)

        var t = (ap.x * ab.x + ap.y * ab.y + ap.z * ab.z) / ab2
        t = Math.max(0f, Math.min(1f, t))

        val proj = Vector3D(a.x + t * ab.x, a.y + t * ab.y, a.z + t * ab.z)
        return WorldCoordinateManager.distanceMeters(p, proj)
    }
}
