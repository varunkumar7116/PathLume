package com.pathlume.app.presentation.arrival

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.presentation.theme.*

@Composable
fun ArrivalScreen(
    destinationName: String,
    onDoneClicked: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(NavyDark)
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxSize()
        ) {
            Spacer(modifier = Modifier.height(60.dp))

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = AccentGreen,
                    modifier = Modifier.size(88.dp)
                )

                Spacer(modifier = Modifier.height(24.dp))

                Text(
                    text = "You've arrived ✓",
                    style = MaterialTheme.typography.headlineLarge.copy(fontSize = 32.sp),
                    color = TextMain
                )

                Spacer(modifier = Modifier.height(10.dp))

                Text(
                    text = destinationName,
                    style = MaterialTheme.typography.headlineMedium.copy(fontSize = 20.sp),
                    color = SkyBlue
                )

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = "You have successfully reached your destination floor and location.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSub
                )
            }

            Button(
                onClick = onDoneClicked,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = SkyBlue)
            ) {
                Text(
                    text = "Done",
                    color = NavyDark,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp
                )
            }
        }
    }
}
