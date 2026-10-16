package com.cycloedge.app.domain.model

enum class ActivityState {
    IDLE,
    READY,
    RECORDING,
    PAUSED,
    STOPPED,
    FINISHED,
    RECOVERING,
    DISCARDED
}

enum class HeartRateZone(val zoneNumber: Int, val displayName: String, val minPct: Double, val maxPct: Double) {
    ZONE_1(1, "Z1 RECOVERY", 0.50, 0.60),
    ZONE_2(2, "Z2 ENDURANCE", 0.60, 0.70),
    ZONE_3(3, "Z3 TEMPO", 0.70, 0.80),
    ZONE_4(4, "Z4 THRESHOLD", 0.80, 0.90),
    ZONE_5(5, "Z5 ANAEROBIC", 0.90, 1.00);

    companion object {
        fun fromBpm(bpm: Int, maxHr: Int = 190): HeartRateZone? {
            if (bpm <= 0 || maxHr <= 0) return null
            val pct = bpm.toDouble() / maxHr
            return when {
                pct < 0.60 -> ZONE_1
                pct < 0.70 -> ZONE_2
                pct < 0.80 -> ZONE_3
                pct < 0.90 -> ZONE_4
                else -> ZONE_5
            }
        }
    }
}

