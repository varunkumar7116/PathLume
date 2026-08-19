package com.pathlume.app.presentation.destinations

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Domain
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.domain.model.Destination
import com.pathlume.app.presentation.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DestinationDetailsScreen(
    destination: Destination,
    onStartNavigation: () -> Unit,
    onBackClicked: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Destination Details", color = TextMain, fontWeight = FontWeight.Bold) },
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(24.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Column {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = CardDark),
                    shape = RoundedCornerShape(20.dp)
                ) {
                    Column(modifier = Modifier.padding(24.dp)) {
                        Text(
                            text = destination.name,
                            style = MaterialTheme.typography.headlineLarge.copy(fontSize = 24.sp),
                            color = TextMain
                        )

                        Spacer(modifier = Modifier.height(6.dp))

                        Text(
                            text = "Category: ${destination.category}",
                            style = MaterialTheme.typography.bodyMedium,
                            color = SkyBlue
                        )

                        Spacer(modifier = Modifier.height(20.dp))

                        Divider(color = BorderDark)

                        Spacer(modifier = Modifier.height(20.dp))

                        // Stats
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceAround
                        ) {
                            DetailItem(icon = Icons.Default.Domain, label = "Floor", value = destination.floorId.replace("floor_", "Floor "))
                            DetailItem(icon = Icons.Default.DirectionsWalk, label = "Est. Walk", value = "2 min")
                            DetailItem(icon = Icons.Default.LocationOn, label = "Distance", value = "45 m")
                        }
                    }
                }
            }

            Button(
                onClick = onStartNavigation,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = SkyBlue)
            ) {
                Text(
                    text = "START NAVIGATION",
                    color = NavyDark,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp
                )
            }
        }
    }
}

@Composable
private fun DetailItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: String
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(imageVector = icon, contentDescription = null, tint = SkyBlue, modifier = Modifier.size(22.dp))
        Spacer(modifier = Modifier.height(6.dp))
        Text(text = value, fontWeight = FontWeight.Bold, fontSize = 15.sp, color = TextMain)
        Text(text = label, fontSize = 12.sp, color = TextSub)
    }
}
