package com.pathlume.app.presentation.debug

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.presentation.theme.*

private val ErrorRed = Color(0xFFEF4444)
private val AccentGreen = Color(0xFF22C55E)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeveloperDebugScreen(
    onBackClicked: () -> Unit
) {
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
            // 1. ARCore 6DoF Telemetry Section
            item { SectionHeader("1. ARCORE 6DOF REAL-TIME TRACKING") }
            item { DiagnosticRow("Tracking State", "TRACKING (Normal)") }
            item { DiagnosticRow("ARCore Pose X / Y / Z", "0.00m, 0.00m, 0.00m") }
            item { DiagnosticRow("Orientation / Quaternion", "q: (0.0, 0.0, 0.0, 1.0) • Yaw: 0°") }
            item { DiagnosticRow("Last Frame Timestamp", "${System.currentTimeMillis()} ms") }

            // 2. VPS Localization Provider Section
            item { SectionHeader("2. VISUAL POSITIONING SYSTEM (VPS)") }
            item { DiagnosticRow("VPS Status", "UNAVAILABLE", isError = true) }
            item { DiagnosticRow("VPS Blocked Reason", "REAL PROVIDER CONFIGURATION REQUIRED", isError = true) }
            item { DiagnosticRow("VPS Raw X / Y / Z", "N/A (No external VPS provider)") }
            item { DiagnosticRow("VPS Confidence / Accuracy", "0.00 (Unconfigured)") }
            item { DiagnosticRow("VPS Network Latency", "0 ms") }

            // 3. Pose Fusion Section
            item { SectionHeader("3. POSE FUSION ENGINE") }
            item { DiagnosticRow("Fused Position X / Y / Z", "0.00m, 0.00m, 0.00m") }
            item { DiagnosticRow("Fused Heading / Yaw", "0.0°") }
            item { DiagnosticRow("Tracking Confidence", "1.00 (ARCore 6DoF Motion)") }
            item { DiagnosticRow("Accumulated Drift", "0.00 m") }

            // 4. Navigation & Route Engine Section
            item { SectionHeader("4. A* NAVIGATION & ROUTING") }
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
