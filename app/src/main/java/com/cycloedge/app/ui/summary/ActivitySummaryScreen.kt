package com.cycloedge.app.ui.summary

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.cycloedge.app.data.local.entities.ActivityEntity
import com.cycloedge.app.ui.cockpit.MetricGridCard
import com.cycloedge.app.ui.theme.*
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun ActivitySummaryScreen(
    activity: ActivityEntity,
    onBackClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val dateFormat = SimpleDateFormat("dd MMMM yyyy, HH:mm", Locale("id", "ID"))

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(PureBlack)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(16.dp)
            .verticalScroll(rememberScrollState())
    ) {
        // Top Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(activity.title, style = CycloTypography.displaySmall, color = PureWhite)
        }

        Text(
            dateFormat.format(Date(activity.startTimeMs)),
            style = CycloTypography.bodyMedium,
            color = TextMuted
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Distance & Time
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            MetricGridCard(
                label = "Total Jarak",
                value = String.format("%.2f", activity.totalDistanceMeters / 1000.0),
                unit = "km",
                valueColor = ElectricGreen,
                valueStyle = CycloTypography.displayLarge,
                modifier = Modifier.weight(1f)
            )
            val movingHours = activity.movingSeconds / 3600
            val movingMins = (activity.movingSeconds % 3600) / 60
            val movingSecs = activity.movingSeconds % 60
            val timeStr = if (movingHours > 0) {
                String.format("%02d:%02d:%02d", movingHours, movingMins, movingSecs)
            } else {
                String.format("%02d:%02d", movingMins, movingSecs)
            }
            MetricGridCard(
                label = "Durasi Bergerak",
                value = timeStr,
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Speed Metrics
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            MetricGridCard(
                label = "Kecepatan Rata-rata",
                value = String.format("%.1f", (activity.avgSpeedMps ?: 0.0) * 3.6),
                unit = "km/h",
                modifier = Modifier.weight(1f)
            )
            MetricGridCard(
                label = "Kecepatan Maksimum",
                value = String.format("%.1f", (activity.maxSpeedMps ?: 0.0) * 3.6),
                unit = "km/h",
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Heart Rate & Power
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            MetricGridCard(
                label = "Detak Jantung Rata-rata",
                value = activity.avgHeartRate?.toString() ?: "--",
                unit = "bpm",
                modifier = Modifier.weight(1f)
            )
            MetricGridCard(
                label = "Normalized Power (NP)",
                value = activity.normalizedPowerWatts?.toString() ?: "--",
                unit = "W",
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Elevation Gain
        MetricGridCard(
            label = "Total Elevasi (Ascent)",
            value = String.format("%.0f", activity.totalAscentMeters),
            unit = "m"
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Share / Export Actions
        Button(
            onClick = {
                activity.fitFilePath?.let { path ->
                    val file = File(path)
                    if (file.exists()) {
                        val uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "application/octet-stream"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        context.startActivity(Intent.createChooser(shareIntent, "Bagikan Berkas FIT"))
                    }
                }
            },
            colors = ButtonDefaults.buttonColors(containerColor = ElectricGreen),
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(10.dp)
        ) {
            Text("BAGIKAN BERKAS .FIT (GARMIN/STRAVA)", color = PureBlack, style = CycloTypography.labelSmall)
        }

        Spacer(modifier = Modifier.height(12.dp))

        OutlinedButton(
            onClick = onBackClick,
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(10.dp)
        ) {
            Text("KEMBALI KE COCKPIT", color = PureWhite, style = CycloTypography.labelSmall)
        }
    }
}

