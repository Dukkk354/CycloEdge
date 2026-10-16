package com.cycloedge.app.thermal

import android.content.Context
import android.os.Build
import android.os.PowerManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class ThermalGuardManager(private val context: Context) {

    sealed class ThermalAction(val targetFps: Int) {
        data object Normal : ThermalAction(targetFps = 60)
        data object ThrottleStage1 : ThermalAction(targetFps = 30) // Reduce map framerate
        data object ThrottleStage2 : ThermalAction(targetFps = 15) // Reduce map framerate & disable 3D terrain
        data object EmergencyOledMode : ThermalAction(targetFps = 10) // Black monochrome screen
    }

    private val _currentAction = MutableStateFlow<ThermalAction>(ThermalAction.Normal)
    val currentAction: StateFlow<ThermalAction> = _currentAction.asStateFlow()

    fun startMonitoring() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            powerManager.addThermalStatusListener { status ->
                val action = when (status) {
                    PowerManager.THERMAL_STATUS_NONE,
                    PowerManager.THERMAL_STATUS_LIGHT -> ThermalAction.Normal
                    PowerManager.THERMAL_STATUS_MODERATE -> ThermalAction.ThrottleStage1
                    PowerManager.THERMAL_STATUS_SEVERE -> ThermalAction.ThrottleStage2
                    PowerManager.THERMAL_STATUS_CRITICAL,
                    PowerManager.THERMAL_STATUS_EMERGENCY,
                    PowerManager.THERMAL_STATUS_SHUTDOWN -> ThermalAction.EmergencyOledMode
                    else -> ThermalAction.Normal
                }
                _currentAction.value = action
            }
        }
    }
}

