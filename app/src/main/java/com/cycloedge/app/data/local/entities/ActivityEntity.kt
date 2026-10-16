package com.cycloedge.app.data.local.entities

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "activities",
    indices = [
        Index(value = ["status"]),
        Index(value = ["start_time_ms"])
    ]
)
data class ActivityEntity(
    @PrimaryKey
    @ColumnInfo(name = "id")
    val id: String,

    @ColumnInfo(name = "title")
    val title: String,

    @ColumnInfo(name = "sport")
    val sport: String = "cycling",

    @ColumnInfo(name = "status")
    val status: String = "RECORDING", // RECORDING, PAUSED, STOPPED, FINISHED, DISCARDED

    @ColumnInfo(name = "start_time_ms")
    val startTimeMs: Long,

    @ColumnInfo(name = "end_time_ms")
    val endTimeMs: Long? = null,

    @ColumnInfo(name = "last_checkpoint_ms")
    val lastCheckpointMs: Long? = null,

    @ColumnInfo(name = "total_distance_m")
    val totalDistanceMeters: Double = 0.0,

    @ColumnInfo(name = "elapsed_s")
    val elapsedSeconds: Long = 0L,

    @ColumnInfo(name = "moving_s")
    val movingSeconds: Long = 0L,

    @ColumnInfo(name = "avg_speed_mps")
    val avgSpeedMps: Double? = null,

    @ColumnInfo(name = "max_speed_mps")
    val maxSpeedMps: Double? = null,

    @ColumnInfo(name = "avg_heart_rate")
    val avgHeartRate: Int? = null,

    @ColumnInfo(name = "max_heart_rate")
    val maxHeartRate: Int? = null,

    @ColumnInfo(name = "avg_cadence")
    val avgCadence: Int? = null,

    @ColumnInfo(name = "avg_power_w")
    val avgPowerWatts: Int? = null,

    @ColumnInfo(name = "max_power_w")
    val maxPowerWatts: Int? = null,

    @ColumnInfo(name = "normalized_power_w")
    val normalizedPowerWatts: Int? = null,

    @ColumnInfo(name = "total_ascent_m")
    val totalAscentMeters: Double = 0.0,

    @ColumnInfo(name = "total_descent_m")
    val totalDescentMeters: Double = 0.0,

    @ColumnInfo(name = "calories_kcal")
    val caloriesKcal: Int? = null,

    @ColumnInfo(name = "fit_file_path")
    val fitFilePath: String? = null,

    @ColumnInfo(name = "summary_polyline")
    val summaryPolyline: String? = null, // Encoded polyline for <50ms UI render

    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),

    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis()
)

