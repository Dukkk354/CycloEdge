package com.cycloedge.app.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.cycloedge.app.R
import com.cycloedge.app.domain.model.LiveTelemetry
import com.cycloedge.app.ui.MainActivity

object ServiceNotificationHelper {
    const val NOTIFICATION_ID = 1001
    const val CHANNEL_ID = "cycloedge_recording_channel"

    const val ACTION_START = "ACTION_START"
    const val ACTION_PAUSE = "ACTION_PAUSE"
    const val ACTION_RESUME = "ACTION_RESUME"
    const val ACTION_STOP = "ACTION_STOP"
    const val ACTION_LAP = "ACTION_LAP"

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.recording_notification_channel_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = context.getString(R.string.recording_notification_channel_desc)
                setShowBadge(false)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    fun buildNotification(context: Context, telemetry: LiveTelemetry): Notification {
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            context,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val pauseResumeAction = if (telemetry.state == com.cycloedge.app.domain.model.ActivityState.PAUSED) {
            val resumeIntent = Intent(context, RecordingForegroundService::class.java).apply {
                action = ACTION_RESUME
            }
            val resumePendingIntent = PendingIntent.getService(
                context, 1, resumeIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            NotificationCompat.Action.Builder(
                android.R.drawable.ic_media_play,
                context.getString(R.string.btn_resume),
                resumePendingIntent
            ).build()
        } else {
            val pauseIntent = Intent(context, RecordingForegroundService::class.java).apply {
                action = ACTION_PAUSE
            }
            val pausePendingIntent = PendingIntent.getService(
                context, 2, pauseIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            NotificationCompat.Action.Builder(
                android.R.drawable.ic_media_pause,
                context.getString(R.string.btn_pause),
                pausePendingIntent
            ).build()
        }

        val stopIntent = Intent(context, RecordingForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            context, 3, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_close_clear_cancel,
            context.getString(R.string.btn_stop),
            stopPendingIntent
        ).build()

        val contentText = String.format(
            "%.1f km | %s | %.1f km/h",
            telemetry.distanceKm,
            telemetry.formattedTime(telemetry.movingSeconds),
            telemetry.speedKmh
        )

        val hrText = telemetry.heartRateBpm?.let { " • ♥ $it bpm" } ?: ""

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(context.getString(R.string.ride_in_progress) + hrText)
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(pauseResumeAction)
            .addAction(stopAction)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .build()
    }
}

