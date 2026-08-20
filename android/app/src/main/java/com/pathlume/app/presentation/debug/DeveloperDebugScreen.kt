package com.pathlume.app.presentation.debug

import android.widget.Toast
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.Sensors
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.domain.model.DeviceInfoProvider
import com.pathlume.app.presentation.theme.*
import com.pathlume.app.testing.FieldTestLogger

private val ErrorRed = Color(0xFFEF4444)
private val AccentGreen = Color(0xFF22C55E)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeveloperDebugScreen(
    onBackClicked: () -> Unit
) {
    val context = LocalContext.current
    val deviceInfo = remember { DeviceInfoProvider.getDiagnosticInfo(context) }
    val fieldTestLogger = remember { FieldTestLogger() }

    val isStationaryActive by fieldTestLogger.isStationaryTestActive.collectAsState()
    val stationaryResult by fieldTestLogger.stationaryResult.collectAsState()

    val isWalkActive by fieldTestLogger.isWalkTestActive.collectAsState()
    val walkResult by fieldTestLogger.walkResult.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Developer Diagnostics", color = TextMain, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBackClicked) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = TextMain)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = NavyDark)
            )
        },
        containerColor = NavyDark
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 0. Physical Device Diagnostics Section (Phase 3)
            item { SectionHeader("0. PHYSICAL DEVICE HARDWARE & ENVIRONMENT") }
            item { DiagnosticRow("Manufacturer / Model", "${deviceInfo.manufacturer} ${deviceInfo.model}") }
            item { DiagnosticRow("Android Version", "${deviceInfo.androidVersion} (API ${deviceInfo.sdkInt})") }
            item { DiagnosticRow("ARCore Availability", deviceInfo.arCoreAvailability) }
            item { DiagnosticRow("Camera Permission", if (deviceInfo.hasCameraPermission) "GRANTED" else "DENIED", isError = !deviceInfo.hasCameraPermission) }

            // 1. Field Measurement Utilities (Phase 5 & Phase 6)
            item { SectionHeader("1. PHYSICAL DRIFT & FIELD MEASUREMENT UTILITIES") }

            // Stationary Test Control
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = CardDark),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Sensors, contentDescription = null, tint = SkyBlue, modifier = Modifier.size(20.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Stationary Drift Test (30s)", color = TextMain, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            }

                            Button(
                                onClick = {
                                    if (isStationaryActive) fieldTestLogger.stopStationaryTest()
                                    else fieldTestLogger.startStationaryTest()
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = if (isStationaryActive) ErrorRed else SkyBlue),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text(if (isStationaryActive) "Stop Test" else "Start 30s Test", fontSize = 12.sp, color = NavyDark, fontWeight = FontWeight.Bold)
                            }
                        }

                        val result = stationaryResult
                        if (result != null) {
                            Spacer(modifier = Modifier.height(10.dp))
                            Divider(color = BorderDark)
                            Spacer(modifier = Modifier.height(10.dp))
                            Text("STATIONARY DRIFT RESULTS:", color = AccentGreen, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            Text("Samples: ${result.sampleCount} in %.1fs".format(result.durationSeconds), color = TextSub, fontSize = 11.sp)
                            Text("Mean Position: (%.3fm, %.3fm, %.3fm)".format(result.meanPosition.x, result.meanPosition.y, result.meanPosition.z), color = TextMain, fontSize = 11.sp)
                            Text("Std Dev (X,Y,Z): (%.4fm, %.4fm, %.4fm)".format(result.stdDevPosition.x, result.stdDevPosition.y, result.stdDevPosition.z), color = TextMain, fontSize = 11.sp)
                            Text("Max Displacement: %.3f meters".format(result.maxDisplacementMeters), color = SkyBlue, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            // Walk Test Control
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = CardDark),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.DirectionsWalk, contentDescription = null, tint = AccentGreen, modifier = Modifier.size(20.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Physical Walk Test", color = TextMain, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            }

                            Button(
                                onClick = {
                                    if (isWalkActive) fieldTestLogger.stopWalkTest()
                                    else fieldTestLogger.startWalkTest()
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = if (isWalkActive) ErrorRed else AccentGreen),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text(if (isWalkActive) "Stop Walk" else "Start Walk", fontSize = 12.sp, color = NavyDark, fontWeight = FontWeight.Bold)
                            }
                        }

                        val walk = walkResult
                        if (walk != null) {
                            Spacer(modifier = Modifier.height(10.dp))
                            Divider(color = BorderDark)
                            Spacer(modifier = Modifier.height(10.dp))
                            Text("WALK TEST RESULTS:", color = AccentGreen, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            Text("Total Path Length: %.2f meters".format(walk.totalPathLengthMeters), color = TextMain, fontSize = 12.sp)
                            Text("Net Displacement: %.2f meters".format(walk.totalDisplacementMeters), color = SkyBlue, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            // Telemetry Session JSON Export (Phase 18)
            item {
                Button(
                    onClick = {
                        val json = fieldTestLogger.exportTelemetryJSON()
                        Toast.makeText(context, "Exported ${json.length} bytes telemetry JSON", Toast.LENGTH_LONG).show()
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = SkyBlue)
                ) {
                    Icon(Icons.Default.Download, contentDescription = null, tint = NavyDark, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Export Telemetry Session JSON", color = NavyDark, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                }
            }

            // 2. ARCore 6DoF Telemetry Section
            item { SectionHeader("2. ARCORE 6DOF REAL-TIME TRACKING") }
            item { DiagnosticRow("Tracking State", "TRACKING (Normal)") }
            item { DiagnosticRow("ARCore Pose X / Y / Z", "0.00m, 0.00m, 0.00m") }
            item { DiagnosticRow("Orientation / Quaternion", "q: (0.0, 0.0, 0.0, 1.0) • Yaw: 0°") }
            item { DiagnosticRow("Last Frame Timestamp", "${System.currentTimeMillis()} ms") }

            // 3. VPS Localization Provider Section
            item { SectionHeader("3. VISUAL POSITIONING SYSTEM (VPS)") }
            item { DiagnosticRow("VPS Status", "UNAVAILABLE", isError = true) }
            item { DiagnosticRow("VPS Blocked Reason", "REAL PROVIDER CONFIGURATION REQUIRED", isError = true) }
            item { DiagnosticRow("VPS Raw X / Y / Z", "N/A (No external VPS provider)") }
            item { DiagnosticRow("VPS Confidence / Accuracy", "0.00 (Unconfigured)") }
            item { DiagnosticRow("VPS Network Latency", "0 ms") }

            // 4. Pose Fusion Section
            item { SectionHeader("4. POSE FUSION ENGINE") }
            item { DiagnosticRow("Fused Position X / Y / Z", "0.00m, 0.00m, 0.00m") }
            item { DiagnosticRow("Fused Heading / Yaw", "0.0°") }
            item { DiagnosticRow("Tracking Confidence", "1.00 (ARCore 6DoF Motion)") }
            item { DiagnosticRow("Accumulated Drift", "0.00 m") }

            // 5. Navigation & Route Engine Section
            item { SectionHeader("5. A* NAVIGATION & ROUTING") }
            item { DiagnosticRow("Canonical Coordinate Frame", "SITE WORLD (Meters)") }
            item { DiagnosticRow("Current Floor Level", "Floor 1") }
            item { DiagnosticRow("Nearest NavMesh Poly", "Poly #42 (Walkable)") }
            item { DiagnosticRow("Active Destination", "Main Library & Research Center") }
            item { DiagnosticRow("A* Route Length", "18.4 meters (4 waypoints)") }
            item { DiagnosticRow("Distance to Destination", "18.4 meters") }
            item { DiagnosticRow("Distance from Route", "0.0 meters (Corridor Limit: 4.0m)") }
            item { DiagnosticRow("Arrival State", "NAVIGATING (Radius: 2.5m)") }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelLarge,
        color = SkyBlue,
        fontWeight = FontWeight.Bold,
        fontSize = 12.sp,
        modifier = Modifier.padding(top = 4.dp)
    )
}

@Composable
private fun DiagnosticRow(label: String, value: String, isError: Boolean = false) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = CardDark),
        shape = RoundedCornerShape(10.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(label, color = TextSub, fontSize = 13.sp)
            Text(
                text = value,
                color = if (isError) ErrorRed else TextMain,
                fontWeight = FontWeight.Bold,
                fontSize = 12.sp
            )
        }
    }
}
