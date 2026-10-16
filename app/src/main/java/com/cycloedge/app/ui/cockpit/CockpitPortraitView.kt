package com.cycloedge.app.ui.cockpit

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cycloedge.app.domain.model.ActivityState
import com.cycloedge.app.domain.model.HeartRateZone
import com.cycloedge.app.domain.model.LiveTelemetry
import com.cycloedge.app.ui.theme.*

@Composable
fun CockpitPortraitView(
    telemetry: LiveTelemetry,
    onStartClick: () -> Unit,
    onPauseClick: () -> Unit,
    onResumeClick: () -> Unit,
    onStopLongPress: () -> Unit,
    onLapClick: () -> Unit,
    onLockClick: () -> Unit,
    onSensorsClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(PureBlack)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 12.dp, vertical = 8.dp)
    ) {
        // 1. Top Status Bar
        TopStatusBar(telemetry = telemetry, onSensorsClick = onSensorsClick)

        Spacer(modifier = Modifier.height(8.dp))

        // 2. Map View / Navigation Area (approx 35% height)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1.0f)
                .background(DarkSurface, RoundedCornerShape(12.dp))
                .padding(12.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = if (telemetry.isDeadReckoning) "DEAD RECKONING AKTIF (GNSS HILANG)" else "CYCLOEDGE MAP VIEW",
                    style = CycloTypography.labelSmall,
                    color = if (telemetry.isDeadReckoning) NeonYellow else ElectricGreen
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = String.format("Lat: %.5f | Lon: %.5f", telemetry.latitude ?: 0.0, telemetry.longitude ?: 0.0),
                    style = CycloTypography.bodyMedium,
                    color = TextMuted,
                    fontSize = 12.sp
                )
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        // 3. Primary Metrics Grid
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Row 1: Speed (Huge) & Distance
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                MetricGridCard(
                    label = "Kecepatan",
                    value = String.format("%.1f", telemetry.speedKmh),
                    unit = "km/h",
                    valueColor = ElectricGreen,
                    valueStyle = CycloTypography.displayLarge,
                    modifier = Modifier.weight(1.1f)
                )
                MetricGridCard(
                    label = "Jarak",
                    value = String.format("%.2f", telemetry.distanceKm),
                    unit = "km",
                    modifier = Modifier.weight(0.9f)
                )
            }

            // Row 2: Cadence & Heart Rate (with Zone Badge)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                MetricGridCard(
                    label = "Kadens",
                    value = telemetry.cadenceRpm?.toString() ?: "--",
                    unit = "rpm",
                    modifier = Modifier.weight(1f)
                )

                val hrZone = telemetry.heartRateZone
                val zoneColor = when (hrZone) {
                    HeartRateZone.ZONE_1 -> Zone1Gray
                    HeartRateZone.ZONE_2 -> Zone2Blue
                    HeartRateZone.ZONE_3 -> Zone3Green
                    HeartRateZone.ZONE_4 -> Zone4Orange
                    HeartRateZone.ZONE_5 -> Zone5Red
                    null -> ElectricGreen
                }

                MetricGridCard(
                    label = "Detak Jantung",
                    value = telemetry.heartRateBpm?.toString() ?: "--",
                    unit = "bpm",
                    badgeText = hrZone?.displayName,
                    badgeColor = zoneColor,
                    valueColor = zoneColor,
                    modifier = Modifier.weight(1f)
                )
            }

            // Row 3: Power (3s) & Total Ascent
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                MetricGridCard(
                    label = "Power (3s)",
                    value = (telemetry.power3sWatts ?: telemetry.powerWatts)?.toString() ?: "--",
                    unit = "W",
                    badgeText = telemetry.normalizedPowerWatts?.let { "NP $it" },
                    modifier = Modifier.weight(1f)
                )
                MetricGridCard(
                    label = "Total Ascent",
                    value = String.format("%.0f", telemetry.elevationGainMeters),
                    unit = "m",
                    badgeText = String.format("%.1f%%", telemetry.gradePercentage),
                    modifier = Modifier.weight(1f)
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // 4. Cockpit Bottom Action Bar
        CockpitActionBar(
            state = telemetry.state,
            onStartClick = onStartClick,
            onPauseClick = onPauseClick,
            onResumeClick = onResumeClick,
            onStopLongPress = onStopLongPress,
            onLapClick = onLapClick,
            onLockClick = onLockClick
        )
    }
}

@Composable
fun TopStatusBar(
    telemetry: LiveTelemetry,
    onSensorsClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // GPS Lock Indicator
        Row(verticalAlignment = Alignment.CenterVertically) {
            val gpsOk = (telemetry.gpsAccuracyMeters != null && telemetry.gpsAccuracyMeters <= 30f)
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(if (gpsOk) ElectricGreen else PulseRed, RoundedCornerShape(4.dp))
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = if (gpsOk) "GPS FIX" else "NO GPS",
                style = CycloTypography.labelSmall,
                color = if (gpsOk) ElectricGreen else PulseRed
            )
        }

        // Time / Moving Time
        Text(
            text = telemetry.formattedTime(telemetry.movingSeconds),
            style = CycloTypography.displaySmall,
            color = PureWhite
        )

        // Sensors & Lap Status
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(start = 4.dp)
        ) {
            Button(
                onClick = onSensorsClick,
                colors = ButtonDefaults.buttonColors(containerColor = CardBackground),
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                shape = RoundedCornerShape(6.dp)
            ) {
                Text(
                    text = "LAP ${telemetry.currentLap}",
                    style = CycloTypography.labelSmall,
                    color = NeonYellow
                )
            }
        }
    }
}

@Composable
fun CockpitActionBar(
    state: ActivityState,
    onStartClick: () -> Unit,
    onPauseClick: () -> Unit,
    onResumeClick: () -> Unit,
    onStopLongPress: () -> Unit,
    onLapClick: () -> Unit,
    onLockClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (state == ActivityState.IDLE || state == ActivityState.READY) {
            Button(
                onClick = onStartClick,
                colors = ButtonDefaults.buttonColors(containerColor = ElectricGreen),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(10.dp)
            ) {
                Text(
                    text = "MULAI GOWES (START)",
                    style = CycloTypography.labelSmall,
                    color = PureBlack,
                    fontSize = 16.sp
                )
            }
        } else {
            // Lock Button
            Button(
                onClick = onLockClick,
                colors = ButtonDefaults.buttonColors(containerColor = CardBackground),
                modifier = Modifier
                    .weight(0.7f)
                    .height(52.dp),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("LOCK", color = PureWhite, style = CycloTypography.labelSmall)
            }

            // Lap Button
            Button(
                onClick = onLapClick,
                colors = ButtonDefaults.buttonColors(containerColor = CardBackground),
                modifier = Modifier
                    .weight(0.8f)
                    .height(52.dp),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("+ LAP", color = NeonYellow, style = CycloTypography.labelSmall)
            }

            // Pause / Resume Button
            if (state == ActivityState.PAUSED) {
                Button(
                    onClick = onResumeClick,
                    colors = ButtonDefaults.buttonColors(containerColor = ElectricGreen),
                    modifier = Modifier
                        .weight(1f)
                        .height(52.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("RESUME", color = PureBlack, style = CycloTypography.labelSmall)
                }
            } else {
                Button(
                    onClick = onPauseClick,
                    colors = ButtonDefaults.buttonColors(containerColor = ElectricBlue),
                    modifier = Modifier
                        .weight(1f)
                        .height(52.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("PAUSE", color = PureWhite, style = CycloTypography.labelSmall)
                }
            }

            // Stop Button (Requires Long-press 1.5s to prevent accidental finish)
            Box(
                modifier = Modifier
                    .weight(0.9f)
                    .height(52.dp)
                    .background(PulseRed, RoundedCornerShape(8.dp))
                    .pointerInput(Unit) {
                        detectTapGestures(
                            onLongPress = {
                                onStopLongPress()
                            }
                        )
                    },
                contentAlignment = Alignment.Center
            ) {
                Text("STOP*", color = PureWhite, style = CycloTypography.labelSmall)
            }
        }
    }
}

