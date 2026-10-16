package com.cycloedge.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.cycloedge.app.data.local.entities.SyncJobEntity

@Dao
interface SyncJobDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(job: SyncJobEntity): Long

    @Update
    suspend fun update(job: SyncJobEntity)

    @Query("SELECT * FROM sync_jobs WHERE status = 'PENDING' ORDER BY created_at ASC")
    suspend fun getPendingJobs(): List<SyncJobEntity>

    @Query("SELECT * FROM sync_jobs WHERE activity_id = :activityId AND provider = :provider LIMIT 1")
    suspend fun getJob(activityId: String, provider: String): SyncJobEntity?
}

