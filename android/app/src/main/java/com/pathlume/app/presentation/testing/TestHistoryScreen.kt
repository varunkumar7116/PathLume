package com.pathlume.app.presentation.testing

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Assessment
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.History
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.presentation.theme.*
import com.pathlume.app.testing.FieldTestSessionRecord
import com.pathlume.app.testing.PhysicalTestStatus
import com.pathlume.app.testing.TestHistoryManager
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val NavyDark = Color(0xFF0F172A)
private val CardDark = Color(0xFF1E293B)
private val SkyBlue = Color(0xFF38BDF8)
private val AccentGreen = Color(0xFF22C55E)
private val ErrorRed = Color(0xFFEF4444)
private val OrangeWarning = Color(0xFFF97316)
private val TextMain = Color(0xFFF8FAFC)
private val TextSub = Color(0xFF94A3B8)
private val BorderDark = Color(0xFF334155)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TestHistoryScreen(
    onBackClicked: () -> Unit
) {
    val context = LocalContext.current
    val sessions = remember { TestHistoryManager.getAllSessions() }
    var selectedSession by remember { mutableStateOf<FieldTestSessionRecord?>(null) }

    val dateFormat = remember { SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Field Test History & Reports", color = TextMain, fontWeight = FontWeight.Bold) },
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
                .padding(20.dp)
        ) {
            Text(
                text = "Previous Test Sessions (${sessions.size})",
                style = MaterialTheme.typography.labelLarge,
                color = TextSub
            )

            Spacer(modifier = Modifier.height(14.dp))

            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxSize()
            ) {
                items(sessions) { session ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, BorderDark, RoundedCornerShape(14.dp))
                            .clickable { selectedSession = session },
                        colors = CardDefaults.cardColors(containerColor = CardDark)
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = session.testSessionId,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 15.sp,
                                    color = SkyBlue
                                )
                                StatusBadge(status = session.physicalStatus)
                            }

                            Spacer(modifier = Modifier.height(6.dp))

                            Text(
                                text = "Date: ${dateFormat.format(Date(session.timestampMs))}",
                                fontSize = 12.sp,
                                color = TextSub
                            )
                            Text(
                                text = "Device: ${session.deviceModel}",
                                fontSize = 12.sp,
                                color = TextMain
                            )
                            Text(
                                text = "Site: ${session.siteId} • Calibration: ${session.calibrationVersion}",
                                fontSize = 12.sp,
                                color = TextSub
                            )

                            if (session.testerNotes.isNotEmpty()) {
                                Spacer(modifier = Modifier.height(6.dp))
                                Text(
                                    text = "Notes: ${session.testerNotes}",
                                    fontSize = 11.sp,
                                    color = AccentGreen,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // Inspect Session Dialog
    if (selectedSession != null) {
        val s = selectedSession!!
        AlertDialog(
            onDismissRequest = { selectedSession = null },
            title = { Text("Session ${s.testSessionId}", color = TextMain, fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    Text("Device: ${s.deviceModel}", color = TextSub, fontSize = 13.sp)
                    Text("Site ID: ${s.siteId}", color = TextSub, fontSize = 13.sp)
                    Text("Calibration Version: ${s.calibrationVersion}", color = TextSub, fontSize = 13.sp)
                    Text("Failure Classification: ${s.failureType.name}", color = ErrorRed, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Text("Telemetry Frames: ${s.telemetryFrameCount}", color = TextSub, fontSize = 13.sp)
                    Spacer(modifier = Modifier.height(10.dp))
                    Text("Notes: ${s.testerNotes}", color = TextMain, fontSize = 12.sp)
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val reportJson = TestHistoryManager.generateStructuredReportJSON(s)
                        Toast.makeText(context, "Exported JSON Report (${reportJson.length} bytes)", Toast.LENGTH_LONG).show()
                        selectedSession = null
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = SkyBlue)
                ) {
                    Icon(Icons.Default.Download, contentDescription = null, tint = NavyDark, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Export Report JSON", color = NavyDark, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { selectedSession = null }) {
                    Text("Close", color = TextSub)
                }
            },
            containerColor = CardDark
        )
    }
}

@Composable
private fun StatusBadge(status: PhysicalTestStatus) {
    val color = when (status) {
        PhysicalTestStatus.CODE_VERIFIED -> SkyBlue
        PhysicalTestStatus.PHYSICAL_TEST_PASSED -> AccentGreen
        PhysicalTestStatus.PHYSICAL_TEST_FAILED -> ErrorRed
        PhysicalTestStatus.NOT_TESTED -> OrangeWarning
        PhysicalTestStatus.BLOCKED -> ErrorRed
    }
    Surface(color = color.copy(alpha = 0.2f), shape = RoundedCornerShape(6.dp)) {
        Text(
            text = status.name,
            color = color,
            fontWeight = FontWeight.Bold,
            fontSize = 10.sp,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
        )
    }
}
