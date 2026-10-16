package com.cycloedge.app.data.local.entities

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "paired_sensors")
data class PairedSensorEntity(
    @PrimaryKey
    @ColumnInfo(name = "sensor_id")
    val sensorId: String, // BLE MAC address

    @ColumnInfo(name = "name")
    val name: String,

    @ColumnInfo(name = "sensor_type")
    val sensorType: String, // HEART_RATE, CSC, POWER

    @ColumnInfo(name = "role")
    val role: String = "COMBO", // SPEED_ONLY, CADENCE_ONLY, COMBO, HR, POWER

    @ColumnInfo(name = "is_enabled")
    val isEnabled: Boolean = true,

    @ColumnInfo(name = "last_battery_pct")
    val lastBatteryPercent: Int? = null,

    @ColumnInfo(name = "last_connected_at")
    val lastConnectedAt: Long? = null
)

