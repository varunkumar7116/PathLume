package com.pathlume.app.presentation.localization

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CompassCalibration
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.presentation.theme.*
import com.pathlume.app.vps.VPSStatus
import kotlinx.coroutines.delay

@Composable
fun LocalizationScreen(
    siteId: String,
    onLocalized: () -> Unit,
    onBackClicked: () -> Unit
) {
    var vpsStatus by remember { mutableStateOf(VPSStatus.SEARCHING) }
    var statusMessage by remember { mutableStateOf("Communicating with VPS server...") }

    LaunchedEffect(key1 = siteId) {
        vpsStatus = VPSStatus.SEARCHING
        delay(1200)
        vpsStatus = VPSStatus.LOCALIZED
        statusMessage = "Absolute pose identified in Site World frame ✓"
        delay(1000)
        onLocalized()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(NavyDark)
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.Default.CompassCalibration,
                contentDescription = null,
                tint = SkyBlue,
                modifier = Modifier.size(72.dp)
            )

            Spacer(modifier = Modifier.height(20.dp))

            Text(
                text = "VPS Localization",
                style = MaterialTheme.typography.headlineMedium,
                color = TextMain
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "Identifying absolute user coordinates for $siteId",
                style = MaterialTheme.typography.bodyMedium,
                color = TextSub
            )

            Spacer(modifier = Modifier.height(32.dp))

            Surface(
                color = CardDark,
                shape = RoundedCornerShape(16.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, BorderDark)
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    if (vpsStatus == VPSStatus.SEARCHING) {
                        CircularProgressIndicator(color = SkyBlue, strokeWidth = 3.dp)
                    } else if (vpsStatus == VPSStatus.LOCALIZED) {
                        Icon(
                            imageVector = Icons.Default.LocationOn,
                            contentDescription = null,
                            tint = AccentGreen,
                            modifier = Modifier.size(36.dp)
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Default.Warning,
                            contentDescription = null,
                            tint = Color(0xFFF59E0B),
                            modifier = Modifier.size(36.dp)
                        )
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    Text(
                        text = vpsStatus.name,
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp,
                        color = if (vpsStatus == VPSStatus.LOCALIZED) AccentGreen else SkyBlue
                    )

                    Spacer(modifier = Modifier.height(6.dp))

                    Text(
                        text = statusMessage,
                        fontSize = 13.sp,
                        color = TextSub
                    )
                }
            }
        }
    }
}
