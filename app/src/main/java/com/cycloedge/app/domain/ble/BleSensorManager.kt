package com.cycloedge.app.domain.ble

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import android.os.ParcelUuid
import android.util.Log
import com.cycloedge.app.domain.model.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.concurrent.ConcurrentHashMap

@SuppressLint("MissingPermission")
class BleSensorManager(
    private val context: Context,
    private val scope: CoroutineScope
) {
    companion object {
        private const val TAG = "BleSensorManager"
    }

    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        manager?.adapter
    }

    private val bluetoothLeScanner: BluetoothLeScanner?
        get() = bluetoothAdapter?.bluetoothLeScanner

    // Parsers
    private val speedCadenceParsers = ConcurrentHashMap<String, CyclingSpeedCadenceParser>()
    private val powerParser = CyclingPowerParser()

    // Connected GATT instances
    private val activeGatts = ConcurrentHashMap<String, BluetoothGatt>()

    // Configured roles: Address -> SensorRole
    private val sensorRoles = ConcurrentHashMap<String, SensorRole>()

    // Output Telemetry Flows
    private val _latestHeartRate = MutableStateFlow<HeartRateSample?>(null)
    val latestHeartRate: StateFlow<HeartRateSample?> = _latestHeartRate.asStateFlow()

    private val _latestSpeedMps = MutableStateFlow<Double?>(null)
    val latestSpeedMps: StateFlow<Double?> = _latestSpeedMps.asStateFlow()

    private val _latestCadenceRpm = MutableStateFlow<Int?>(null)
    val latestCadenceRpm: StateFlow<Int?> = _latestCadenceRpm.asStateFlow()

    private val _latestPower = MutableStateFlow<CyclingPowerSample?>(null)
    val latestPower: StateFlow<CyclingPowerSample?> = _latestPower.asStateFlow()

    private val _batteryLevels = MutableStateFlow<Map<String, Int>>(emptyMap())
    val batteryLevels: StateFlow<Map<String, Int>> = _batteryLevels.asStateFlow()

    private val _discoveredSensors = MutableStateFlow<List<DiscoveredSensor>>(emptyList())
    val discoveredSensors: StateFlow<List<DiscoveredSensor>> = _discoveredSensors.asStateFlow()

    private var isScanning = false

    fun startScanning() {
        val scanner = bluetoothLeScanner ?: return
        if (isScanning) return

        _discoveredSensors.value = emptyList()
        val filters = listOf(
            ScanFilter.Builder().setServiceUuid(ParcelUuid(BleGattUuids.HEART_RATE_SERVICE)).build(),
            ScanFilter.Builder().setServiceUuid(ParcelUuid(BleGattUuids.CYCLING_SPEED_AND_CADENCE_SERVICE)).build(),
            ScanFilter.Builder().setServiceUuid(ParcelUuid(BleGattUuids.CYCLING_POWER_SERVICE)).build()
        )
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        try {
            scanner.startScan(filters, settings, scanCallback)
            isScanning = true
            Log.d(TAG, "Started BLE Scan with filters")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting BLE scan", e)
        }
    }

    fun stopScanning() {
        val scanner = bluetoothLeScanner ?: return
        if (!isScanning) return
        try {
            scanner.stopScan(scanCallback)
            isScanning = false
            Log.d(TAG, "Stopped BLE Scan")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping BLE scan", e)
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            result?.device?.let { device ->
                val name = device.name ?: "Unknown Sensor"
                val address = device.address

                val serviceUuids = result.scanRecord?.serviceUuids ?: emptyList()
                val type = when {
                    serviceUuids.contains(ParcelUuid(BleGattUuids.HEART_RATE_SERVICE)) -> SensorType.HEART_RATE
                    serviceUuids.contains(ParcelUuid(BleGattUuids.CYCLING_SPEED_AND_CADENCE_SERVICE)) -> SensorType.CSC
                    serviceUuids.contains(ParcelUuid(BleGattUuids.CYCLING_POWER_SERVICE)) -> SensorType.POWER
                    else -> return
                }

                val current = _discoveredSensors.value.toMutableList()
                if (current.none { it.address == address }) {
                    current.add(DiscoveredSensor(address, name, type, result.rssi))
                    _discoveredSensors.value = current
                }
            }
        }
    }

    fun connectSensor(address: String, role: SensorRole = SensorRole.COMBO) {
        sensorRoles[address] = role
        val device = bluetoothAdapter?.getRemoteDevice(address) ?: return

        Log.d(TAG, "Connecting to sensor: $address with role $role")
        // Use autoConnect = false for immediate direct connection
        val gatt = device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        activeGatts[address] = gatt
    }

    fun disconnectSensor(address: String) {
        activeGatts[address]?.let { gatt ->
            gatt.disconnect()
            gatt.close()
            activeGatts.remove(address)
            Log.d(TAG, "Disconnected and closed GATT for $address")
        }
    }

    fun disconnectAll() {
        activeGatts.values.forEach { gatt ->
            try {
                gatt.disconnect()
                gatt.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing gatt", e)
            }
        }
        activeGatts.clear()
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val address = gatt.device.address
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.d(TAG, "Connected to $address. Requesting high priority connection...")
                gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
                gatt.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.w(TAG, "Disconnected from $address. Scheduling reconnect...")
                activeGatts.remove(address)
                gatt.close()
                // Schedule exponential backoff reconnect if active
                scheduleReconnect(address)
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) return

            for (service in gatt.services) {
                when (service.uuid) {
                    BleGattUuids.HEART_RATE_SERVICE -> {
                        enableNotification(gatt, service.getCharacteristic(BleGattUuids.HEART_RATE_MEASUREMENT))
                    }
                    BleGattUuids.CYCLING_SPEED_AND_CADENCE_SERVICE -> {
                        enableNotification(gatt, service.getCharacteristic(BleGattUuids.CSC_MEASUREMENT))
                    }
                    BleGattUuids.CYCLING_POWER_SERVICE -> {
                        enableNotification(gatt, service.getCharacteristic(BleGattUuids.CYCLING_POWER_MEASUREMENT))
                    }
                    BleGattUuids.BATTERY_SERVICE -> {
                        // Read battery level characteristic
                        service.getCharacteristic(BleGattUuids.BATTERY_LEVEL)?.let { char ->
                            gatt.readCharacteristic(char)
                        }
                    }
                }
            }
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            handleCharacteristicUpdate(gatt.device.address, characteristic.uuid, characteristic.value)
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS && characteristic.uuid == BleGattUuids.BATTERY_LEVEL) {
                val level = characteristic.getIntValue(BluetoothGattCharacteristic.FORMAT_UINT8, 0)
                level?.let {
                    val map = _batteryLevels.value.toMutableMap()
                    map[gatt.device.address] = it
                    _batteryLevels.value = map
                }
            }
        }
    }

    private fun enableNotification(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic?) {
        if (characteristic == null) return
        gatt.setCharacteristicNotification(characteristic, true)
        val descriptor = characteristic.getDescriptor(BleGattUuids.CCCD) ?: return
        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        gatt.writeDescriptor(descriptor)
    }

    private fun handleCharacteristicUpdate(address: String, uuid: java.util.UUID, bytes: ByteArray?) {
        when (uuid) {
            BleGattUuids.HEART_RATE_MEASUREMENT -> {
                val sample = HeartRateParser.parse(bytes)
                if (sample != null) {
                    _latestHeartRate.value = sample
                }
            }
            BleGattUuids.CSC_MEASUREMENT -> {
                val parser = speedCadenceParsers.getOrPut(address) { CyclingSpeedCadenceParser() }
                val sample = parser.parse(bytes) ?: return
                val role = sensorRoles[address] ?: SensorRole.COMBO

                if (role == SensorRole.SPEED_ONLY || role == SensorRole.COMBO) {
                    sample.speedMps?.let { _latestSpeedMps.value = it }
                }
                if (role == SensorRole.CADENCE_ONLY || role == SensorRole.COMBO) {
                    sample.cadenceRpm?.let { _latestCadenceRpm.value = it }
                }
            }
            BleGattUuids.CYCLING_POWER_MEASUREMENT -> {
                val sample = powerParser.parse(bytes)
                if (sample != null) {
                    _latestPower.value = sample
                    sample.cadenceRpm?.let {
                        // Cadence from power meter as cadence source if not already provided by CSC
                        if (_latestCadenceRpm.value == null || _latestCadenceRpm.value == 0) {
                            _latestCadenceRpm.value = it
                        }
                    }
                }
            }
        }
    }

    private fun scheduleReconnect(address: String) {
        val role = sensorRoles[address] ?: return
        scope.launch {
            delay(2000L) // Wait 2s before retry
            Log.d(TAG, "Executing reconnection to $address")
            connectSensor(address, role)
        }
    }
}

