package com.pathlume.app.testing

import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.localization.ARCorePose
import com.pathlume.app.localization.FusedPose
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject

data class StationaryTestResult(
    val sampleCount: Int,
    val durationSeconds: Float,
    val meanPosition: Vector3D,
    val stdDevPosition: Vector3D,
    val maxDisplacementMeters: Float
)

data class WalkTestResult(
    val sampleCount: Int,
    val totalPathLengthMeters: Float,
    val totalDisplacementMeters: Float,
    val currentPosition: Vector3D
)

data class TelemetryFrame(
    val timestamp: Long,
    val arcoreX: Float,
    val arcoreY: Float,
    val arcoreZ: Float,
    val yaw: Float,
    val trackingState: String,
    val fusedX: Float,
    val fusedY: Float,
    val fusedZ: Float,
    val distanceToDestination: Float,
    val distanceFromRoute: Float,
    val currentFloor: Int,
    val destinationFloor: Int,
    val navigationState: String
)

class FieldTestLogger {
    private val _isStationaryTestActive = MutableStateFlow(false)
    val isStationaryTestActive: StateFlow<Boolean> = _isStationaryTestActive.asStateFlow()

    private val _stationaryResult = MutableStateFlow<StationaryTestResult?>(null)
    val stationaryResult: StateFlow<StationaryTestResult?> = _stationaryResult.asStateFlow()

    private val _isWalkTestActive = MutableStateFlow(false)
    val isWalkTestActive: StateFlow<Boolean> = _isWalkTestActive.asStateFlow()

    private val _walkResult = MutableStateFlow<WalkTestResult?>(null)
    val walkResult: StateFlow<WalkTestResult?> = _walkResult.asStateFlow()

    private val stationaryPoses = mutableListOf<ARCorePose>()
    private val walkPoses = mutableListOf<ARCorePose>()
    private val telemetryFrames = mutableListOf<TelemetryFrame>()

    private var stationaryStartMs = 0L

    fun startStationaryTest() {
        stationaryPoses.clear()
        stationaryStartMs = System.currentTimeMillis()
        _stationaryResult.value = null
        _isStationaryTestActive.value = true
    }

    fun stopStationaryTest() {
        _isStationaryTestActive.value = false
        if (stationaryPoses.isEmpty()) return

        val count = stationaryPoses.size
        var sumX = 0f; var sumY = 0f; var sumZ = 0f
        for (pose in stationaryPoses) {
            sumX += pose.position.x
            sumY += pose.position.y
            sumZ += pose.position.z
        }
        val meanX = sumX / count
        val meanY = sumY / count
        val meanZ = sumZ / count

        var varX = 0f; var varY = 0f; var varZ = 0f
        var maxDisp = 0f

        val firstPos = stationaryPoses[0].position

        for (pose in stationaryPoses) {
            val dx = pose.position.x - meanX
            val dy = pose.position.y - meanY
            val dz = pose.position.z - meanZ
            varX += dx * dx
            varY += dy * dy
            varZ += dz * dz

            val distFromFirst = Math.sqrt(
                ((pose.position.x - firstPos.x) * (pose.position.x - firstPos.x) +
                 (pose.position.y - firstPos.y) * (pose.position.y - firstPos.y) +
                 (pose.position.z - firstPos.z) * (pose.position.z - firstPos.z)).toDouble()
            ).toFloat()
            if (distFromFirst > maxDisp) maxDisp = distFromFirst
        }

        val stdX = Math.sqrt((varX / count).toDouble()).toFloat()
        val stdY = Math.sqrt((varY / count).toDouble()).toFloat()
        val stdZ = Math.sqrt((varZ / count).toDouble()).toFloat()
        val durationSec = (System.currentTimeMillis() - stationaryStartMs) / 1000f

        _stationaryResult.value = StationaryTestResult(
            sampleCount = count,
            durationSeconds = durationSec,
            meanPosition = Vector3D(meanX, meanY, meanZ),
            stdDevPosition = Vector3D(stdX, stdY, stdZ),
            maxDisplacementMeters = maxDisp
        )
    }

    fun startWalkTest() {
        walkPoses.clear()
        _walkResult.value = null
        _isWalkTestActive.value = true
    }

    fun stopWalkTest() {
        _isWalkTestActive.value = false
    }

    fun recordFrame(
        arPose: ARCorePose?,
        fusedPose: FusedPose,
        trackingState: String,
        distanceToDestination: Float,
        distanceFromRoute: Float,
        destinationFloor: Int,
        navigationState: String
    ) {
        val now = System.currentTimeMillis()
        val arX = arPose?.position?.x ?: 0f
        val arY = arPose?.position?.y ?: 0f
        val arZ = arPose?.position?.z ?: 0f
        val yaw = arPose?.heading ?: 0f

        // Record telemetry frame
        telemetryFrames.add(
            TelemetryFrame(
                timestamp = now,
                arcoreX = arX,
                arcoreY = arY,
                arcoreZ = arZ,
                yaw = yaw,
                trackingState = trackingState,
                fusedX = fusedPose.position.x,
                fusedY = fusedPose.position.y,
                fusedZ = fusedPose.position.z,
                distanceToDestination = distanceToDestination,
                distanceFromRoute = distanceFromRoute,
                currentFloor = fusedPose.floor,
                destinationFloor = destinationFloor,
                navigationState = navigationState
            )
        )

        // Record stationary test frame if active
        if (_isStationaryTestActive.value && arPose != null) {
            stationaryPoses.add(arPose)
            if (now - stationaryStartMs >= 30000L) {
                stopStationaryTest()
            }
        }

        // Record walk test frame if active
        if (_isWalkTestActive.value && arPose != null) {
            walkPoses.add(arPose)
            val count = walkPoses.size
            var pathLen = 0f
            for (i in 0 until count - 1) {
                val p1 = walkPoses[i].position
                val p2 = walkPoses[i + 1].position
                val dx = p2.x - p1.x
                val dy = p2.y - p1.y
                val dz = p2.z - p1.z
                pathLen += Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
            }
            val start = walkPoses[0].position
            val curr = walkPoses.last().position
            val disp = Math.sqrt(
                ((curr.x - start.x) * (curr.x - start.x) +
                 (curr.y - start.y) * (curr.y - start.y) +
                 (curr.z - start.z) * (curr.z - start.z)).toDouble()
            ).toFloat()

            _walkResult.value = WalkTestResult(
                sampleCount = count,
                totalPathLengthMeters = pathLen,
                totalDisplacementMeters = disp,
                currentPosition = curr
            )
        }
    }

    fun exportTelemetryJSON(): String {
        val jsonArr = JSONArray()
        for (f in telemetryFrames) {
            val obj = JSONObject()
            obj.put("timestamp", f.timestamp)
            obj.put("arcore_x", f.arcoreX)
            obj.put("arcore_y", f.arcoreY)
            obj.put("arcore_z", f.arcoreZ)
            obj.put("yaw", f.yaw)
            obj.put("tracking_state", f.trackingState)
            obj.put("fused_x", f.fusedX)
            obj.put("fused_y", f.fusedY)
            obj.put("fused_z", f.fusedZ)
            obj.put("distance_to_destination", f.distanceToDestination)
            obj.put("distance_from_route", f.distanceFromRoute)
            obj.put("current_floor", f.currentFloor)
            obj.put("destination_floor", f.destinationFloor)
            obj.put("navigation_state", f.navigationState)
            jsonArr.put(obj)
        }
        return jsonArr.toString(2)
    }
}
