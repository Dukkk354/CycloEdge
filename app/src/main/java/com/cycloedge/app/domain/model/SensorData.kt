package com.cycloedge.app.domain.model

enum class SensorType {
    HEART_RATE,
    CSC,
    POWER
}

enum class SensorRole {
    SPEED_ONLY,
    CADENCE_ONLY,
    COMBO,
    HR,
    POWER
}

data class DiscoveredSensor(
    val address: String,
    val name: String,
    val type: SensorType,
    val rssi: Int = 0
)

data class HeartRateSample(
    val bpm: Int,
    val sensorContactDetected: Boolean,
    val rrIntervalsMs: List<Double> = emptyList(),
    val timestampMs: Long = System.currentTimeMillis()
)

data class CSCSample(
    val speedMps: Double? = null,
    val cadenceRpm: Int? = null,
    val wheelRevolutions: Long? = null,
    val crankRevolutions: Int? = null,
    val timestampMs: Long = System.currentTimeMillis()
)

data class CyclingPowerSample(
    val instantaneousPowerWatts: Int,
    val pedalBalancePercent: Double? = null,
    val isRightPedal: Boolean? = null,
    val cadenceRpm: Int? = null,
    val timestampMs: Long = System.currentTimeMillis()
)

