package com.pathlume.app.presentation.debug

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.presentation.theme.*

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
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Text("System Diagnostics & Telemetry", style = MaterialTheme.typography.labelLarge, color = TextSub)
            }

            item { DiagnosticRow("Active Site ID", "demo_site") }
            item { DiagnosticRow("Building / Floor", "building_main / Floor 0") }
            item { DiagnosticRow("Fused Position (X, Y, Z)", "10.0, 0.0, 5.0") }
            item { DiagnosticRow("Fused Heading", "90.0°") }
            item { DiagnosticRow("ARCore Tracking State", "TRACKING (Normal)") }
            item { DiagnosticRow("VPS State Machine", "VPS_LOCALIZED") }
            item { DiagnosticRow("VPS Latency", "120 ms") }
            item { DiagnosticRow("VPS Accuracy", "0.35 meters") }
            item { DiagnosticRow("Accumulated Drift", "0.12 meters") }
            item { DiagnosticRow("A* Route Status", "ACTIVE (4 nodes)") }
            item { DiagnosticRow("Off-Route Distance", "0.20 meters (Threshold: 2.0m)") }
            item { DiagnosticRow("Coordinate Frame", "Canonical SITE WORLD (Meters)") }
        }
    }
}

@Composable
private fun DiagnosticRow(label: String, value: String) {
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
            Text(value, color = SkyBlue, fontWeight = FontWeight.Bold, fontSize = 13.sp)
        }
    }
}
