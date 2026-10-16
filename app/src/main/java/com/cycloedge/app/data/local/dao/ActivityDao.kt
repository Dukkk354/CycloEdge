package com.cycloedge.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.cycloedge.app.data.local.entities.ActivityEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ActivityDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(activity: ActivityEntity)

    @Update
    suspend fun update(activity: ActivityEntity)

    @Query("SELECT * FROM activities WHERE id = :id LIMIT 1")
    suspend fun getActivityById(id: String): ActivityEntity?

    @Query("SELECT * FROM activities WHERE status IN ('RECORDING', 'PAUSED') ORDER BY start_time_ms DESC LIMIT 1")
    suspend fun getActiveOrRecoverableActivity(): ActivityEntity?

    @Query("SELECT * FROM activities WHERE status = 'FINISHED' ORDER BY start_time_ms DESC")
    fun getAllFinishedActivities(): Flow<List<ActivityEntity>>

    @Query("UPDATE activities SET last_checkpoint_ms = :checkpointMs, total_distance_m = :distanceM, elapsed_s = :elapsedS, moving_s = :movingS, updated_at = :updatedAt WHERE id = :id")
    suspend fun updateCheckpoint(id: String, checkpointMs: Long, distanceM: Double, elapsedS: Long, movingS: Long, updatedAt: Long)

    @Query("DELETE FROM activities WHERE id = :id")
    suspend fun deleteById(id: String)
}

