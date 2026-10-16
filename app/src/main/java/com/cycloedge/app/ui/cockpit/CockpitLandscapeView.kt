package com.cycloedge.app.ui.cockpit

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cycloedge.app.domain.model.HeartRateZone
import com.cycloedge.app.domain.model.LiveTelemetry
import com.cycloedge.app.ui.theme.*

@Composable
fun CockpitLandscapeView(
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
            .padding(8.dp)
    ) {
        // Top Bar
        TopStatusBar(telemetry = telemetry, onSensorsClick = onSensorsClick)

        Spacer(modifier = Modifier.height(6.dp))

        // Side-by-side Layout: Left Map, Right Metric Grid
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Left: Map View (approx 45%)
            Box(
                modifier = Modifier
                    .weight(0.45f)
                    .fillMaxHeight()
                    .background(DarkSurface, RoundedCornerShape(12.dp))
                    .padding(12.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = if (telemetry.isDeadReckoning) "DEAD RECKONING" else "MAP HUD (VECTOR)",
                        style = CycloTypography.labelSmall,
                        color = if (telemetry.isDeadReckoning) NeonYellow else ElectricGreen
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = String.format("Akurasi: %.1fm", telemetry.gpsAccuracyMeters ?: 0f),
                        style = CycloTypography.bodyMedium,
                        color = TextMuted,
                        fontSize = 11.sp
                    )
                }
            }

            // Right: 6-Metric Compact Grid (approx 55%)
            Column(
                modifier = Modifier
                    .weight(0.55f)
                    .fillMaxHeight(),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                // Row 1: Speed & Distance
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    MetricGridCard(
                        label = "Speed",
                        value = String.format("%.1f", telemetry.speedKmh),
                        unit = "km/h",
                        valueColor = ElectricGreen,
                        valueStyle = CycloTypography.displayMedium,
                        modifier = Modifier.weight(1f)
                    )
                    MetricGridCard(
                        label = "Distance",
                        value = String.format("%.2f", telemetry.distanceKm),
                        unit = "km",
                        valueStyle = CycloTypography.displayMedium,
                        modifier = Modifier.weight(1f)
                    )
                }

                // Row 2: Cadence & Heart Rate
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    MetricGridCard(
                        label = "Cadence",
                        value = telemetry.cadenceRpm?.toString() ?: "--",
                        unit = "rpm",
                        valueStyle = CycloTypography.displaySmall,
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
                        label = "Heart Rate",
                        value = telemetry.heartRateBpm?.toString() ?: "--",
                        unit = "bpm",
                        badgeText = hrZone?.displayName,
                        badgeColor = zoneColor,
                        valueColor = zoneColor,
                        valueStyle = CycloTypography.displaySmall,
                        modifier = Modifier.weight(1f)
                    )
                }

                // Row 3: Power & Ascent
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    MetricGridCard(
                        label = "Power 3s",
                        value = (telemetry.power3sWatts ?: telemetry.powerWatts)?.toString() ?: "--",
                        unit = "W",
                        valueStyle = CycloTypography.displaySmall,
                        modifier = Modifier.weight(1f)
                    )
                    MetricGridCard(
                        label = "Ascent",
                        value = String.format("%.0f", telemetry.elevationGainMeters),
                        unit = "m",
                        valueStyle = CycloTypography.displaySmall,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(6.dp))

        // Cockpit Action Bar
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

