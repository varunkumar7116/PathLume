package com.pathlume.app

import androidx.annotation.NonNull
import com.pathlume.app.ar.ARCoreManager
import com.pathlume.app.ar.ARViewFactory
import com.pathlume.app.bridge.ARMessageHandler
import com.pathlume.app.bridge.ARMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var arCoreManager: ARCoreManager
    private lateinit var arMethodChannel: ARMethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        arCoreManager = ARCoreManager(this)
        arCoreManager.renderer.displayRotationSupplier = {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                display?.rotation ?: 0
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay.rotation
            }
        }

        // Platform View for AR Camera Feed Surface
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("com.pathlume.app/ar_view", ARViewFactory(arCoreManager))

        // MethodChannel
        arMethodChannel = ARMethodChannel(this, arCoreManager)
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pathlume.app/ar_channel")
        methodChannel.setMethodCallHandler(arMethodChannel)

        // EventChannel for tracking status & 6DoF pose stream
        val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pathlume.app/ar_events")
        eventChannel.setStreamHandler(ARMessageHandler(arCoreManager))
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (::arMethodChannel.isInitialized) {
            arMethodChannel.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun onResume() {
        super.onResume()
        if (::arCoreManager.isInitialized && arCoreManager.isSessionActive) {
            arCoreManager.resumeARCoreSession()
        }
    }

    override fun onPause() {
        super.onPause()
        if (::arCoreManager.isInitialized && arCoreManager.isSessionActive) {
            arCoreManager.pauseARCoreSession()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::arCoreManager.isInitialized) {
            arCoreManager.stopARCoreSession()
        }
    }
}

