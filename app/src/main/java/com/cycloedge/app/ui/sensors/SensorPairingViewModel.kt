package com.cycloedge.app.ui.sensors

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cycloedge.app.data.local.CycloDatabase
import com.cycloedge.app.data.local.entities.PairedSensorEntity
import com.cycloedge.app.domain.ble.BleSensorManager
import com.cycloedge.app.domain.model.DiscoveredSensor
import com.cycloedge.app.domain.model.SensorRole
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class SensorPairingViewModel(application: Application) : AndroidViewModel(application) {

    private val context = application.applicationContext
    private val database = CycloDatabase.getInstance(context)
    val bleManager = BleSensorManager(context, viewModelScope)

    val discoveredSensors: StateFlow<List<DiscoveredSensor>> = bleManager.discoveredSensors
    val pairedSensors: StateFlow<List<PairedSensorEntity>> = database.pairedSensorDao()
        .getEnabledSensors()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun startScanning() {
        bleManager.startScanning()
    }

    fun stopScanning() {
        bleManager.stopScanning()
    }

    fun pairSensor(sensor: DiscoveredSensor, role: SensorRole = SensorRole.COMBO) {
        viewModelScope.launch(Dispatchers.IO) {
            val entity = PairedSensorEntity(
                sensorId = sensor.address,
                name = sensor.name,
                sensorType = sensor.type.name,
                role = role.name,
                isEnabled = true,
                lastConnectedAt = System.currentTimeMillis()
            )
            database.pairedSensorDao().insertOrUpdate(entity)
            bleManager.connectSensor(sensor.address, role)
        }
    }

    fun unpairSensor(address: String) {
        viewModelScope.launch(Dispatchers.IO) {
            database.pairedSensorDao().delete(address)
            bleManager.disconnectSensor(address)
        }
    }

    override fun onCleared() {
        super.onCleared()
        bleManager.stopScanning()
    }
}

