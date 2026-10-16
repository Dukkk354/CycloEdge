package com.cycloedge.app.service

import android.content.Context
import android.os.PowerManager
import android.util.Log

class WakeLockManager(private val context: Context) {
    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        private const val TAG = "WakeLockManager"
        private const val WAKE_LOCK_TAG = "CycloEdge::RecordingWakeLock"
    }

    fun acquire() {
        if (wakeLock?.isHeld == true) return
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG).apply {
            setReferenceCounted(false)
            acquire()
        }
        Log.d(TAG, "Partial WakeLock acquired for active ride recording")
    }

    fun release() {
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
            Log.d(TAG, "Partial WakeLock released")
        }
        wakeLock = null
    }
}

