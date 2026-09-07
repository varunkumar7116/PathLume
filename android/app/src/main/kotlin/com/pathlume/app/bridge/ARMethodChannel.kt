package com.pathlume.app.bridge

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.pathlume.app.ar.ARCoreManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class ARMethodChannel(
    private val activity: Activity,
    private val arCoreManager: ARCoreManager
) : MethodChannel.MethodCallHandler, PluginRegistry.RequestPermissionsResultListener {

    companion object {
        const val CAMERA_PERMISSION_REQUEST_CODE = 1001
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == CAMERA_PERMISSION_REQUEST_CODE) {
            val isGranted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(isGranted)
            pendingResult = null
            return true
        }
        return false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkARAvailability" -> {
                result.success(arCoreManager.checkARAvailability())
            }
            "checkCameraPermission" -> {
                val hasPermission = ContextCompat.checkSelfPermission(
                    activity,
                    Manifest.permission.CAMERA
                ) == PackageManager.PERMISSION_GRANTED
                result.success(hasPermission)
            }
            "requestCameraPermission" -> {
                if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA)
                    == PackageManager.PERMISSION_GRANTED
                ) {
                    result.success(true)
                } else {
                    pendingResult = result
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.CAMERA),
                        CAMERA_PERMISSION_REQUEST_CODE
                    )
                }
            }
            "startARSession" -> {
                result.success(arCoreManager.startARCoreSession())
            }
            "pauseARSession" -> {
                arCoreManager.pauseARCoreSession()
                result.success(true)
            }
            "stopARSession" -> {
                arCoreManager.stopARCoreSession()
                result.success(true)
            }
            "placeTestMarker" -> {
                result.success(arCoreManager.placeTestMarker())
            }
            "addNodeAnchor" -> {
                val x = (call.argument<Number>("x"))?.toFloat() ?: 0f
                val y = (call.argument<Number>("y"))?.toFloat() ?: 0f
                val z = (call.argument<Number>("z"))?.toFloat() ?: 0f
                android.util.Log.d("PATHLUME_ARChannel", "[PATHLUME][ADD_NODE] Native anchor request received for ($x, $y, $z)")
                result.success(arCoreManager.addNodeAnchor(x, y, z))
            }
            "clearNodeAnchors" -> {
                arCoreManager.resetSession()
                result.success(true)
            }
            "resetARSession" -> {
                arCoreManager.resetSession()
                result.success(true)
            }
            "startLocalization" -> {
                val success = arCoreManager.startARCoreSession()
                result.success(success)
            }
            "stopLocalization" -> {
                arCoreManager.stopARCoreSession()
                result.success(true)
            }
            "requestQRPose" -> {
                result.success(arCoreManager.requestQRPose())
            }
            "getTrackingState" -> {
                result.success(arCoreManager.getTrackingState())
            }
            "updateNavigationRoute" -> {
                val pointsList = call.argument<List<Map<String, Number>>>("points") ?: emptyList()
                val destMap = call.argument<Map<String, Number>>("destination")

                val floatPoints = pointsList.map { p ->
                    floatArrayOf(
                        (p["x"]?.toFloat() ?: 0f),
                        (p["y"]?.toFloat() ?: 0f),
                        (p["z"]?.toFloat() ?: 0f)
                    )
                }

                val destFloat = if (destMap != null) {
                    floatArrayOf(
                        (destMap["x"]?.toFloat() ?: 0f),
                        (destMap["y"]?.toFloat() ?: 0f),
                        (destMap["z"]?.toFloat() ?: 0f)
                    )
                } else null

                arCoreManager.setNavigationRoute(floatPoints, destFloat)
                result.success(true)
            }
            "clearNavigationRoute" -> {
                arCoreManager.clearNavigationRoute()
                result.success(true)
            }
            "getCameraDiagnostics" -> {
                result.success(arCoreManager.getCameraDiagnostics())
            }
            else -> result.notImplemented()
        }
    }
}
