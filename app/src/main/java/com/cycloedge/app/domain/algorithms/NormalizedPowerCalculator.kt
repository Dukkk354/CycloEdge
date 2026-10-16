package com.cycloedge.app.domain.algorithms

import kotlin.math.pow

class NormalizedPowerCalculator(
    private val ftpWatts: Int = 200
) {
    // 3-second window
    private val window3s = ArrayDeque<Int>()
    // 30-second rolling window
    private val window30s = ArrayDeque<Int>()
    // Sum of (30s average)^4
    private var sumPower4: Double = 0.0
    private var count30sSamples: Long = 0L

    fun reset() {
        window3s.clear()
        window30s.clear()
        sumPower4 = 0.0
        count30sSamples = 0L
    }

    data class PowerMetrics(
        val power3sWatts: Int,
        val normalizedPowerWatts: Int,
        val intensityFactor: Double,
        val trainingStressScore: Double
    )

    fun addSample(powerWatts: Int, totalMovingSeconds: Long): PowerMetrics {
        // Update 3s window
        window3s.addLast(powerWatts)
        if (window3s.size > 3) window3s.removeFirst()
        val avg3s = (window3s.sum().toDouble() / window3s.size).toInt()

        // Update 30s window
        window30s.addLast(powerWatts)
        if (window30s.size > 30) window30s.removeFirst()

        if (window30s.size >= 30) {
            val avg30s = window30s.sum().toDouble() / 30.0
            sumPower4 += avg30s.pow(4.0)
            count30sSamples++
        }

        val np = if (count30sSamples > 0) {
            (sumPower4 / count30sSamples).pow(0.25).toInt()
        } else {
            avg3s
        }

        val safeFtp = maxOf(50, ftpWatts)
        val ifVal = np.toDouble() / safeFtp
        val tss = if (totalMovingSeconds > 0) {
            ((totalMovingSeconds * np * ifVal) / (safeFtp * 3600.0)) * 100.0
        } else {
            0.0
        }

        return PowerMetrics(
            power3sWatts = avg3s,
            normalizedPowerWatts = np,
            intensityFactor = ifVal,
            trainingStressScore = tss
        )
    }
}

