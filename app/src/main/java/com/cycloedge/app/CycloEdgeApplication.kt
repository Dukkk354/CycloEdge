package com.cycloedge.app

import android.app.Application
import android.util.Log
import com.cycloedge.app.data.local.CycloDatabase
import com.cycloedge.app.service.ServiceNotificationHelper
import com.cycloedge.app.thermal.ThermalGuardManager

class CycloEdgeApplication : Application() {

    lateinit var database: CycloDatabase
        private set

    lateinit var thermalGuardManager: ThermalGuardManager
        private set

    override fun onCreate() {
        super.onCreate()
        Log.d("CycloEdgeApp", "Initializing CycloEdge Application")

        // 1. Initialize SQLite Database
        database = CycloDatabase.getInstance(this)

        // 2. Initialize Notification Channel
        ServiceNotificationHelper.createNotificationChannel(this)

        // 3. Start Thermal Monitoring for Tropical Overheating Prevention
        thermalGuardManager = ThermalGuardManager(this).apply {
            startMonitoring()
        }
    }
}

