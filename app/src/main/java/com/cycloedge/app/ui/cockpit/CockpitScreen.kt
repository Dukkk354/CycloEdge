package com.cycloedge.app.ui.cockpit

import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import com.cycloedge.app.data.local.entities.ActivityEntity
import com.cycloedge.app.ui.theme.*

@Composable
fun CockpitScreen(
    viewModel: CockpitViewModel,
    onNavigateToSensors: () -> Unit,
    modifier: Modifier = Modifier
) {
    val telemetry by viewModel.telemetry.collectAsState()
    val isScreenLocked by viewModel.isScreenLocked.collectAsState()
    val recoverableActivity by viewModel.recoverableActivity.collectAsState()

    var showStopConfirmationDialog by remember { mutableStateOf(false) }

    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    Box(modifier = modifier.fillMaxSize().background(PureBlack)) {
        if (isLandscape) {
            CockpitLandscapeView(
                telemetry = telemetry,
                onStartClick = { viewModel.startRide() },
                onPauseClick = { viewModel.pauseRide() },
                onResumeClick = { viewModel.resumeRide() },
                onStopLongPress = { showStopConfirmationDialog = true },
                onLapClick = { viewModel.triggerLap() },
                onLockClick = { viewModel.toggleScreenLock() },
                onSensorsClick = onNavigateToSensors
            )
        } else {
            CockpitPortraitView(
                telemetry = telemetry,
                onStartClick = { viewModel.startRide() },
                onPauseClick = { viewModel.pauseRide() },
                onResumeClick = { viewModel.resumeRide() },
                onStopLongPress = { showStopConfirmationDialog = true },
                onLapClick = { viewModel.triggerLap() },
                onLockClick = { viewModel.toggleScreenLock() },
                onSensorsClick = onNavigateToSensors
            )
        }

        // Rain & Sweat Lock Overlay
        RainLockOverlay(
            isLocked = isScreenLocked,
            onUnlockRequested = { viewModel.unlockScreen() }
        )

        // Stop Ride Confirmation Dialog
        if (showStopConfirmationDialog) {
            AlertDialog(
                onDismissRequest = { showStopConfirmationDialog = false },
                title = { Text("Selesaikan Gowes?", color = PureWhite) },
                text = { Text("Aktivitas akan dihentikan dan berkas FIT akan diekspor.", color = TextMuted) },
                confirmButton = {
                    Button(
                        onClick = {
                            showStopConfirmationDialog = false
                            viewModel.stopRide()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = PulseRed)
                    ) {
                        Text("YA, SELESAI", color = PureWhite)
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showStopConfirmationDialog = false }) {
                        Text("BATAL", color = TextMuted)
                    }
                },
                containerColor = CardBackground,
                shape = RoundedCornerShape(12.dp)
            )
        }

        // Crash Recovery Dialog (if previous session crashed)
        recoverableActivity?.let { activity ->
            CrashRecoveryDialog(
                activity = activity,
                onSave = { viewModel.saveRecoverableActivity(activity) },
                onDiscard = { viewModel.discardRecoverableActivity(activity.id) }
            )
        }
    }
}

@Composable
fun CrashRecoveryDialog(
    activity: ActivityEntity,
    onSave: () -> Unit,
    onDiscard: () -> Unit
) {
    AlertDialog(
        onDismissRequest = { /* Force explicit user choice */ },
        title = { Text("Pemulihan Aktivitas", color = NeonYellow) },
        text = {
            Text(
                "Ditemukan sesi gowes sebelumnya (${activity.title}) yang terhenti mendadak akibat baterai habis atau sistem. " +
                        "Data jarak: ${String.format("%.2f", activity.totalDistanceMeters / 1000.0)} km.",
                color = PureWhite
            )
        },
        confirmButton = {
            Button(
                onClick = onSave,
                colors = ButtonDefaults.buttonColors(containerColor = ElectricGreen)
            ) {
                Text("SIMPAN FILE FIT", color = PureBlack)
            }
        },
        dismissButton = {
            TextButton(onClick = onDiscard) {
                Text("BUANG", color = PulseRed)
            }
        },
        containerColor = CardBackground,
        shape = RoundedCornerShape(12.dp)
    )
}

