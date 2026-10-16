package com.cycloedge.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.cycloedge.app.data.local.entities.TrackpointEntity

@Dao
interface TrackpointDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBatch(trackpoints: List<TrackpointEntity>)

    @Query("SELECT * FROM trackpoints WHERE activity_id = :activityId ORDER BY ts_ms ASC")
    suspend fun getTrackpointsForActivity(activityId: String): List<TrackpointEntity>

    @Query("SELECT COUNT(*) FROM trackpoints WHERE activity_id = :activityId")
    suspend fun getCountForActivity(activityId: String): Int

    @Query("SELECT * FROM trackpoints WHERE activity_id = :activityId ORDER BY ts_ms DESC LIMIT 1")
    suspend fun getLatestTrackpoint(activityId: String): TrackpointEntity?
}

