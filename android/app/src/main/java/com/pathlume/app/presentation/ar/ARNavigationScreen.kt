package com.pathlume.app.presentation.ar

import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.CompassCalibration
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.pathlume.app.domain.model.Destination
import kotlinx.coroutines.delay

private val NavyDark = Color(0xFF0F172A)
private val CardDark = Color(0xFF1E293B)
private val SkyBlue = Color(0xFF38BDF8)
private val BluePrimary = Color(0xFF0284C7)
private val AccentGreen = Color(0xFF22C55E)
private val TextMain = Color(0xFFF8FAFC)
private val TextSub = Color(0xFF94A3B8)
private val BorderDark = Color(0xFF334155)

data class NavNode2D(
    val id: String,
    val name: String,
    val relX: Float, // -1.0 to 1.0 (screen relative)
    val relY: Float, // 0.0 (top) to 1.0 (bottom)
    val isDestination: Boolean = false,
    val isCurrentPose: Boolean = false
)

@Composable
fun ARNavigationScreen(
    destination: Destination,
    onArrived: () -> Unit,
    onCloseClicked: () -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    var showNodeGraphOverlay by remember { mutableStateOf(true) }
    var vpsConfidence by remember { mutableStateOf(0.96f) }

    // Real-time VPS pose coordinates in site canonical frame (meters)
    var posX by remember { mutableStateOf(0.0f) }
    var posY by remember { mutableStateOf(-1.90f) }
    var posZ by remember { mutableStateOf(1.2f) }
    var headingDegrees by remember { mutableStateOf(345) }

    // Waypoint Nodes along path
    val routeNodes = remember(destination) {
        listOf(
            NavNode2D("N0_start", "User VPS Origin", 0.0f, 0.85f, isCurrentPose = true),
            NavNode2D("N1_lobby", "Main Entrance Corridor", -0.15f, 0.70f),
            NavNode2D("N2_junction", "Central Elevator Junction", 0.10f, 0.55f),
            NavNode2D("N3_hallway", "Corridor Waypoint 3", -0.05f, 0.40f),
            NavNode2D("N4_dest", destination.name, 0.0f, 0.28f, isDestination = true)
        )
    }

    var currentWaypointIndex by remember { mutableStateOf(1) }

    // Real-time VPS pose simulation tick
    LaunchedEffect(Unit) {
        while (true) {
            delay(800)
            headingDegrees = (headingDegrees + (-2..2).random() + 360) % 360
            posZ += 0.3f
            posX += ((-5..5).random() / 100.0f)
            vpsConfidence = (94..99).random() / 100.0f

            if (posZ > 3.5f && currentWaypointIndex < routeNodes.size - 1) {
                currentWaypointIndex++
            }
        }
    }

    val cameraProviderFuture = remember { ProcessCameraProvider.getInstance(context) }

    DisposableEffect(Unit) {
        onDispose {
            try {
                if (cameraProviderFuture.isDone) {
                    cameraProviderFuture.get().unbindAll()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(NavyDark)
    ) {
        // 1. CameraX Live Camera Background
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

        // 2. 3D AR Node Mapping Canvas (Draws Topological Nodes & AR Edges over camera)
        Canvas(modifier = Modifier.fillMaxSize()) {
            val width = size.width
            val height = size.height

            if (showNodeGraphOverlay) {
                // Draw A* Path Edges connecting nodes
                for (i in 0 until routeNodes.size - 1) {
                    val n1 = routeNodes[i]
                    val n2 = routeNodes[i + 1]

                    val p1 = Offset(width / 2 + n1.relX * width * 0.4f, n1.relY * height)
                    val p2 = Offset(width / 2 + n2.relX * width * 0.4f, n2.relY * height)

                    // Draw connecting path line
                    drawLine(
                        color = if (i < currentWaypointIndex) AccentGreen else SkyBlue,
                        start = p1,
                        end = p2,
                        strokeWidth = if (i < currentWaypointIndex) 8.dp.toPx() else 4.dp.toPx()
                    )
                }

                // Draw AR Node Landmarks
                routeNodes.forEachIndexed { idx, node ->
                    val cx = width / 2 + node.relX * width * 0.4f
                    val cy = node.relY * height

                    if (node.isDestination) {
                        // Render Destination Target Marker
                        drawCircle(color = AccentGreen, radius = 22.dp.toPx(), center = Offset(cx, cy))
                        drawCircle(color = NavyDark, radius = 14.dp.toPx(), center = Offset(cx, cy))
                        drawCircle(color = AccentGreen, radius = 8.dp.toPx(), center = Offset(cx, cy))
                    } else if (node.isCurrentPose) {
                        // Render VPS User Pose Origin Marker
                        drawCircle(color = SkyBlue.copy(alpha = 0.4f), radius = 28.dp.toPx(), center = Offset(cx, cy))
                        drawCircle(color = SkyBlue, radius = 12.dp.toPx(), center = Offset(cx, cy))
                    } else {
                        // Render Intermediate Topological Graph Node
                        val isPassed = idx <= currentWaypointIndex
                        drawCircle(
                            color = if (isPassed) AccentGreen else Color.White,
                            radius = 10.dp.toPx(),
                            center = Offset(cx, cy)
                        )
                        drawCircle(
                            color = NavyDark,
                            radius = 6.dp.toPx(),
                            center = Offset(cx, cy)
                        )
                    }
                }
            }
        }

        // 3. Top Header HUD: Active Instruction & Destination
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
                        val nextWaypointText = "Next: ${routeNodes.getOrNull(currentWaypointIndex)?.name ?: "Destination"}"
                        Text(
                            text = nextWaypointText,
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

            // VPS Pose Coordinates Real-Time Telemetry Bar
            Surface(
                color = NavyDark.copy(alpha = 0.85f),
                shape = RoundedCornerShape(12.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, BorderDark)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.CompassCalibration, contentDescription = null, tint = AccentGreen, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        val posString = "VPS: (%.2fm, %.2fm, %.2fm)".format(posX, posY, posZ)
                        Text(
                            text = posString,
                            color = TextMain,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        val headingText = "Heading: ${headingDegrees}°"
                        Text(
                            text = headingText,
                            color = TextSub,
                            fontSize = 12.sp
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Surface(
                            color = if (showNodeGraphOverlay) SkyBlue.copy(alpha = 0.2f) else CardDark,
                            shape = RoundedCornerShape(6.dp),
                            modifier = Modifier.clickable { showNodeGraphOverlay = !showNodeGraphOverlay }
                        ) {
                            val nodeToggleText = if (showNodeGraphOverlay) "Nodes: ON" else "Nodes: OFF"
                            Text(
                                text = nodeToggleText,
                                color = if (showNodeGraphOverlay) SkyBlue else TextSub,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }
                }
            }
        }

        // 4. Bottom Control Panel & Waypoint Node Step Controls
        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Surface(
                color = CardDark.copy(alpha = 0.94f),
                shape = RoundedCornerShape(20.dp),
                shadowElevation = 10.dp,
                border = androidx.compose.foundation.BorderStroke(1.dp, BorderDark)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text(
                                text = "A* Route Navigation",
                                color = TextMain,
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp
                            )
                            val statusStr = "Node ${currentWaypointIndex + 1} of ${routeNodes.size} • ${(vpsConfidence * 100).toInt()}% VPS Confidence"
                            Text(
                                text = statusStr,
                                color = TextSub,
                                fontSize = 12.sp
                            )
                        }

                        Button(
                            onClick = onArrived,
                            colors = ButtonDefaults.buttonColors(containerColor = AccentGreen),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null, tint = NavyDark, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Arrived", color = NavyDark, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        }
                    }
                }
            }
        }
    }
}
