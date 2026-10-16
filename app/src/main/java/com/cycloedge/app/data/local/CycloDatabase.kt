package com.cycloedge.app.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import com.cycloedge.app.data.local.dao.ActivityDao
import com.cycloedge.app.data.local.dao.PairedSensorDao
import com.cycloedge.app.data.local.dao.SyncJobDao
import com.cycloedge.app.data.local.dao.TrackpointDao
import com.cycloedge.app.data.local.entities.ActivityEntity
import com.cycloedge.app.data.local.entities.LapEntity
import com.cycloedge.app.data.local.entities.PairedSensorEntity
import com.cycloedge.app.data.local.entities.SyncJobEntity
import com.cycloedge.app.data.local.entities.TrackpointEntity

@Database(
    entities = [
        ActivityEntity::class,
        TrackpointEntity::class,
        PairedSensorEntity::class,
        LapEntity::class,
        SyncJobEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class CycloDatabase : RoomDatabase() {

    abstract fun activityDao(): ActivityDao
    abstract fun trackpointDao(): TrackpointDao
    abstract fun pairedSensorDao(): PairedSensorDao
    abstract fun syncJobDao(): SyncJobDao

    companion object {
        @Volatile
        private var INSTANCE: CycloDatabase? = null

        fun getInstance(context: Context): CycloDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    CycloDatabase::class.java,
                    "cycloedge_local.db"
                )
                    .addCallback(object : Callback() {
                        override fun onOpen(db: SupportSQLiteDatabase) {
                            super.onOpen(db)
                            // Enable SQLite Write-Ahead Logging (WAL) and foreign keys
                            db.execSQL("PRAGMA journal_mode = WAL;")
                            db.execSQL("PRAGMA synchronous = NORMAL;")
                            db.execSQL("PRAGMA foreign_keys = ON;")
                        }
                    })
                    .fallbackToDestructiveMigration()
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }
}

