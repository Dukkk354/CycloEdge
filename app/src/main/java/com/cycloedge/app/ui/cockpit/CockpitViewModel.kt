package com.cycloedge.app.ui.cockpit

import android.app.Application
import android.content.Intent
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cycloedge.app.data.local.CycloDatabase
import com.cycloedge.app.data.local.entities.ActivityEntity
import com.cycloedge.app.domain.model.ActivityState
import com.cycloedge.app.domain.model.LiveTelemetry
import com.cycloedge.app.export.FitFileEncoder
import com.cycloedge.app.service.RecordingForegroundService
import com.cycloedge.app.service.ServiceNotificationHelper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File

class CockpitViewModel(application: Application) : AndroidViewModel(application) {

    private val context = application.applicationContext
    private val database = CycloDatabase.getInstance(context)

    val telemetry: StateFlow<LiveTelemetry> = RecordingForegroundService.telemetryState

    private val _isScreenLocked = MutableStateFlow(false)
    val isScreenLocked: StateFlow<Boolean> = _isScreenLocked.asStateFlow()

    private val _recoverableActivity = MutableStateFlow<ActivityEntity?>(null)
    val recoverableActivity: StateFlow<ActivityEntity?> = _recoverableActivity.asStateFlow()

    init {
        checkForCrashedOrRecoverableActivity()
    }

    fun checkForCrashedOrRecoverableActivity() {
        if (RecordingForegroundService.isServiceRunning) return

        viewModelScope.launch(Dispatchers.IO) {
            val recoverable = database.activityDao().getActiveOrRecoverableActivity()
            if (recoverable != null) {
                _recoverableActivity.value = recoverable
            }
        }
    }

    fun dismissRecovery() {
        _recoverableActivity.value = null
    }

    fun discardRecoverableActivity(activityId: String) {
        viewModelScope.launch(Dispatchers.IO) {
            database.activityDao().deleteById(activityId)
            _recoverableActivity.value = null
        }
    }

    fun saveRecoverableActivity(activity: ActivityEntity) {
        viewModelScope.launch(Dispatchers.IO) {
            val trackpoints = database.trackpointDao().getTrackpointsForActivity(activity.id)
            val fitDir = File(context.filesDir, "fits").apply { mkdirs() }
            val fitFile = File(fitDir, "${activity.id}.fit")

            FitFileEncoder.encodeAndSave(activity, trackpoints, fitFile)

            val updated = activity.copy(
                status = "FINISHED",
                fitFilePath = fitFile.absolutePath,
                endTimeMs = activity.lastCheckpointMs ?: System.currentTimeMillis()
            )
            database.activityDao().update(updated)
            _recoverableActivity.value = null
        }
    }

    fun startRide() {
        val intent = Intent(context, RecordingForegroundService::class.java).apply {
            action = ServiceNotificationHelper.ACTION_START
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    fun pauseRide() {
        val intent = Intent(context, RecordingForegroundService::class.java).apply {
            action = ServiceNotificationHelper.ACTION_PAUSE
        }
        context.startService(intent)
    }

    fun resumeRide() {
        val intent = Intent(context, RecordingForegroundService::class.java).apply {
            action = ServiceNotificationHelper.ACTION_RESUME
        }
        context.startService(intent)
    }

    fun triggerLap() {
        val intent = Intent(context, RecordingForegroundService::class.java).apply {
            action = ServiceNotificationHelper.ACTION_LAP
        }
        context.startService(intent)
    }

    fun stopRide() {
        val intent = Intent(context, RecordingForegroundService::class.java).apply {
            action = ServiceNotificationHelper.ACTION_STOP
        }
        context.startService(intent)

        // Generate FIT file upon stop
        val current = telemetry.value
        if (current.activityId.isNotEmpty()) {
            viewModelScope.launch(Dispatchers.IO) {
                val activity = database.activityDao().getActivityById(current.activityId) ?: return@launch
                val trackpoints = database.trackpointDao().getTrackpointsForActivity(current.activityId)
                val fitDir = File(context.filesDir, "fits").apply { mkdirs() }
                val fitFile = File(fitDir, "${current.activityId}.fit")

                FitFileEncoder.encodeAndSave(activity, trackpoints, fitFile)

                val finishedActivity = activity.copy(
                    status = "FINISHED",
                    endTimeMs = System.currentTimeMillis(),
                    fitFilePath = fitFile.absolutePath
                )
                database.activityDao().update(finishedActivity)
            }
        }
    }

    fun toggleScreenLock() {
        _isScreenLocked.value = !_isScreenLocked.value
    }

    fun unlockScreen() {
        _isScreenLocked.value = false
    }
}

