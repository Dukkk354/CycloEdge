package com.cycloedge.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.cycloedge.app.data.local.entities.PairedSensorEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface PairedSensorDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOrUpdate(sensor: PairedSensorEntity)

    @Update
    suspend fun update(sensor: PairedSensorEntity)

    @Query("SELECT * FROM paired_sensors WHERE is_enabled = 1")
    fun getEnabledSensors(): Flow<List<PairedSensorEntity>>

    @Query("SELECT * FROM paired_sensors WHERE sensor_id = :sensorId LIMIT 1")
    suspend fun getSensorById(sensorId: String): PairedSensorEntity?

    @Query("DELETE FROM paired_sensors WHERE sensor_id = :sensorId")
    suspend fun delete(sensorId: String)
}

