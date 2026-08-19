package com.pathlume.app.presentation.destinations

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.domain.model.Destination
import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.presentation.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DestinationSearchScreen(
    siteId: String,
    onDestinationSelected: (Destination) -> Unit,
    onBackClicked: () -> Unit
) {
    var searchQuery by remember { mutableStateOf("") }

    // Dynamic destinations for siteId
    val allDestinations = remember(siteId) {
        listOf(
            Destination("d1", "Main Library & Research Center", "b1", "floor_1", Vector3D(10f, 0f, 5f), "Academic"),
            Destination("d2", "Executive Conference Room 201", "b1", "floor_1", Vector3D(15f, 0f, 12f), "Office"),
            Destination("d3", "Student Reception & Help Desk", "b1", "floor_0", Vector3D(2f, 0f, 2f), "Service"),
            Destination("d4", "Central Cafeteria & Lounge", "b1", "floor_0", Vector3D(-8f, 0f, 6f), "Dining"),
            Destination("d5", "Innovation & Robotics Lab", "b2", "floor_0", Vector3D(-12f, 0f, -10f), "Lab")
        )
    }

    val filteredDestinations = remember(searchQuery) {
        if (searchQuery.isBlank()) allDestinations
        else allDestinations.filter {
            it.name.contains(searchQuery, ignoreCase = true) ||
            it.category.contains(searchQuery, ignoreCase = true)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Where do you want to go?", color = TextMain, fontWeight = FontWeight.Bold, fontSize = 20.sp) },
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
                .padding(horizontal = 20.dp)
        ) {
            Spacer(modifier = Modifier.height(12.dp))

            // Search Bar
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("Search places in $siteId", color = TextSub) },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = SkyBlue) },
                shape = RoundedCornerShape(14.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SkyBlue,
                    unfocusedBorderColor = BorderDark,
                    focusedContainerColor = CardDark,
                    unfocusedContainerColor = CardDark
                )
            )

            Spacer(modifier = Modifier.height(20.dp))

            Text(
                text = "Available Places (${filteredDestinations.size})",
                fontSize = 13.sp,
                color = TextSub,
                fontWeight = FontWeight.SemiBold
            )

            Spacer(modifier = Modifier.height(12.dp))

            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxSize()
            ) {
                items(filteredDestinations) { destination ->
                    DestinationCard(
                        destination = destination,
                        onClick = { onDestinationSelected(destination) }
                    )
                }
            }
        }
    }
}

@Composable
private fun DestinationCard(
    destination: Destination,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, BorderDark, RoundedCornerShape(14.dp))
            .clickable { onClick() },
        colors = CardDefaults.cardColors(containerColor = CardDark)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                Surface(
                    color = BluePrimary.copy(alpha = 0.2f),
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.size(44.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(Icons.Default.LocationOn, contentDescription = null, tint = SkyBlue)
                    }
                }

                Spacer(modifier = Modifier.width(14.dp))

                Column {
                    Text(
                        text = destination.name,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        color = TextMain
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = "${destination.category} • Floor ${destination.floorId.replace("floor_", "")}",
                        fontSize = 13.sp,
                        color = TextSub
                    )
                }
            }

            Text(
                text = "Select",
                color = SkyBlue,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp
            )
        }
    }
}
