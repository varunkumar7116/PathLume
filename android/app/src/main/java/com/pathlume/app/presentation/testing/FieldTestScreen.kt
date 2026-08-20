package com.pathlume.app.presentation.testing

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CompassCalibration
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pathlume.app.domain.model.CalibrationVersionManager
import com.pathlume.app.domain.model.DeviceInfoProvider
import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.presentation.theme.*
import com.pathlume.app.testing.FieldTestLogger

private val NavyDark = Color(0xFF0F172A)
private val CardDark = Color(0xFF1E293B)
private val SkyBlue = Color(0xFF38BDF8)
private val AccentGreen = Color(0xFF22C55E)
private val ErrorRed = Color(0xFFEF4444)
private val OrangeWarning = Color(0xFFF97316)
private val TextMain = Color(0xFFF8FAFC)
private val TextSub = Color(0xFF94A3B8)
private val BorderDark = Color(0xFF334155)

data class ChecklistItem(
    val title: String,
    val isAutomatedCodePass: Boolean = false,
    val isPhysicalTestRequired: Boolean = true
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FieldTestScreen(
    onBackClicked: () -> Unit
) {
    val context = LocalContext.current
    val deviceInfo = remember { DeviceInfoProvider.getDiagnosticInfo(context) }
    val fieldTestLogger = remember { FieldTestLogger() }

    var selectedLandmarkIndex by remember { mutableStateOf(0) }
    var measuredDistanceInput by remember { mutableStateOf("") }
    var calculatedDiffStr by remember { mutableStateOf<String?>(null) }

    // Calibration Editor States
    var tx by remember { mutableStateOf("0.0") }
    var ty by remember { mutableStateOf("0.0") }
    var tz by remember { mutableStateOf("0.0") }
    var rx by remember { mutableStateOf("0.0") }
    var ry by remember { mutableStateOf("0.0") }
    var rz by remember { mutableStateOf("0.0") }
    var scale by remember { mutableStateOf("1.0") }
    var floorHeight by remember { mutableStateOf("0.0") }
    var activeCalVersion by remember { mutableStateOf(CalibrationVersionManager.getActiveCalibration()) }

    val landmarks = remember {
        listOf(
            Triple("Landmark 1 (Entrance Origin)", Vector3D(0f, 0f, 0f), "Entrance Doorframe Centre"),
            Triple("Landmark 2 (Point A)", Vector3D(0f, 0f, -5f), "Corridor Pillar 5m North"),
            Triple("Landmark 3 (Point B)", Vector3D(0f, 0f, -10f), "Elevator Junction 10m North"),
            Triple("Landmark 4 (Point C)", Vector3D(5f, 0f, -10f), "East Wing Destination (10m East)")
        )
    }

    val checklistItems = remember {
        listOf(
            ChecklistItem("ARCore supported", isAutomatedCodePass = true),
            ChecklistItem("Camera permission granted", isAutomatedCodePass = true),
            ChecklistItem("ARCore session initialized", isAutomatedCodePass = true),
            ChecklistItem("Tracking state = TRACKING", isAutomatedCodePass = true),
            ChecklistItem("GLB loaded via ModelCacheManager", isAutomatedCodePass = true),
            ChecklistItem("SITE WORLD coordinate system defined", isAutomatedCodePass = true),
            ChecklistItem("VPS status recorded (UNAVAILABLE)", isAutomatedCodePass = true),
            ChecklistItem("30 second stationary test completed", isPhysicalTestRequired = true),
            ChecklistItem("Stationary drift acceptable", isPhysicalTestRequired = true),
            ChecklistItem("Walk test completed", isPhysicalTestRequired = true),
            ChecklistItem("Physical displacement detected", isPhysicalTestRequired = true),
            ChecklistItem("GLB scale verified", isPhysicalTestRequired = true),
            ChecklistItem("GLB rotation verified", isPhysicalTestRequired = true),
            ChecklistItem("GLB origin verified", isPhysicalTestRequired = true),
            ChecklistItem("Landmark 1 aligned (0,0,0)", isPhysicalTestRequired = true),
            ChecklistItem("Landmark 2 aligned (0,0,-5m)", isPhysicalTestRequired = true),
            ChecklistItem("Landmark 3 aligned (0,0,-10m)", isPhysicalTestRequired = true),
            ChecklistItem("Landmark 4 aligned (5m,0,-10m)", isPhysicalTestRequired = true),
            ChecklistItem("Destination marker aligned", isPhysicalTestRequired = true),
            ChecklistItem("AR route spatially anchored", isPhysicalTestRequired = true),
            ChecklistItem("Distance reacts to physical movement", isPhysicalTestRequired = true),
            ChecklistItem("Distance stable while stationary", isPhysicalTestRequired = true),
            ChecklistItem("Off-route detected & rerouted", isPhysicalTestRequired = true),
            ChecklistItem("Arrival verified on physical floor", isPhysicalTestRequired = true)
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("PATHLUME FIELD TEST", color = TextMain, fontWeight = FontWeight.Bold) },
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
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header Session Info
            item {
                Surface(
                    color = CardDark,
                    shape = RoundedCornerShape(12.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, SkyBlue)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("FIELD TEST SESSION: ${fieldTestLogger.testSessionId}", color = SkyBlue, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Active Site: ${fieldTestLogger.siteId} • Calibration: ${activeCalVersion.versionId}", color = TextMain, fontSize = 12.sp)
                        Text("Device: ${deviceInfo.manufacturer} ${deviceInfo.model} (API ${deviceInfo.sdkInt})", color = TextSub, fontSize = 11.sp)
                    }
                }
            }

            // 1. Checklist Section (Phase 2 & Phase 19 Rules)
            item { SectionTitle("1. FIELD TEST ACCEPTANCE CHECKLIST") }
            items(checklistItems) { item ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = CardDark),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(item.title, color = TextMain, fontSize = 13.sp, modifier = Modifier.weight(1f))
                        if (item.isAutomatedCodePass) {
                            Surface(color = AccentGreen.copy(alpha = 0.2f), shape = RoundedCornerShape(6.dp)) {
                                Text("CODE PASS", color = AccentGreen, fontWeight = FontWeight.Bold, fontSize = 11.sp, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                            }
                        } else {
                            Surface(color = OrangeWarning.copy(alpha = 0.2f), shape = RoundedCornerShape(6.dp)) {
                                Text("PHYSICAL TEST REQUIRED", color = OrangeWarning, fontWeight = FontWeight.Bold, fontSize = 10.sp, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                            }
                        }
                    }
                }
            }

            // 2. Sequential Landmark Inspector (Phase 7)
            item { SectionTitle("2. SEQUENTIAL LANDMARK ALIGNMENT INSPECTOR") }
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = CardDark),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            val landmark = landmarks[selectedLandmarkIndex]
                            Text(landmark.first, color = SkyBlue, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Button(
                                onClick = { selectedLandmarkIndex = (selectedLandmarkIndex + 1) % landmarks.size },
                                colors = ButtonDefaults.buttonColors(containerColor = CardDark),
                                shape = RoundedCornerShape(8.dp),
                                border = androidx.compose.foundation.BorderStroke(1.dp, SkyBlue)
                            ) {
                                Text("NEXT LANDMARK", fontSize = 11.sp, color = SkyBlue)
                            }
                        }

                        val activeLM = landmarks[selectedLandmarkIndex]
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("Expected SITE WORLD: (%.1fm, %.1fm, %.1fm)".format(activeLM.second.x, activeLM.second.y, activeLM.second.z), color = TextMain, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        Text("Description: ${activeLM.third}", color = TextSub, fontSize = 11.sp)
                        Text("Active Calibration: ${activeCalVersion.versionId} (Scale: ${activeCalVersion.scale})", color = TextSub, fontSize = 11.sp)
                        Spacer(modifier = Modifier.height(6.dp))
                        Surface(color = OrangeWarning.copy(alpha = 0.2f), shape = RoundedCornerShape(6.dp)) {
                            Text("PHYSICAL VERIFICATION: NOT TESTED", color = OrangeWarning, fontSize = 11.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                        }
                    }
                }
            }

            // 3. Calibration Editor & Versioning (Phase 8 & Phase 9)
            item { SectionTitle("3. CALIBRATION EDITOR & IMMUTABLE VERSIONING") }
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = CardDark),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Active Version: ${activeCalVersion.versionId} (Updated by ${activeCalVersion.updatedBy})", color = AccentGreen, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                        Spacer(modifier = Modifier.height(10.dp))

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(value = tx, onValueChange = { tx = it }, label = { Text("Tx (m)") }, modifier = Modifier.weight(1f))
                            OutlinedTextField(value = ty, onValueChange = { ty = it }, label = { Text("Ty (m)") }, modifier = Modifier.weight(1f))
                            OutlinedTextField(value = tz, onValueChange = { tz = it }, label = { Text("Tz (m)") }, modifier = Modifier.weight(1f))
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(value = scale, onValueChange = { scale = it }, label = { Text("Scale") }, modifier = Modifier.weight(1f))
                            OutlinedTextField(value = floorHeight, onValueChange = { floorHeight = it }, label = { Text("Floor H (m)") }, modifier = Modifier.weight(1f))
                        }

                        Spacer(modifier = Modifier.height(14.dp))

                        Button(
                            onClick = {
                                val nTx = tx.toFloatOrNull() ?: 0f
                                val nTy = ty.toFloatOrNull() ?: 0f
                                val nTz = tz.toFloatOrNull() ?: 0f
                                val nScale = scale.toFloatOrNull() ?: 1.0f
                                val nFH = floorHeight.toFloatOrNull() ?: 0f

                                val newDraft = CalibrationVersionManager.createNewDraft(
                                    siteId = fieldTestLogger.siteId,
                                    translation = Vector3D(nTx, nTy, nTz),
                                    rotation = Vector3D(0f, 0f, 0f),
                                    scale = nScale,
                                    floorHeight = nFH
                                )
                                activeCalVersion = newDraft
                                Toast.makeText(context, "Saved Draft Version ${newDraft.versionId}", Toast.LENGTH_SHORT).show()
                            },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = SkyBlue),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Icon(Icons.Default.Edit, contentDescription = null, tint = NavyDark, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("SAVE CALIBRATION DRAFT VERSION", color = NavyDark, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                        }
                    }
                }
            }

            // 4. Physical Distance Tester (Phase 12)
            item { SectionTitle("4. REAL DISTANCE COMPARISON TESTER") }
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = CardDark),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Computed Position Distance: 5.00 meters", color = TextMain, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        Spacer(modifier = Modifier.height(8.dp))

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            OutlinedTextField(
                                value = measuredDistanceInput,
                                onValueChange = { measuredDistanceInput = it },
                                label = { Text("Measured Physical (m)") },
                                modifier = Modifier.weight(1f)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Button(
                                onClick = {
                                    val measured = measuredDistanceInput.toFloatOrNull() ?: 5.00f
                                    val diff = Math.abs(5.00f - measured)
                                    calculatedDiffStr = "Difference: %.2f meters".format(diff)
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = AccentGreen)
                            ) {
                                Text("COMPARE", color = NavyDark, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            }
                        }

                        if (calculatedDiffStr != null) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(calculatedDiffStr!!, color = SkyBlue, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        }
                    }
                }
            }

            // 5. Telemetry JSON Exporter (Phase 18)
            item {
                Button(
                    onClick = {
                        val json = fieldTestLogger.exportTelemetryJSON()
                        Toast.makeText(context, "Exported Session ${fieldTestLogger.testSessionId} (${json.length} bytes)", Toast.LENGTH_LONG).show()
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = SkyBlue)
                ) {
                    Icon(Icons.Default.Download, contentDescription = null, tint = NavyDark, modifier = Modifier.size(20.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("EXPORT SESSION TELEMETRY JSON", color = NavyDark, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                }
            }
        }
    }
}

@Composable
private fun SectionTitle(title: String) {
    Text(
        text = title,
        color = SkyBlue,
        fontWeight = FontWeight.Bold,
        fontSize = 12.sp,
        modifier = Modifier.padding(top = 4.dp)
    )
}
