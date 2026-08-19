package com.pathlume.app.navigation

import com.pathlume.app.data.remote.NavigationEdgeData
import com.pathlume.app.data.remote.NavigationGraphData
import com.pathlume.app.data.remote.NavigationNodeData
import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.localization.WorldCoordinateManager
import java.util.PriorityQueue

class AStarEngine(
    private val graphData: NavigationGraphData
) {
    private val nodeMap = graphData.nodes.associateBy { it.id }
    private val adjacency = mutableMapOf<String, MutableList<NavigationEdgeData>>()

    init {
        graphData.edges.forEach { edge ->
            if (edge.walkable) {
                adjacency.getOrPut(edge.from) { mutableListOf() }.add(edge)
                adjacency.getOrPut(edge.to) { mutableListOf() }.add(
                    NavigationEdgeData(
                        from = edge.to,
                        to = edge.from,
                        distance = edge.distance,
                        walkable = edge.walkable,
                        transitionType = edge.transitionType
                    )
                )
            }
        }
    }

    fun findNearestNode(position: Vector3D, floorId: String? = null): NavigationNodeData? {
        var bestNode: NavigationNodeData? = null
        var bestDistance = Float.MAX_VALUE

        graphData.nodes.forEach { node ->
            if (floorId == null || node.floorId == floorId) {
                val dist = WorldCoordinateManager.distanceMeters(position, Vector3D(node.x, node.y, node.z))
                if (dist < bestDistance) {
                    bestDistance = dist
                    bestNode = node
                }
            }
        }

        return bestNode
    }

    /**
     * Calculates A* route from start node ID to target node ID.
     */
    fun findRoute(startNodeId: String, targetNodeId: String): List<NavigationNodeData> {
        val startNode = nodeMap[startNodeId] ?: return emptyList()
        val targetNode = nodeMap[targetNodeId] ?: return emptyList()

        if (startNodeId == targetNodeId) return listOf(startNode)

        val gScore = mutableMapOf<String, Float>().withDefault { Float.MAX_VALUE }
        val fScore = mutableMapOf<String, Float>().withDefault { Float.MAX_VALUE }
        val cameFrom = mutableMapOf<String, String>()

        val openSet = PriorityQueue<Pair<String, Float>>(compareBy { it.second })

        gScore[startNodeId] = 0f
        val initialH = heuristic(startNode, targetNode)
        fScore[startNodeId] = initialH
        openSet.add(Pair(startNodeId, initialH))

        val visited = mutableSetOf<String>()

        while (openSet.isNotEmpty()) {
            val currentId = openSet.poll()!!.first

            if (currentId == targetNodeId) {
                return reconstructPath(cameFrom, currentId)
            }

            if (!visited.add(currentId)) continue

            val currentG = gScore.getValue(currentId)
            val neighbors = adjacency[currentId] ?: emptyList()

            for (edge in neighbors) {
                val neighborId = edge.to
                val neighborNode = nodeMap[neighborId] ?: continue

                // Transition cost multiplier for vertical transitions (stairs/elevators)
                val transitionMultiplier = when (edge.transitionType) {
                    "stairs" -> 1.5f
                    "elevator" -> 1.2f
                    else -> 1.0f
                }
                val tentativeG = currentG + edge.distance * transitionMultiplier

                if (tentativeG < gScore.getValue(neighborId)) {
                    cameFrom[neighborId] = currentId
                    gScore[neighborId] = tentativeG
                    val f = tentativeG + heuristic(neighborNode, targetNode)
                    fScore[neighborId] = f
                    openSet.add(Pair(neighborId, f))
                }
            }
        }

        return emptyList()
    }

    private fun heuristic(a: NavigationNodeData, b: NavigationNodeData): Float {
        val p1 = Vector3D(a.x, a.y, a.z)
        val p2 = Vector3D(b.x, b.y, b.z)
        val floorDiff = Math.abs(if (a.floorId == b.floorId) 0 else 1) * 3.0f
        return WorldCoordinateManager.distanceMeters(p1, p2) + floorDiff
    }

    private fun reconstructPath(cameFrom: Map<String, String>, currentId: String): List<NavigationNodeData> {
        val path = mutableListOf<NavigationNodeData>()
        var curr: String? = currentId
        while (curr != null) {
            nodeMap[curr]?.let { path.add(it) }
            curr = cameFrom[curr]
        }
        return path.reversed()
    }
}
