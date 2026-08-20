package com.pathlume.app

import com.pathlume.app.data.remote.NavigationEdgeData
import com.pathlume.app.data.remote.NavigationGraphData
import com.pathlume.app.data.remote.NavigationNodeData
import com.pathlume.app.domain.model.Destination
import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.localization.FusedPose
import com.pathlume.app.localization.FusedPoseStatus
import com.pathlume.app.localization.PoseFusionManager
import com.pathlume.app.localization.WorldCoordinateManager
import com.pathlume.app.navigation.AStarEngine
import com.pathlume.app.navigation.ArrivalDetector
import com.pathlume.app.navigation.OffRouteDetector
import com.pathlume.app.vps.VPSPose
import org.junit.Assert.*
import org.junit.Test

class NavigationEngineTest {

    private val sampleGraph = NavigationGraphData(
        nodes = listOf(
            NavigationNodeData("node_1", 0f, 0f, 0f, "floor_0", "b1"),
            NavigationNodeData("node_2", 5f, 0f, 0f, "floor_0", "b1"),
            NavigationNodeData("node_3", 10f, 0f, 0f, "floor_0", "b1"),
            NavigationNodeData("node_stair", 10f, 0f, 3f, "floor_1", "b1")
        ),
        edges = listOf(
            NavigationEdgeData("node_1", "node_2", 5f),
            NavigationEdgeData("node_2", "node_3", 5f),
            NavigationEdgeData("node_3", "node_stair", 4f, walkable = true, transitionType = "stairs")
        )
    )

    @Test
    fun aStar_findsRouteAcrossNodes() {
        val engine = AStarEngine(sampleGraph)
        val route = engine.findRoute("node_1", "node_stair")
        assertEquals(4, route.size)
        assertEquals("node_1", route.first().id)
        assertEquals("node_stair", route.last().id)
    }

    @Test
    fun offRouteDetector_triggersWhenUserStraysOverThreshold() {
        val engine = AStarEngine(sampleGraph)
        val routeData = engine.findRoute("node_1", "node_3")
        val routeNodes = routeData.map { com.pathlume.app.navigation.RouteNode(it.id, Vector3D(it.x, it.y, it.z), it.floorId, it.buildingId, it.type) }

        val detector = OffRouteDetector(2.0f)

        // User on route
        val onRouteUser = Vector3D(2.5f, 0.2f, 0f)
        assertFalse(detector.isOffRoute(onRouteUser, routeNodes))

        // User strays 5 meters away
        val offRouteUser = Vector3D(2.5f, 5.0f, 0f)
        assertTrue(detector.isOffRoute(offRouteUser, routeNodes))
    }

    @Test
    fun arrivalDetector_verifiesDistanceAndFloorMatch() {
        val dest = Destination(
            id = "d1",
            name = "Room 101",
            buildingId = "b1",
            floorId = "floor_0",
            position = Vector3D(10f, 0f, 0f)
        )

        // Same floor, close distance -> Arrived
        assertTrue(ArrivalDetector.hasArrived(Vector3D(10.5f, 0f, 0f), 0, dest, 0))

        // Different floor -> Not arrived
        assertFalse(ArrivalDetector.hasArrived(Vector3D(10.5f, 0f, 0f), 1, dest, 0))
    }

    @Test
    fun poseFusionManager_blendsVpsCorrection() {
        val fusionManager = PoseFusionManager()

        val vpsPose = VPSPose(
            position = Vector3D(10f, 0f, 5f),
            heading = 90f,
            floor = 1,
            accuracy = 0.3f
        )

        fusionManager.applyVPSCorrection(vpsPose)
        val fused = fusionManager.fusedPose.value

        assertEquals(10f, fused.position.x, 0.1f)
        assertEquals(90f, fused.heading, 0.1f)
        assertEquals(FusedPoseStatus.ACTIVE, fused.status)
    }
}
