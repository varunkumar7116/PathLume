package com.pathlume.app.presentation.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CompassCalibration
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.presentation.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onScanQRClicked: () -> Unit,
    onSiteSelected: (String) -> Unit,
    onSettingsClicked: () -> Unit
) {
    var showManualDialog by remember { mutableStateOf(false) }
    var manualSiteIdInput by remember { mutableStateOf("") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.CompassCalibration,
                            contentDescription = null,
                            tint = SkyBlue,
                            modifier = Modifier.size(28.dp)
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            text = "PathLume",
                            fontWeight = FontWeight.Bold,
                            fontSize = 22.sp,
                            color = TextMain
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onSettingsClicked) {
                        Icon(
                            imageVector = Icons.Default.Settings,
                            contentDescription = "Settings",
                            tint = TextSub
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = NavyDark)
            )
        },
        containerColor = NavyDark
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(20.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                // Header Banner
                Text(
                    text = "Indoor Navigation",
                    style = MaterialTheme.typography.headlineMedium,
                    color = TextMain
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "One site, seamless AR guidance across all buildings & floors.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSub
                )

                Spacer(modifier = Modifier.height(28.dp))

                // Primary Hero QR Action Card
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(20.dp))
                        .clickable { onScanQRClicked() },
                    colors = CardDefaults.cardColors(containerColor = CardDark),
                    elevation = CardDefaults.cardElevation(defaultElevation = 6.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Box(
                            modifier = Modifier
                                .size(72.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(BluePrimary.copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.QrCodeScanner,
                                contentDescription = "Scan QR",
                                tint = SkyBlue,
                                modifier = Modifier.size(40.dp)
                            )
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        Text(
                            text = "Scan Site QR",
                            style = MaterialTheme.typography.headlineMedium.copy(fontSize = 20.sp),
                            color = TextMain
                        )

                        Spacer(modifier = Modifier.height(6.dp))

                        Text(
                            text = "Scan the official PathLume site QR at the building entrance to start.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = TextSub
                        )

                        Spacer(modifier = Modifier.height(20.dp))

                        Button(
                            onClick = onScanQRClicked,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = SkyBlue)
                        ) {
                            Text(
                                text = "Open Camera Scanner",
                                color = NavyDark,
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(28.dp))

                // Test / Demo Site Presets Section
                Text(
                    text = "Demo Site Presets",
                    style = MaterialTheme.typography.labelLarge,
                    color = TextSub
                )

                Spacer(modifier = Modifier.height(12.dp))

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .border(1.dp, BorderDark, RoundedCornerShape(14.dp))
                        .clickable { onSiteSelected("sample1") },
                    colors = CardDefaults.cardColors(containerColor = CardDark)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text(
                                text = "Photogrammetry Scan (sample1.glb)",
                                style = MaterialTheme.typography.labelLarge,
                                color = TextMain
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = "siteId: sample1 • 3D GLB Model",
                                style = MaterialTheme.typography.bodyMedium,
                                color = AccentGreen
                            )
                        }

                        Icon(
                            imageVector = Icons.Default.Search,
                            contentDescription = "Load Site",
                            tint = AccentGreen
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .border(1.dp, BorderDark, RoundedCornerShape(14.dp))
                        .clickable { onSiteSelected("demo_site") },
                    colors = CardDefaults.cardColors(containerColor = CardDark)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text(
                                text = "Demo Universal Campus",
                                style = MaterialTheme.typography.labelLarge,
                                color = TextMain
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = "siteId: demo_site",
                                style = MaterialTheme.typography.bodyMedium,
                                color = SkyBlue
                            )
                        }

                        Icon(
                            imageVector = Icons.Default.Search,
                            contentDescription = "Load Site",
                            tint = SkyBlue
                        )
                    }
                }
            }

            // Footer Manual Input Button
            OutlinedButton(
                onClick = { showManualDialog = true },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(12.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, BorderDark)
            ) {
                Text(
                    text = "Enter Site ID Manually",
                    color = TextSub,
                    fontSize = 14.sp
                )
            }
        }
    }

    if (showManualDialog) {
        AlertDialog(
            onDismissRequest = { showManualDialog = false },
            title = { Text("Enter Site ID", color = TextMain) },
            text = {
                Column {
                    Text(
                        "Type a siteId (e.g. demo_site or site_001):",
                        color = TextSub,
                        fontSize = 14.sp
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = manualSiteIdInput,
                        onValueChange = { manualSiteIdInput = it },
                        singleLine = true,
                        placeholder = { Text("demo_site", color = TextSub) },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val input = manualSiteIdInput.trim()
                        if (input.isNotEmpty()) {
                            showManualDialog = false
                            onSiteSelected(input)
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = SkyBlue)
                ) {
                    Text("Load Site", color = NavyDark)
                }
            },
            dismissButton = {
                TextButton(onClick = { showManualDialog = false }) {
                    Text("Cancel", color = TextSub)
                }
            },
            containerColor = CardDark
        )
    }
}
