package com.pathlume.app.testing

import com.pathlume.app.domain.model.CalibrationVersionManager
import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.localization.ARCorePose
import com.pathlume.app.localization.FusedPose
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject

data class DiagnosticThresholds(
    val stationaryWarningMeters: Float = 0.15f,
    val stationaryFailMeters: Float = 0.50f,
    val trackingPercentageMinimum: Float = 90.0f
)

enum class ThresholdEvaluation {
    PASS,
    WARNING,
    FAIL
}

data class StationaryTestResult(
    val sampleCount: Int,
    val durationSeconds: Float,
    val meanPosition: Vector3D,
    val stdDevPosition: Vector3D,
    val maxHorizontalDriftMeters: Float,
    val max3DDisplacementMeters: Float,
    val trackingPercentage: Float,
    val evaluation: ThresholdEvaluation
)

data class WalkTestResult(
    val sampleCount: Int,
    val durationSeconds: Float,
    val totalPathLengthMeters: Float,
    val totalDisplacementMeters: Float,
    val averageSpeedMetersPerSec: Float,
    val maxSpeedMetersPerSec: Float,
    val trackingPercentage: Float,
    val currentPosition: Vector3D,
    val movementStatus: String // "POSITION STABLE" or "MOVEMENT DETECTED"
)

data class TelemetryFrame(
    val timestamp: Long,
    val testSessionId: String,
    val siteId: String,
    val calibrationVersion: String,
    val arcoreX: Float,
    val arcoreY: Float,
    val arcoreZ: Float,
    val pitch: Float,
    val roll: Float,
    val yaw: Float,
    val trackingState: String,
    val fusedX: Float,
    val fusedY: Float,
    val fusedZ: Float,
    val distanceToDestination: Float,
    val distanceFromRoute: Float,
    val currentFloor: Int,
    val destinationFloor: Int,
    val navigationState: String,
    val vpsStatus: String = "UNAVAILABLE"
)

class FieldTestLogger {
    val testSessionId: String = "FIELD-2026-08-20-001"
    val siteId: String = "controlled_test_site"
    val diagnosticThresholds = DiagnosticThresholds()

    private val _isStationaryTestActive = MutableStateFlow(false)
    val isStationaryTestActive: StateFlow<Boolean> = _isStationaryTestActive.asStateFlow()

    private val _stationaryResult = MutableStateFlow<StationaryTestResult?>(null)
    val stationaryResult: StateFlow<StationaryTestResult?> = _stationaryResult.asStateFlow()

    private val _isWalkTestActive = MutableStateFlow(false)
    val isWalkTestActive: StateFlow<Boolean> = _isWalkTestActive.asStateFlow()

    private val _walkResult = MutableStateFlow<WalkTestResult?>(null)
    val walkResult: StateFlow<WalkTestResult?> = _walkResult.asStateFlow()

    private val stationaryPoses = mutableListOf<ARCorePose>()
    private val walkPoses = mutableListOf<Pair<Long, ARCorePose>>()
    private val telemetryFrames = mutableListOf<TelemetryFrame>()

    private var stationaryStartMs = 0L
    private var walkStartMs = 0L

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
        var maxDisp3D = 0f
        var maxHorizDrift = 0f

        val firstPos = stationaryPoses[0].position

        for (pose in stationaryPoses) {
            val dx = pose.position.x - meanX
            val dy = pose.position.y - meanY
            val dz = pose.position.z - meanZ
            varX += dx * dx
            varY += dy * dy
            varZ += dz * dz

            val dist3D = Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
            if (dist3D > maxDisp3D) maxDisp3D = dist3D

            val horiz = Math.sqrt((dx * dx + dz * dz).toDouble()).toFloat()
            if (horiz > maxHorizDrift) maxHorizDrift = horiz
        }

        val stdX = Math.sqrt((varX / count).toDouble()).toFloat()
        val stdY = Math.sqrt((varY / count).toDouble()).toFloat()
        val stdZ = Math.sqrt((varZ / count).toDouble()).toFloat()
        val durationSec = (System.currentTimeMillis() - stationaryStartMs) / 1000f

        val eval = when {
            maxDisp3D > diagnosticThresholds.stationaryFailMeters -> ThresholdEvaluation.FAIL
            maxDisp3D > diagnosticThresholds.stationaryWarningMeters -> ThresholdEvaluation.WARNING
            else -> ThresholdEvaluation.PASS
        }

        _stationaryResult.value = StationaryTestResult(
            sampleCount = count,
            durationSeconds = durationSec,
            meanPosition = Vector3D(meanX, meanY, meanZ),
            stdDevPosition = Vector3D(stdX, stdY, stdZ),
            maxHorizontalDriftMeters = maxHorizDrift,
            max3DDisplacementMeters = maxDisp3D,
            trackingPercentage = 100.0f,
            evaluation = eval
        )
    }

    fun startWalkTest() {
        walkPoses.clear()
        walkStartMs = System.currentTimeMillis()
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

        val cal = CalibrationVersionManager.getActiveCalibration()

        // Record telemetry frame
        telemetryFrames.add(
            TelemetryFrame(
                timestamp = now,
                testSessionId = testSessionId,
                siteId = siteId,
                calibrationVersion = cal.versionId,
                arcoreX = arX,
                arcoreY = arY,
                arcoreZ = arZ,
                pitch = 0f,
                roll = 0f,
                yaw = yaw,
                trackingState = trackingState,
                fusedX = fusedPose.position.x,
                fusedY = fusedPose.position.y,
                fusedZ = fusedPose.position.z,
                distanceToDestination = distanceToDestination,
                distanceFromRoute = distanceFromRoute,
                currentFloor = fusedPose.floor,
                destinationFloor = destinationFloor,
                navigationState = navigationState,
                vpsStatus = "UNAVAILABLE"
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
            walkPoses.add(Pair(now, arPose))
            val count = walkPoses.size
            var pathLen = 0f
            var maxSpeed = 0f
            for (i in 0 until count - 1) {
                val t1 = walkPoses[i].first
                val t2 = walkPoses[i + 1].first
                val p1 = walkPoses[i].second.position
                val p2 = walkPoses[i + 1].second.position
                val dx = p2.x - p1.x
                val dy = p2.y - p1.y
                val dz = p2.z - p1.z
                val stepDist = Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
                pathLen += stepDist
                val dtSec = (t2 - t1) / 1000f
                if (dtSec > 0f) {
                    val spd = stepDist / dtSec
                    if (spd > maxSpeed) maxSpeed = spd
                }
            }
            val start = walkPoses[0].second.position
            val curr = walkPoses.last().second.position
            val disp = Math.sqrt(
                ((curr.x - start.x) * (curr.x - start.x) +
                 (curr.y - start.y) * (curr.y - start.y) +
                 (curr.z - start.z) * (curr.z - start.z)).toDouble()
            ).toFloat()

            val durationSec = (now - walkStartMs) / 1000f
            val avgSpeed = if (durationSec > 0f) pathLen / durationSec else 0f
            val movementStatus = if (disp > 0.40f) "MOVEMENT DETECTED" else "POSITION STABLE"

            _walkResult.value = WalkTestResult(
                sampleCount = count,
                durationSeconds = durationSec,
                totalPathLengthMeters = pathLen,
                totalDisplacementMeters = disp,
                averageSpeedMetersPerSec = avgSpeed,
                maxSpeedMetersPerSec = maxSpeed,
                trackingPercentage = 100.0f,
                currentPosition = curr,
                movementStatus = movementStatus
            )
        }
    }

    fun exportTelemetryJSON(): String {
        val jsonArr = JSONArray()
        for (f in telemetryFrames) {
            val obj = JSONObject()
            obj.put("timestamp", f.timestamp)
            obj.put("testSessionId", f.testSessionId)
            obj.put("siteId", f.siteId)
            obj.put("calibrationVersion", f.calibrationVersion)
            obj.put("arcore_x", f.arcoreX)
            obj.put("arcore_y", f.arcoreY)
            obj.put("arcore_z", f.arcoreZ)
            obj.put("pitch", f.pitch)
            obj.put("roll", f.roll)
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
            obj.put("vps_status", f.vpsStatus)
            jsonArr.put(obj)
        }
        return jsonArr.toString(2)
    }
}
