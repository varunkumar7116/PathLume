package com.pathlume.app.presentation.ar

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.CompassCalibration
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.domain.model.Destination
import com.pathlume.app.presentation.theme.*
import kotlinx.coroutines.delay

@Composable
fun ARNavigationScreen(
    destination: Destination,
    onArrived: () -> Unit,
    onCloseClicked: () -> Unit
) {
    var distanceRemaining by remember { mutableStateOf(45f) }
    var currentInstruction by remember { mutableStateOf("Continue straight towards Main Corridor") }
    var isOffRoute by remember { mutableStateOf(false) }

    LaunchedEffect(key1 = true) {
        while (distanceRemaining > 0) {
            delay(1500)
            distanceRemaining = Math.max(0f, distanceRemaining - 5f)

            if (distanceRemaining == 20f) {
                currentInstruction = "Turn left at Conference Room 201"
            } else if (distanceRemaining <= 5f) {
                onArrived()
                break
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(NavyDark)
    ) {
        // Camera View Simulation Box
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        )

        // Top Navigation Instruction Header Banner
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(16.dp)
        ) {
            Surface(
                color = CardDark.copy(alpha = 0.95f),
                shape = RoundedCornerShape(18.dp),
                shadowElevation = 8.dp,
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
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.size(48.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Default.Navigation,
                                contentDescription = null,
                                tint = NavyDark,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(16.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = currentInstruction,
                            fontWeight = FontWeight.Bold,
                            fontSize = 17.sp,
                            color = TextMain
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = "${destination.name} • ${distanceRemaining.toInt()} m remaining",
                            fontSize = 13.sp,
                            color = TextSub
                        )
                    }

                    IconButton(onClick = onCloseClicked) {
                        Icon(Icons.Default.Close, contentDescription = "Exit", tint = TextSub)
                    }
                }
            }

            AnimatedVisibility(visible = isOffRoute) {
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = Color(0xFFF59E0B),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.Center
                    ) {
                        Icon(Icons.Default.Refresh, contentDescription = null, tint = NavyDark)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Updating route from current position...", color = NavyDark, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        // Bottom Navigation Bar with Distance & Arrive trigger
        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Surface(
                color = CardDark.copy(alpha = 0.9f),
                shape = RoundedCornerShape(16.dp),
                shadowElevation = 8.dp
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.CompassCalibration, contentDescription = null, tint = AccentGreen)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Fused Pose: Active", color = TextMain, fontSize = 13.sp)
                    }

                    Button(
                        onClick = onArrived,
                        colors = ButtonDefaults.buttonColors(containerColor = AccentGreen)
                    ) {
                        Text("Simulate Arrival", color = NavyDark, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
