package com.cycloedge.app.ui.sensors

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cycloedge.app.domain.model.DiscoveredSensor
import com.cycloedge.app.domain.model.SensorRole
import com.cycloedge.app.domain.model.SensorType
import com.cycloedge.app.ui.theme.*

@Composable
fun SensorPairingScreen(
    viewModel: SensorPairingViewModel,
    onBackClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val discovered by viewModel.discoveredSensors.collectAsState()
    val paired by viewModel.pairedSensors.collectAsState()

    var isScanning by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(PureBlack)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(16.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Button(
                onClick = onBackClick,
                colors = ButtonDefaults.buttonColors(containerColor = CardBackground),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("KEMBALI", color = PureWhite, style = CycloTypography.labelSmall)
            }

            Text("SENSOR BLE", style = CycloTypography.displaySmall, color = PureWhite)

            Button(
                onClick = {
                    if (isScanning) {
                        viewModel.stopScanning()
                        isScanning = false
                    } else {
                        viewModel.startScanning()
                        isScanning = true
                    }
                },
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isScanning) PulseRed else ElectricGreen
                ),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text(
                    text = if (isScanning) "STOP" else "SCAN",
                    color = if (isScanning) PureWhite else PureBlack,
                    style = CycloTypography.labelSmall
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Paired Sensors Section
        Text("SENSOR TERPASANG", style = CycloTypography.labelSmall, color = ElectricGreen)
        Spacer(modifier = Modifier.height(8.dp))

        if (paired.isEmpty()) {
            Text(
                "Belum ada sensor yang dipasangkan.",
                style = CycloTypography.bodyMedium,
                color = TextMuted
            )
        } else {
            for (p in paired) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(CardBackground, RoundedCornerShape(8.dp))
                        .padding(12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(p.name, style = CycloTypography.labelSmall, color = PureWhite)
                        Text("${p.sensorType} (${p.role}) • ${p.sensorId}", fontSize = 11.sp, color = TextMuted)
                    }
                    Button(
                        onClick = { viewModel.unpairSensor(p.sensorId) },
                        colors = ButtonDefaults.buttonColors(containerColor = PulseRed.copy(alpha = 0.2f)),
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Text("LEPAS", color = PulseRed, fontSize = 11.sp)
                    }
                }
                Spacer(modifier = Modifier.height(6.dp))
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Discovered Sensors Section
        Text("SENSOR DITEMUKAN", style = CycloTypography.labelSmall, color = NeonYellow)
        Spacer(modifier = Modifier.height(8.dp))

        LazyColumn(
            modifier = Modifier.fillMaxWidth().weight(1f),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(discovered) { sensor ->
                DiscoveredSensorRow(
                    sensor = sensor,
                    onPair = { role ->
                        viewModel.pairSensor(sensor, role)
                    }
                )
            }
        }
    }
}

@Composable
fun DiscoveredSensorRow(
    sensor: DiscoveredSensor,
    onPair: (SensorRole) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(DarkSurface, RoundedCornerShape(10.dp))
            .padding(12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(sensor.name, style = CycloTypography.labelSmall, color = PureWhite)
            Text(
                "${sensor.type.name} • RSSI: ${sensor.rssi} dBm",
                fontSize = 11.sp,
                color = TextMuted
            )
        }

        if (sensor.type == SensorType.CSC) {
            // Dual CSC choice: Speed Only or Cadence Only
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Button(
                    onClick = { onPair(SensorRole.SPEED_ONLY) },
                    colors = ButtonDefaults.buttonColors(containerColor = ElectricBlue),
                    shape = RoundedCornerShape(6.dp),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Text("RODA", color = PureWhite, fontSize = 10.sp)
                }
                Button(
                    onClick = { onPair(SensorRole.CADENCE_ONLY) },
                    colors = ButtonDefaults.buttonColors(containerColor = NeonYellow),
                    shape = RoundedCornerShape(6.dp),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Text("CRANK", color = PureBlack, fontSize = 10.sp)
                }
            }
        } else {
            Button(
                onClick = { onPair(SensorRole.COMBO) },
                colors = ButtonDefaults.buttonColors(containerColor = ElectricGreen),
                shape = RoundedCornerShape(6.dp)
            ) {
                Text("PASANGKAN", color = PureBlack, fontSize = 11.sp)
            }
        }
    }
}

