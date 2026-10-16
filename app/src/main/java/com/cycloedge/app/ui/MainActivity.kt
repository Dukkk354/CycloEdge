package com.cycloedge.app.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.runtime.*
import androidx.core.content.ContextCompat
import com.cycloedge.app.ui.cockpit.CockpitScreen
import com.cycloedge.app.ui.cockpit.CockpitViewModel
import com.cycloedge.app.ui.sensors.SensorPairingScreen
import com.cycloedge.app.ui.sensors.SensorPairingViewModel
import com.cycloedge.app.ui.theme.CycloEdgeTheme

class MainActivity : ComponentActivity() {

    private val cockpitViewModel: CockpitViewModel by viewModels()
    private val sensorPairingViewModel: SensorPairingViewModel by viewModels()

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { _ ->
        // Permissions handled
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Keep screen on during ride
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Request required runtime permissions
        requestRequiredPermissions()

        setContent {
            CycloEdgeTheme {
                var currentScreen by remember { mutableStateOf("cockpit") }

                when (currentScreen) {
                    "cockpit" -> {
                        CockpitScreen(
                            viewModel = cockpitViewModel,
                            onNavigateToSensors = { currentScreen = "sensors" }
                        )
                    }
                    "sensors" -> {
                        SensorPairingScreen(
                            viewModel = sensorPairingViewModel,
                            onBackClick = { currentScreen = "cockpit" }
                        )
                    }
                }
            }
        }
    }

    private fun requestRequiredPermissions() {
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        val neededPermissions = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (neededPermissions.isNotEmpty()) {
            permissionLauncher.launch(neededPermissions.toTypedArray())
        }
    }
}

