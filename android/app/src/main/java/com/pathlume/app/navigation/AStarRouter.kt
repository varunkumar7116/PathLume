package com.pathlume.app.navigation

import com.pathlume.app.domain.model.Vector3D
import java.util.PriorityQueue

data class RouteNode(
    val id: String,
    val position: Vector3D,
    val floorId: String,
    val buildingId: String,
    val type: String = "walkable"
)

data class RouteEdge(
    val from: String,
    val to: String,
    val distance: Float,
    val walkable: Boolean = true,
    val transitionType: String = "walk"
)

class AStarRouter {

    fun findPath(
        nodes: List<RouteNode>,
        edges: List<RouteEdge>,
        startNodeId: String,
        targetNodeId: String
    ): List<RouteNode> {
        val nodeMap = nodes.associateBy { it.id }
        val start = nodeMap[startNodeId] ?: return emptyList()
        val target = nodeMap[targetNodeId] ?: return emptyList()

        if (startNodeId == targetNodeId) return listOf(start)

        // Adjacency map
        val adj = mutableMapOf<String, MutableList<Pair<RouteNode, Float>>>()
        edges.filter { it.walkable }.forEach { edge ->
            val fromNode = nodeMap[edge.from]
            val toNode = nodeMap[edge.to]
            if (fromNode != null && toNode != null) {
                val weightMultiplier = when (edge.transitionType) {
                    "stairs" -> 1.5f
                    "elevator" -> 1.2f
                    "ramp" -> 1.1f
                    else -> 1.0f
                }
                val cost = edge.distance * weightMultiplier
                adj.getOrPut(edge.from) { mutableListOf() }.add(Pair(toNode, cost))
                adj.getOrPut(edge.to) { mutableListOf() }.add(Pair(fromNode, cost))
            }
        }

        val gScore = mutableMapOf<String, Float>().withDefault { Float.MAX_VALUE }
        val fScore = mutableMapOf<String, Float>().withDefault { Float.MAX_VALUE }
        val cameFrom = mutableMapOf<String, String>()

        gScore[startNodeId] = 0f
        fScore[startNodeId] = heuristic(start.position, target.position)

        val openSet = PriorityQueue<Pair<String, Float>>(compareBy { it.second })
        openSet.add(Pair(startNodeId, fScore.getValue(startNodeId)))

        val openSetNodes = mutableSetOf(startNodeId)

        while (openSet.isNotEmpty()) {
            val (currentId, _) = openSet.poll()!!
            openSetNodes.remove(currentId)

            if (currentId == targetNodeId) {
                return reconstructPath(cameFrom, currentId, nodeMap)
            }

            val neighbors = adj[currentId] ?: emptyList()
            for ((neighborNode, weight) in neighbors) {
                val neighborId = neighborNode.id
                val tentativeGScore = gScore.getValue(currentId) + weight

                if (tentativeGScore < gScore.getValue(neighborId)) {
                    cameFrom[neighborId] = currentId
                    gScore[neighborId] = tentativeGScore
                    val estimatedFScore = tentativeGScore + heuristic(neighborNode.position, target.position)
                    fScore[neighborId] = estimatedFScore

                    if (!openSetNodes.contains(neighborId)) {
                        openSet.add(Pair(neighborId, estimatedFScore))
                        openSetNodes.add(neighborId)
                    }
                }
            }
        }

        return emptyList()
    }

    fun findNearestNode(nodes: List<RouteNode>, currentPosition: Vector3D): RouteNode? {
        return nodes.minByOrNull { distance(it.position, currentPosition) }
    }

    fun distance(a: Vector3D, b: Vector3D): Float {
        val dx = a.x - b.x
        val dy = a.y - b.y
        val dz = a.z - b.z
        return Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
    }

    private fun heuristic(a: Vector3D, b: Vector3D): Float {
        return distance(a, b)
    }

    private fun reconstructPath(
        cameFrom: Map<String, String>,
        currentId: String,
        nodeMap: Map<String, RouteNode>
    ): List<RouteNode> {
        val totalPath = mutableListOf<RouteNode>()
        var curr: String? = currentId
        while (curr != null) {
            val node = nodeMap[curr]
            if (node != null) totalPath.add(0, node)
            curr = cameFrom[curr]
        }
        return totalPath
    }
}
