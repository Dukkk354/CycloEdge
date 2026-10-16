package com.cycloedge.app.data.local.entities

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "sync_jobs",
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
data class SyncJobEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,

    @ColumnInfo(name = "activity_id")
    val activityId: String,

    @ColumnInfo(name = "provider")
    val provider: String, // STRAVA, INTERVALS, LOCAL_EXPORT

    @ColumnInfo(name = "status")
    val status: String = "PENDING", // PENDING, UPLOADING, DONE, FAILED

    @ColumnInfo(name = "external_id")
    val externalId: String? = null,

    @ColumnInfo(name = "attempts")
    val attempts: Int = 0,

    @ColumnInfo(name = "last_error")
    val lastError: String? = null,

    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),

    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis()
)

