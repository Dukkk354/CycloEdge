package com.cycloedge.app.domain.model

data class LiveTelemetry(
    val activityId: String = "",
    val state: ActivityState = ActivityState.IDLE,
    val timestampMs: Long = System.currentTimeMillis(),
    val latitude: Double? = null,
    val longitude: Double? = null,
    val gpsAccuracyMeters: Float? = null,
    val isDeadReckoning: Boolean = false,
    val speedMps: Double = 0.0,
    val avgSpeedMps: Double = 0.0,
    val maxSpeedMps: Double = 0.0,
    val distanceMeters: Double = 0.0,
    val elevationMeters: Double = 0.0,
    val elevationGainMeters: Double = 0.0,
    val gradePercentage: Double = 0.0,
    val heartRateBpm: Int? = null,
    val cadenceRpm: Int? = null,
    val powerWatts: Int? = null,
    val power3sWatts: Int? = null,
    val normalizedPowerWatts: Int? = null,
    val pedalBalancePercent: Double? = null,
    val isRightPedal: Boolean? = null,
    val elapsedSeconds: Long = 0L,
    val movingSeconds: Long = 0L,
    val currentLap: Int = 1,
    val isAutoPaused: Boolean = false,
    val isScreenLocked: Boolean = false,
    val sensorBatteryPercent: Map<String, Int> = emptyMap()
) {
    val speedKmh: Double get() = speedMps * 3.6
    val avgSpeedKmh: Double get() = avgSpeedMps * 3.6
    val maxSpeedKmh: Double get() = maxSpeedMps * 3.6
    val distanceKm: Double get() = distanceMeters / 1000.0

    val heartRateZone: HeartRateZone?
        get() = heartRateBpm?.let { HeartRateZone.fromBpm(it) }

    fun formattedTime(seconds: Long): String {
        val hrs = seconds / 3600
        val mins = (seconds % 3600) / 60
        val secs = seconds % 60
        return if (hrs > 0) {
            String.format("%02d:%02d:%02d", hrs, mins, secs)
        } else {
            String.format("%02d:%02d", mins, secs)
        }
    }
}

