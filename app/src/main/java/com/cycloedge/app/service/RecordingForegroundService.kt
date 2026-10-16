package com.cycloedge.app.service

import android.annotation.SuppressLint
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import androidx.core.app.ServiceCompat
import com.cycloedge.app.data.local.CycloDatabase
import com.cycloedge.app.data.local.entities.ActivityEntity
import com.cycloedge.app.data.local.entities.LapEntity
import com.cycloedge.app.data.local.entities.TrackpointEntity
import com.cycloedge.app.domain.algorithms.*
import com.cycloedge.app.domain.ble.BleSensorManager
import com.cycloedge.app.domain.model.ActivityState
import com.cycloedge.app.domain.model.LiveTelemetry
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

@SuppressLint("MissingPermission")
class RecordingForegroundService : Service(), LocationListener {

    companion object {
        private const val TAG = "RecordingService"

        private val _telemetryState = MutableStateFlow(LiveTelemetry())
        val telemetryState: StateFlow<LiveTelemetry> = _telemetryState.asStateFlow()

        var isServiceRunning = false
            private set
    }

    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.Default + serviceJob)

    private lateinit var database: CycloDatabase
    private lateinit var wakeLockManager: WakeLockManager
    private lateinit var bleSensorManager: BleSensorManager
    private lateinit var locationManager: LocationManager

    // Algorithms
    private val kalmanFilter = KalmanFilter()
    private val elevationFilter = ElevationComplementaryFilter()
    private val autoPauseDetector = AutoPauseDetector()
    private val npCalculator = NormalizedPowerCalculator()

    // Activity State
    private var currentActivityId: String = ""
    private var activityStartTimeMs: Long = 0L
    private var elapsedSeconds: Long = 0L
    private var movingSeconds: Long = 0L
    private var cumulativeDistanceMeters: Double = 0.0
    private var maxSpeedMps: Double = 0.0

    // Coordinates tracking
    private var lastRawLat: Double? = null
    private var lastRawLon: Double? = null
    private var lastFilteredLat: Double? = null
    private var lastFilteredLon: Double? = null
    private var lastHeadingDegrees: Double = 0.0

    // Lap tracking
    private var currentLapIndex = 1
    private var lapStartDistanceM = 0.0
    private var lapStartMovingS = 0L

    // In-memory ring buffer for batch database flushing
    private val pendingTrackpoints = mutableListOf<TrackpointEntity>()
    private var lastDbFlushTimeMs: Long = 0L

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "RecordingForegroundService created")
        isServiceRunning = true

        database = CycloDatabase.getInstance(this)
        wakeLockManager = WakeLockManager(this)
        bleSensorManager = BleSensorManager(this, serviceScope)
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

        ServiceNotificationHelper.createNotificationChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ServiceNotificationHelper.ACTION_START

        when (action) {
            ServiceNotificationHelper.ACTION_START -> startRide()
            ServiceNotificationHelper.ACTION_PAUSE -> pauseRide()
            ServiceNotificationHelper.ACTION_RESUME -> resumeRide()
            ServiceNotificationHelper.ACTION_STOP -> stopRide()
            ServiceNotificationHelper.ACTION_LAP -> triggerManualLap()
        }

        return START_STICKY
    }

    private fun startRide() {
        if (_telemetryState.value.state == ActivityState.RECORDING) return

        currentActivityId = UUID.randomUUID().toString()
        activityStartTimeMs = System.currentTimeMillis()
        elapsedSeconds = 0L
        movingSeconds = 0L
        cumulativeDistanceMeters = 0.0
        maxSpeedMps = 0.0
        currentLapIndex = 1

        kalmanFilter.reset()
        elevationFilter.reset()
        autoPauseDetector.reset()
        npCalculator.reset()
        pendingTrackpoints.clear()

        // 1. Acquire WakeLock
        wakeLockManager.acquire()

        // 2. Start Foreground Service with location, connectedDevice, and health types (Android 14+)
        val notification = ServiceNotificationHelper.buildNotification(this, _telemetryState.value)
        val fgsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
        } else {
            0
        }
        ServiceCompat.startForeground(this, ServiceNotificationHelper.NOTIFICATION_ID, notification, fgsType)

        // 3. Register GPS updates (1000 ms, 0 m)
        try {
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                1000L,
                0.0f,
                this
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting GPS updates", e)
        }

        // 4. Insert initial Activity record into SQLite
        serviceScope.launch(Dispatchers.IO) {
            val entity = ActivityEntity(
                id = currentActivityId,
                title = "Gowes ${java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale.getDefault()).format(java.util.Date())}",
                startTimeMs = activityStartTimeMs,
                status = "RECORDING"
            )
            database.activityDao().insert(entity)
        }

        _telemetryState.value = _telemetryState.value.copy(
            activityId = currentActivityId,
            state = ActivityState.RECORDING,
            currentLap = currentLapIndex
        )

        // 5. Start 1 Hz Telemetry loop
        startTelemetryLoop()
    }

    private fun startTelemetryLoop() {
        serviceScope.launch {
            while (isActive && _telemetryState.value.state != ActivityState.STOPPED && _telemetryState.value.state != ActivityState.FINISHED) {
                delay(1000L)
                onTelemetryTick()
            }
        }
    }

    private fun onTelemetryTick() {
        val currentState = _telemetryState.value.state
        if (currentState != ActivityState.RECORDING && currentState != ActivityState.PAUSED) return

        elapsedSeconds++

        // 1. Determine speed: priority = BLE wheel sensor > GPS Doppler > Kalman
        val bleSpeed = bleSensorManager.latestSpeedMps.value
        val gpsSpeed = _telemetryState.value.speedMps
        val currentSpeed = bleSpeed ?: gpsSpeed

        // 2. Auto-Pause evaluation
        val autoPauseTransition = autoPauseDetector.update(currentSpeed)
        var isPaused = (currentState == ActivityState.PAUSED)

        if (autoPauseTransition == AutoPauseDetector.StateTransition.TRIGGERED_PAUSE) {
            isPaused = true
            _telemetryState.value = _telemetryState.value.copy(isAutoPaused = true)
        } else if (autoPauseTransition == AutoPauseDetector.StateTransition.TRIGGERED_RESUME) {
            isPaused = false
            _telemetryState.value = _telemetryState.value.copy(isAutoPaused = false)
        }

        // 3. Distance Accumulation (only when moving)
        var isDeadReckoning = false
        if (!isPaused) {
            movingSeconds++
            val deltaDistance = currentSpeed * 1.0 // 1 second step
            cumulativeDistanceMeters += deltaDistance

            if (currentSpeed > maxSpeedMps) {
                maxSpeedMps = currentSpeed
            }

            // Check Dead Reckoning if GPS accuracy is poor (>35m or no fix)
            val gpsAccuracy = _telemetryState.value.gpsAccuracyMeters
            if ((gpsAccuracy == null || gpsAccuracy > 35.0f) && bleSpeed != null && bleSpeed > 0.5) {
                isDeadReckoning = true
                // Dead reckoning: advance coordinates along last known heading
                lastFilteredLat?.let { prevLat ->
                    lastFilteredLon?.let { prevLon ->
                        val latRad = Math.toRadians(prevLat)
                        val mPerDegLat = 111132.954
                        val mPerDegLon = 111132.954 * kotlin.math.cos(latRad)

                        val headingRad = Math.toRadians(lastHeadingDegrees)
                        val dLat = (deltaDistance * kotlin.math.cos(headingRad)) / mPerDegLat
                        val dLon = (deltaDistance * kotlin.math.sin(headingRad)) / mPerDegLon

                        lastFilteredLat = prevLat + dLat
                        lastFilteredLon = prevLon + dLon
                    }
                }
            }
        }

        // 4. Power & Cadence Metrics
        val currentPower = bleSensorManager.latestPower.value?.instantaneousPowerWatts
        val powerMetrics = currentPower?.let { npCalculator.addSample(it, movingSeconds) }
        val currentCadence = bleSensorManager.latestCadenceRpm.value
        val currentHr = bleSensorManager.latestHeartRate.value?.bpm

        // 5. Elevation & Grade
        val elevationResult = elevationFilter.update(
            rawBaroAltitudeMeters = _telemetryState.value.elevationMeters,
            referenceAltitudeMeters = _telemetryState.value.elevationMeters,
            cumulativeDistanceMeters = cumulativeDistanceMeters
        )

        val avgSpeed = if (movingSeconds > 0) cumulativeDistanceMeters / movingSeconds else 0.0

        // 6. Update Live Telemetry State
        val updatedTelemetry = _telemetryState.value.copy(
            timestampMs = System.currentTimeMillis(),
            latitude = lastFilteredLat,
            longitude = lastFilteredLon,
            isDeadReckoning = isDeadReckoning,
            speedMps = currentSpeed,
            avgSpeedMps = avgSpeed,
            maxSpeedMps = maxSpeedMps,
            distanceMeters = cumulativeDistanceMeters,
            elevationMeters = elevationResult.currentElevationMeters,
            elevationGainMeters = elevationResult.totalAscentMeters,
            gradePercentage = elevationResult.gradePercentage,
            heartRateBpm = currentHr,
            cadenceRpm = currentCadence,
            powerWatts = currentPower,
            power3sWatts = powerMetrics?.power3sWatts,
            normalizedPowerWatts = powerMetrics?.normalizedPowerWatts,
            pedalBalancePercent = bleSensorManager.latestPower.value?.pedalBalancePercent,
            isRightPedal = bleSensorManager.latestPower.value?.isRightPedal,
            elapsedSeconds = elapsedSeconds,
            movingSeconds = movingSeconds
        )
        _telemetryState.value = updatedTelemetry

        // 7. Update Notification every second
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(
            ServiceNotificationHelper.NOTIFICATION_ID,
            ServiceNotificationHelper.buildNotification(this, updatedTelemetry)
        )

        // 8. Queue Trackpoint to In-Memory Buffer
        val nowMs = System.currentTimeMillis()
        val trackpoint = TrackpointEntity(
            activityId = currentActivityId,
            timestampMs = nowMs,
            latitude = lastFilteredLat,
            longitude = lastFilteredLon,
            gpsAccuracyMeters = if (isDeadReckoning) null else _telemetryState.value.gpsAccuracyMeters,
            elevationMeters = elevationResult.currentElevationMeters,
            distanceMeters = cumulativeDistanceMeters,
            speedMps = currentSpeed,
            heartRate = currentHr,
            cadence = currentCadence,
            powerWatts = currentPower,
            gradePercent = elevationResult.gradePercentage,
            isPaused = isPaused,
            isDeadReckoning = isDeadReckoning
        )
        pendingTrackpoints.add(trackpoint)

        // 9. Batch Flush to SQLite WAL every 3 seconds
        if (nowMs - lastDbFlushTimeMs >= 3000L || pendingTrackpoints.size >= 5) {
            flushBufferToDatabase(nowMs)
        }
    }

    private fun flushBufferToDatabase(nowMs: Long) {
        if (pendingTrackpoints.isEmpty()) return
        val batch = ArrayList(pendingTrackpoints)
        pendingTrackpoints.clear()
        lastDbFlushTimeMs = nowMs

        serviceScope.launch(Dispatchers.IO) {
            try {
                database.trackpointDao().insertBatch(batch)
                database.activityDao().updateCheckpoint(
                    id = currentActivityId,
                    checkpointMs = nowMs,
                    distanceM = cumulativeDistanceMeters,
                    elapsedS = elapsedSeconds,
                    movingS = movingSeconds,
                    updatedAt = nowMs
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error writing batch trackpoints to SQLite", e)
            }
        }
    }

    override fun onLocationChanged(location: Location) {
        if (location.isFromMockProvider && !com.cycloedge.app.BuildConfig.DEBUG) return

        lastRawLat = location.latitude
        lastRawLon = location.longitude

        val smoothed = kalmanFilter.filter(
            location.latitude,
            location.longitude,
            location.accuracy,
            location.time
        )

        lastFilteredLat = smoothed.latitude
        lastFilteredLon = smoothed.longitude
        lastHeadingDegrees = smoothed.bearingDegrees

        val speed = if (location.hasSpeed() && location.speed >= 0.5f) {
            location.speed.toDouble()
        } else {
            smoothed.speedMps
        }

        _telemetryState.value = _telemetryState.value.copy(
            latitude = smoothed.latitude,
            longitude = smoothed.longitude,
            gpsAccuracyMeters = location.accuracy,
            elevationMeters = location.altitude,
            speedMps = speed
        )
    }

    private fun pauseRide() {
        _telemetryState.value = _telemetryState.value.copy(state = ActivityState.PAUSED)
    }

    private fun resumeRide() {
        _telemetryState.value = _telemetryState.value.copy(state = ActivityState.RECORDING)
    }

    private fun triggerManualLap() {
        val nowMs = System.currentTimeMillis()
        val lapDistance = cumulativeDistanceMeters - lapStartDistanceM
        val lapMovingS = movingSeconds - lapStartMovingS
        val avgLapSpeed = if (lapMovingS > 0) lapDistance / lapMovingS else 0.0

        val lap = LapEntity(
            activityId = currentActivityId,
            lapIndex = currentLapIndex,
            trigger = "MANUAL",
            startMs = nowMs - (lapMovingS * 1000L),
            endMs = nowMs,
            distanceMeters = lapDistance,
            movingSeconds = lapMovingS,
            avgSpeedMps = avgLapSpeed
        )

        serviceScope.launch(Dispatchers.IO) {
            database.openHelper.writableDatabase.execSQL(
                "INSERT INTO laps (activity_id, lap_index, trigger, start_ms, end_ms, distance_m, moving_s, avg_speed_mps) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                arrayOf(lap.activityId, lap.lapIndex, lap.trigger, lap.startMs, lap.endMs, lap.distanceMeters, lap.movingSeconds, lap.avgSpeedMps)
            )
        }

        currentLapIndex++
        lapStartDistanceM = cumulativeDistanceMeters
        lapStartMovingS = movingSeconds

        _telemetryState.value = _telemetryState.value.copy(currentLap = currentLapIndex)
    }

    private fun stopRide() {
        flushBufferToDatabase(System.currentTimeMillis())
        _telemetryState.value = _telemetryState.value.copy(state = ActivityState.STOPPED)

        try {
            locationManager.removeUpdates(this)
        } catch (e: Exception) {
            Log.e(TAG, "Error removing location updates", e)
        }

        bleSensorManager.disconnectAll()
        wakeLockManager.release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        wakeLockManager.release()
        serviceJob.cancel()
        Log.d(TAG, "RecordingForegroundService destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
}

