package com.cycloedge.app.algorithms

import com.cycloedge.app.domain.algorithms.AutoPauseDetector
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class AutoPauseDetectorTest {

    @Test
    fun update_speedDropsBelowThresholdFor5Seconds_triggersPause() {
        val detector = AutoPauseDetector(
            pauseSpeedThresholdKmh = 2.0,
            resumeSpeedThresholdKmh = 3.0,
            pauseConsecutiveSeconds = 5,
            resumeConsecutiveSeconds = 2
        )

        // Riding at 25 km/h (~6.94 m/s)
        for (i in 1..10) {
            val t = detector.update(6.94)
            assertThat(t).isEqualTo(AutoPauseDetector.StateTransition.NONE)
            assertThat(detector.isPaused).isFalse()
        }

        // Stopping at traffic light (0 km/h)
        // Seconds 1 to 4: should not pause yet
        for (i in 1..4) {
            val t = detector.update(0.0)
            assertThat(t).isEqualTo(AutoPauseDetector.StateTransition.NONE)
            assertThat(detector.isPaused).isFalse()
        }

        // 5th second: triggers pause!
        val t5 = detector.update(0.0)
        assertThat(t5).isEqualTo(AutoPauseDetector.StateTransition.TRIGGERED_PAUSE)
        assertThat(detector.isPaused).isTrue()

        // Still stopped
        val t6 = detector.update(0.0)
        assertThat(t6).isEqualTo(AutoPauseDetector.StateTransition.NONE)
        assertThat(detector.isPaused).isTrue()
    }

    @Test
    fun update_speedRisesAboveThresholdFor2Seconds_triggersResume() {
        val detector = AutoPauseDetector(
            pauseSpeedThresholdKmh = 2.0,
            resumeSpeedThresholdKmh = 3.0,
            pauseConsecutiveSeconds = 2,
            resumeConsecutiveSeconds = 2
        )

        // Trigger pause
        detector.update(0.0)
        detector.update(0.0)
        assertThat(detector.isPaused).isTrue()

        // Rider starts moving at 4.0 km/h (1.11 m/s)
        // 1st second: not resumed yet
        val r1 = detector.update(1.11)
        assertThat(r1).isEqualTo(AutoPauseDetector.StateTransition.NONE)
        assertThat(detector.isPaused).isTrue()

        // 2nd second: triggers resume!
        val r2 = detector.update(1.11)
        assertThat(r2).isEqualTo(AutoPauseDetector.StateTransition.TRIGGERED_RESUME)
        assertThat(detector.isPaused).isFalse()
    }
}

