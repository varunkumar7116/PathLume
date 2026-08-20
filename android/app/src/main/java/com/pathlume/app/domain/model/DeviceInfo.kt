package com.pathlume.app.domain.model

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.ar.core.ArCoreApk

data class DeviceDiagnosticInfo(
    val manufacturer: String,
    val model: String,
    val androidVersion: String,
    val sdkInt: Int,
    val arCoreAvailability: String,
    val hasCameraPermission: Boolean
)

object DeviceInfoProvider {
    fun getDiagnosticInfo(context: Context): DeviceDiagnosticInfo {
        val availability = ArCoreApk.getInstance().checkAvailability(context)
        val hasCameraPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        return DeviceDiagnosticInfo(
            manufacturer = Build.MANUFACTURER ?: "Unknown",
            model = Build.MODEL ?: "Unknown",
            androidVersion = Build.VERSION.RELEASE ?: "Unknown",
            sdkInt = Build.VERSION.SDK_INT,
            arCoreAvailability = availability.name,
            hasCameraPermission = hasCameraPermission
        )
    }
}
