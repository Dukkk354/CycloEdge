package com.cycloedge.app.data.local.entities

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey

@Entity(
    tableName = "trackpoints",
    primaryKeys = ["activity_id", "ts_ms"],
    foreignKeys = [
        ForeignKey(
            entity = ActivityEntity::class,
            parentColumns = ["id"],
            childColumns = ["activity_id"],
            onDelete = ForeignKey.CASCADE
        )
    ]
)
data class TrackpointEntity(
    @ColumnInfo(name = "activity_id")
    val activityId: String,

    @ColumnInfo(name = "ts_ms")
    val timestampMs: Long,

    @ColumnInfo(name = "latitude")
    val latitude: Double?,

    @ColumnInfo(name = "longitude")
    val longitude: Double?,

    @ColumnInfo(name = "gps_accuracy_m")
    val gpsAccuracyMeters: Float?,

    @ColumnInfo(name = "elevation_m")
    val elevationMeters: Double?,

    @ColumnInfo(name = "distance_m")
    val distanceMeters: Double,

    @ColumnInfo(name = "speed_mps")
    val speedMps: Double?,

    @ColumnInfo(name = "heart_rate")
    val heartRate: Int?,

    @ColumnInfo(name = "cadence")
    val cadence: Int?,

    @ColumnInfo(name = "power_w")
    val powerWatts: Int?,

    @ColumnInfo(name = "grade_pct")
    val gradePercent: Double?,

    @ColumnInfo(name = "is_paused")
    val isPaused: Boolean = false,

    @ColumnInfo(name = "is_dead_reckoning")
    val isDeadReckoning: Boolean = false
)

