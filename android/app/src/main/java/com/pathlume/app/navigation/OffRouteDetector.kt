package com.pathlume.app.navigation

import com.pathlume.app.domain.model.Vector3D

class OffRouteDetector(private val corridorThresholdMeters: Float = 4.0f) {

    /**
     * Determines if the current user position is outside the active route corridor.
     */
    fun isOffRoute(
        currentPosition: Vector3D,
        routeNodes: List<RouteNode>
    ): Boolean {
        if (routeNodes.size < 2) return false

        val minDistance = getMinDistanceToRoute(currentPosition, routeNodes)
        return minDistance > corridorThresholdMeters
    }

    fun getMinDistanceToRoute(
        currentPosition: Vector3D,
        routeNodes: List<RouteNode>
    ): Float {
        if (routeNodes.isEmpty()) return Float.MAX_VALUE
        if (routeNodes.size == 1) return distancePointToPoint(currentPosition, routeNodes[0].position)

        var minDistance = Float.MAX_VALUE

        for (i in 0 until routeNodes.size - 1) {
            val segStart = routeNodes[i].position
            val segEnd = routeNodes[i + 1].position
            val dist = distancePointToSegment(currentPosition, segStart, segEnd)
            if (dist < minDistance) {
                minDistance = dist
            }
        }

        return minDistance
    }

    private fun distancePointToPoint(a: Vector3D, b: Vector3D): Float {
        val dx = a.x - b.x
        val dy = a.y - b.y
        val dz = a.z - b.z
        return Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
    }

    private fun distancePointToSegment(p: Vector3D, a: Vector3D, b: Vector3D): Float {
        val abx = b.x - a.x
        val aby = b.y - a.y
        val abz = b.z - a.z

        val apx = p.x - a.x
        val apy = p.y - a.y
        val apz = p.z - a.z

        val abLenSq = abx * abx + aby * aby + abz * abz
        if (abLenSq == 0f) return distancePointToPoint(p, a)

        var t = (apx * abx + apy * aby + apz * abz) / abLenSq
        t = Math.max(0f, Math.min(1f, t))

        val projX = a.x + t * abx
        val projY = a.y + t * aby
        val projZ = a.z + t * abz

        val dx = p.x - projX
        val dy = p.y - projY
        val dz = p.z - projZ

        return Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
    }
}
