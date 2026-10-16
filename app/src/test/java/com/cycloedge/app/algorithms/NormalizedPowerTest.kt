package com.cycloedge.app.algorithms

import com.cycloedge.app.domain.algorithms.NormalizedPowerCalculator
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class NormalizedPowerTest {

    @Test
    fun addSample_constantPower_npEqualsSteadyPower() {
        val calc = NormalizedPowerCalculator(ftpWatts = 250)

        // Steady ride at 200 Watts for 60 seconds
        var result = calc.addSample(200, 1)
        for (sec in 2..60) {
            result = calc.addSample(200, sec.toLong())
        }

        assertThat(result.power3sWatts).isEqualTo(200)
        // For steady power, NP should equal average power (200 W)
        assertThat(result.normalizedPowerWatts).isEqualTo(200)
        // IF = NP / FTP = 200 / 250 = 0.8
        assertThat(result.intensityFactor).isWithin(0.01).of(0.8)
    }

    @Test
    fun addSample_surgingIntervals_npIsHigherThanAveragePower() {
        val calc = NormalizedPowerCalculator(ftpWatts = 250)

        // Alternating 100W and 300W (average is 200W, but NP should be significantly higher due to 4th power weighting)
        var result = calc.addSample(100, 1)
        for (sec in 2..120) {
            val power = if ((sec / 15) % 2 == 0) 100 else 300
            result = calc.addSample(power, sec.toLong())
        }

        // NP should exceed the arithmetic mean of 200W
        assertThat(result.normalizedPowerWatts).isGreaterThan(210)
    }
}

