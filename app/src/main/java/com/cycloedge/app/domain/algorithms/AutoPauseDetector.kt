package com.cycloedge.app.domain.algorithms

class AutoPauseDetector(
    private val pauseSpeedThresholdKmh: Double = 2.0,
    private val resumeSpeedThresholdKmh: Double = 3.0,
    private val pauseConsecutiveSeconds: Int = 5,
    private val resumeConsecutiveSeconds: Int = 2
) {
    private var isCurrentlyPaused = false
    private var belowThresholdCounter = 0
    private var aboveThresholdCounter = 0

    val isPaused: Boolean get() = isCurrentlyPaused

    fun reset() {
        isCurrentlyPaused = false
        belowThresholdCounter = 0
        aboveThresholdCounter = 0
    }

    /**
     * Updates detector on 1 Hz telemetry tick
     * @param speedMps current speed from wheel sensor or GPS
     * @return true if state changed (triggered pause or resume event)
     */
    fun update(speedMps: Double): StateTransition {
        val speedKmh = speedMps * 3.6

        if (!isCurrentlyPaused) {
            if (speedKmh < pauseSpeedThresholdKmh) {
                belowThresholdCounter++
                if (belowThresholdCounter >= pauseConsecutiveSeconds) {
                    isCurrentlyPaused = true
                    belowThresholdCounter = 0
                    aboveThresholdCounter = 0
                    return StateTransition.TRIGGERED_PAUSE
                }
            } else {
                belowThresholdCounter = 0
            }
        } else {
            if (speedKmh > resumeSpeedThresholdKmh) {
                aboveThresholdCounter++
                if (aboveThresholdCounter >= resumeConsecutiveSeconds) {
                    isCurrentlyPaused = false
                    aboveThresholdCounter = 0
                    belowThresholdCounter = 0
                    return StateTransition.TRIGGERED_RESUME
                }
            } else {
                aboveThresholdCounter = 0
            }
        }

        return StateTransition.NONE
    }

    enum class StateTransition {
        NONE,
        TRIGGERED_PAUSE,
        TRIGGERED_RESUME
    }
}

