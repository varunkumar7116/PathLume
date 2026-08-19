package com.pathlume.app.presentation.siteloading

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CompassCalibration
import androidx.compose.material.icons.filled.Domain
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.domain.model.Site
import com.pathlume.app.presentation.theme.*
import kotlinx.coroutines.delay

@Composable
fun SiteLoadingScreen(
    siteId: String,
    onSiteLoaded: (Site) -> Unit,
    onBackClicked: () -> Unit
) {
    var isLoading by remember { mutableStateOf(true) }
    var loadedSite by remember { mutableStateOf<Site?>(null) }
    var loadingStepText by remember { mutableStateOf("Loading site metadata…") }

    LaunchedEffect(key1 = siteId) {
        delay(600)
        loadingStepText = "Loading building graphs & floor plans…"
        delay(600)
        loadingStepText = "Initializing VPS coordinate systems…"
        delay(500)

        // Mock generic site loaded based on siteId
        val mockSite = Site(
            siteId = siteId,
            name = if (siteId == "demo_site") "Demo Universal Campus" else "Site $siteId",
            type = "Universal Site",
            description = "Multi-building indoor navigation site with 3D AR positioning."
        )
        loadedSite = mockSite
        isLoading = false
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(NavyDark)
            .padding(24.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.height(40.dp))

                Icon(
                    imageVector = Icons.Default.CompassCalibration,
                    contentDescription = null,
                    tint = SkyBlue,
                    modifier = Modifier.size(64.dp)
                )

                Spacer(modifier = Modifier.height(16.dp))

                Text(
                    text = "PathLume Site Loading",
                    style = MaterialTheme.typography.headlineMedium,
                    color = TextMain
                )

                Spacer(modifier = Modifier.height(6.dp))

                Surface(
                    color = CardDark,
                    shape = RoundedCornerShape(10.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, BorderDark)
                ) {
                    Text(
                        text = "siteId: $siteId",
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                        color = SkyBlue,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)
                    )
                }

                Spacer(modifier = Modifier.height(36.dp))

                if (isLoading) {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = CardDark)
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            CircularProgressIndicator(
                                color = SkyBlue,
                                strokeWidth = 3.dp,
                                modifier = Modifier.size(48.dp)
                            )
                            Spacer(modifier = Modifier.height(20.dp))
                            Text(
                                text = loadingStepText,
                                style = MaterialTheme.typography.bodyLarge,
                                color = TextMain
                            )
                        }
                    }
                } else if (loadedSite != null) {
                    val site = loadedSite!!
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, AccentGreen.copy(alpha = 0.5f), RoundedCornerShape(16.dp)),
                        colors = CardDefaults.cardColors(containerColor = CardDark)
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(20.dp)
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = "Ready",
                                    tint = AccentGreen,
                                    modifier = Modifier.size(24.dp)
                                )
                                Spacer(modifier = Modifier.width(10.dp))
                                Text(
                                    text = "Site Ready",
                                    style = MaterialTheme.typography.headlineMedium.copy(fontSize = 18.sp),
                                    color = TextMain
                                )
                            }

                            Spacer(modifier = Modifier.height(14.dp))

                            Text(
                                text = site.name,
                                style = MaterialTheme.typography.headlineLarge.copy(fontSize = 22.sp),
                                color = TextMain
                            )
                            Text(
                                text = site.description,
                                style = MaterialTheme.typography.bodyMedium,
                                color = TextSub
                            )

                            Spacer(modifier = Modifier.height(16.dp))

                            Divider(color = BorderDark)

                            Spacer(modifier = Modifier.height(16.dp))

                            // Site Stats Summary
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceAround
                            ) {
                                StatBadge(icon = Icons.Default.Domain, label = "Buildings", value = "2")
                                StatBadge(icon = Icons.Default.LocationOn, label = "VPS Mode", value = "Active")
                                StatBadge(icon = Icons.Default.CompassCalibration, label = "Frame", value = "Site World")
                            }
                        }
                    }
                }
            }

            // Bottom Continue / Back Buttons
            Column(modifier = Modifier.fillMaxWidth()) {
                if (!isLoading && loadedSite != null) {
                    Button(
                        onClick = { onSiteLoaded(loadedSite!!) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = SkyBlue)
                    ) {
                        Text(
                            text = "Start VPS Localization",
                            color = NavyDark,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                }

                OutlinedButton(
                    onClick = onBackClicked,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("Scan Different Site QR", color = TextSub)
                }
            }
        }
    }
}

@Composable
private fun StatBadge(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: String
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(imageVector = icon, contentDescription = null, tint = SkyBlue, modifier = Modifier.size(20.dp))
        Spacer(modifier = Modifier.height(4.dp))
        Text(text = value, fontWeight = FontWeight.Bold, fontSize = 14.sp, color = TextMain)
        Text(text = label, fontSize = 11.sp, color = TextSub)
    }
}
