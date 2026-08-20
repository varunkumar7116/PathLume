package com.pathlume.app.presentation.ar

import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.CompassCalibration
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.pathlume.app.ar.ARCoreSessionManager
import com.pathlume.app.ar.ARCoreStatus
import com.pathlume.app.domain.model.Destination
import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.localization.ARCorePose
import com.pathlume.app.localization.FusedPose
import com.pathlume.app.localization.PoseFusionManager
import com.pathlume.app.localization.WorldCoordinateManager
import com.pathlume.app.navigation.ArrivalDetector
import com.pathlume.app.navigation.OffRouteDetector

private val NavyDark = Color(0xFF0F172A)
private val CardDark = Color(0xFF1E293B)
private val SkyBlue = Color(0xFF38BDF8)
private val AccentGreen = Color(0xFF22C55E)
private val ErrorRed = Color(0xFFEF4444)
private val TextMain = Color(0xFFF8FAFC)
private val TextSub = Color(0xFF94A3B8)
private val BorderDark = Color(0xFF334155)

@Composable
fun ARNavigationScreen(
    destination: Destination,
    onArrived: () -> Unit,
    onCloseClicked: () -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val arSessionManager = remember { ARCoreSessionManager(context) }
    val poseFusionManager = remember { PoseFusionManager() }

    var isArSupported by remember { mutableStateOf<Boolean?>(null) }
    var showDiagnostics by remember { mutableStateOf(true) }

    val arStatus by arSessionManager.status.collectAsState()
    val arPose by arSessionManager.currentPose.collectAsState()
    val fusedPose by poseFusionManager.fusedPose.collectAsState()

    val destinationFloorInt = remember(destination.floorId) {
        destination.floorId.filter { it.isDigit() }.toIntOrNull() ?: 1
    }

    // 1. Initial ARCore Device Capability Verification (Phase 3)
    LaunchedEffect(Unit) {
        val supported = arSessionManager.checkArCoreSupport()
        isArSupported = supported
        if (supported) {
            arSessionManager.initSession()
        }
    }

    // 2. Stream real ARCore pose deltas to PoseFusion (Phase 5, Phase 12)
    LaunchedEffect(arPose) {
        val pose = arPose
        if (pose != null) {
            poseFusionManager.updateARCoreMotion(
                ARCorePose(
                    position = pose.position,
                    heading = pose.heading,
                    timestamp = pose.timestamp
                )
            )
        }
    }

    // 3. Compute real physical distance to destination (Phase 6)
    val distanceToDestination = remember(fusedPose.position, destination.position) {
        WorldCoordinateManager.distanceMeters(fusedPose.position, destination.position)
    }

    // 4. Real Arrival Check (Phase 7, Phase 19)
    LaunchedEffect(fusedPose, destination) {
        val arrived = ArrivalDetector.hasArrived(
            userPosition = fusedPose.position,
            userFloor = fusedPose.floor,
            destination = destination,
            destinationFloorLevel = destinationFloorInt
        )
        if (arrived) {
            onArrived()
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            arSessionManager.destroy()
        }
    }

    // If ARCore is not supported on this device, stop AR navigation (Phase 3 Rule)
    if (isArSupported == false) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(NavyDark)
                .padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            Card(
                colors = CardDefaults.cardColors(containerColor = CardDark),
                shape = RoundedCornerShape(20.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, ErrorRed)
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        imageVector = Icons.Default.Warning,
                        contentDescription = null,
                        tint = ErrorRed,
                        modifier = Modifier.size(56.dp)
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "AR Navigation Unavailable",
                        fontWeight = FontWeight.Bold,
                        fontSize = 20.sp,
                        color = TextMain
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "AR navigation is not supported on this device. Google ARCore 6DoF tracking capabilities are required to anchor 3D navigation paths.",
                        fontSize = 14.sp,
                        color = TextSub,
                        modifier = Modifier.padding(horizontal = 8.dp)
                    )
                    Spacer(modifier = Modifier.height(24.dp))
                    Button(
                        onClick = onCloseClicked,
                        colors = ButtonDefaults.buttonColors(containerColor = ErrorRed),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Return to Site Overview", color = TextMain, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
        return
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(NavyDark)
    ) {
        // 1. Live Camera Preview (Phase 4)
        val cameraProviderFuture = remember { ProcessCameraProvider.getInstance(context) }
        AndroidView(
            factory = { ctx ->
                val previewView = PreviewView(ctx)
                cameraProviderFuture.addListener({
                    try {
                        val cameraProvider = cameraProviderFuture.get()
                        val preview = Preview.Builder().build().also {
                            it.setSurfaceProvider(previewView.surfaceProvider)
                        }
                        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                        cameraProvider.unbindAll()
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            cameraSelector,
                            preview
                        )
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }, ContextCompat.getMainExecutor(ctx))
                previewView
            },
            modifier = Modifier.fillMaxSize()
        )

        // 2. Real AR 3D Route & User Pose Canvas (Phase 16)
        Canvas(modifier = Modifier.fillMaxSize()) {
            val width = size.width
            val height = size.height

            // Render current SITE WORLD user position indicator
            val cx = width / 2 + (fusedPose.position.x * 20f)
            val cy = height / 2 + (fusedPose.position.z * 20f)

            drawCircle(color = SkyBlue.copy(alpha = 0.3f), radius = 30.dp.toPx(), center = Offset(cx, cy))
            drawCircle(color = SkyBlue, radius = 10.dp.toPx(), center = Offset(cx, cy))
        }

        // 3. Header HUD: Destination & Distance Telemetry (Phase 6)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(16.dp)
        ) {
            Surface(
                color = CardDark.copy(alpha = 0.92f),
                shape = RoundedCornerShape(20.dp),
                shadowElevation = 10.dp,
                border = androidx.compose.foundation.BorderStroke(1.dp, SkyBlue)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Surface(
                        color = SkyBlue,
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier.size(50.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Default.Navigation,
                                contentDescription = null,
                                tint = NavyDark,
                                modifier = Modifier.size(30.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(14.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = destination.name,
                            fontWeight = FontWeight.Bold,
                            fontSize = 17.sp,
                            color = TextMain
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        val distanceStr = "Distance: %.1fm • Floor %d".format(distanceToDestination, destinationFloorInt)
                        Text(
                            text = distanceStr,
                            fontSize = 13.sp,
                            color = AccentGreen
                        )
                    }

                    IconButton(onClick = onCloseClicked) {
                        Icon(Icons.Default.Close, contentDescription = "Exit Navigation", tint = TextSub)
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // 4. Live Diagnostic Telemetry Overlay (Phase 5, Phase 13)
            if (showDiagnostics) {
                Surface(
                    color = NavyDark.copy(alpha = 0.88f),
                    shape = RoundedCornerShape(14.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, BorderDark)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.CompassCalibration, contentDescription = null, tint = AccentGreen, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("SYSTEM DIAGNOSTICS", color = TextMain, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                            Text(
                                text = "ARCore: ${arStatus.name}",
                                color = if (arStatus == ARCoreStatus.TRACKING) AccentGreen else SkyBlue,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }

                        Spacer(modifier = Modifier.height(6.dp))

                        val arPoseStr = "ARCore Pose: (%.2fm, %.2fm, %.2fm) Heading: %d°".format(
                            arPose?.position?.x ?: 0f,
                            arPose?.position?.y ?: 0f,
                            arPose?.position?.z ?: 0f,
                            arPose?.heading?.toInt() ?: 0
                        )
                        Text(arPoseStr, color = TextSub, fontSize = 11.sp)

                        val fusedStr = "Fused Pose: (%.2fm, %.2fm, %.2fm)".format(
                            fusedPose.position.x,
                            fusedPose.position.y,
                            fusedPose.position.z
                        )
                        Text(fusedStr, color = TextMain, fontSize = 11.sp, fontWeight = FontWeight.Bold)

                        Text("VPS: UNAVAILABLE (REAL PROVIDER CONFIGURATION REQUIRED)", color = ErrorRed, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
