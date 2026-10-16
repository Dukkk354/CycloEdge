package com.cycloedge.app.data.local.entities

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "laps",
    foreignKeys = [
        ForeignKey(
            entity = ActivityEntity::class,
            parentColumns = ["id"],
            childColumns = ["activity_id"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index("activity_id")
    ]
)
data class LapEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,

    @ColumnInfo(name = "activity_id")
    val activityId: String,

    @ColumnInfo(name = "lap_index")
    val lapIndex: Int,

    @ColumnInfo(name = "trigger")
    val trigger: String = "MANUAL", // MANUAL, DISTANCE

    @ColumnInfo(name = "start_ms")
    val startMs: Long,

    @ColumnInfo(name = "end_ms")
    val endMs: Long? = null,

    @ColumnInfo(name = "distance_m")
    val distanceMeters: Double = 0.0,

    @ColumnInfo(name = "moving_s")
    val movingSeconds: Long = 0L,

    @ColumnInfo(name = "avg_speed_mps")
    val avgSpeedMps: Double? = null,

    @ColumnInfo(name = "avg_heart_rate")
    val avgHeartRate: Int? = null,

    @ColumnInfo(name = "avg_power_w")
    val avgPowerWatts: Int? = null,

    @ColumnInfo(name = "ascent_m")
    val ascentMeters: Double = 0.0
)

