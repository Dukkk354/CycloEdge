package com.cycloedge.app.domain.algorithms

import kotlin.math.pow

class ElevationComplementaryFilter(
    private val standardSeaLevelPressureHpa: Double = 1013.25,
    private val hysteresisThresholdMeters: Double = 1.5 // Threshold T to avoid elevation noise accumulation
) {
    private var offsetMeters: Double = 0.0
    private var smoothedElevation: Double? = null
    private var isCalibrated: Boolean = false

    // Hysteresis ascent accumulator
    private var elevationAnchor: Double? = null
    private var totalAscentMeters: Double = 0.0
    private var totalDescentMeters: Double = 0.0

    // Grade window: rolling buffer of Pair<DistanceMeters, ElevationMeters>
    private val gradeHistory = ArrayDeque<Pair<Double, Double>>()

    fun reset() {
        offsetMeters = 0.0
        smoothedElevation = null
        isCalibrated = false
        elevationAnchor = null
        totalAscentMeters = 0.0
        totalDescentMeters = 0.0
        gradeHistory.clear()
    }

    /**
     * Converts atmospheric pressure (hPa / mbar) to raw barometric altitude (meters)
     */
    fun pressureToAltitudeMeters(pressureHpa: Double): Double {
        return 44330.0 * (1.0 - (pressureHpa / standardSeaLevelPressureHpa).pow(1.0 / 5.255))
    }

    /**
     * Process 1 Hz elevation sample
     * @param rawBaroAltitudeMeters Altitude derived from barometer (or GPS altitude if no baro)
     * @param referenceAltitudeMeters Altitude from GPS or DEM (used to calibrate offset)
     * @param cumulativeDistanceMeters Current total distance for grade calculation
     */
    fun update(
        rawBaroAltitudeMeters: Double,
        referenceAltitudeMeters: Double?,
        cumulativeDistanceMeters: Double
    ): ElevationResult {
        // Initial calibration with GPS/DEM
        if (!isCalibrated && referenceAltitudeMeters != null) {
            offsetMeters = referenceAltitudeMeters - rawBaroAltitudeMeters
            isCalibrated = true
        }

        // Complementary filter: slowly drift offset towards reference GPS/DEM to eliminate weather pressure changes
        if (referenceAltitudeMeters != null) {
            val alpha = 0.0033 // Time constant ~ 300 seconds
            val currentEstimated = rawBaroAltitudeMeters + offsetMeters
            val newEstimated = (1.0 - alpha) * currentEstimated + alpha * referenceAltitudeMeters
            offsetMeters = newEstimated - rawBaroAltitudeMeters
        }

        val currentFused = rawBaroAltitudeMeters + offsetMeters

        // EMA smoothing (alpha = 0.25)
        val smoothed = if (smoothedElevation == null) {
            currentFused
        } else {
            0.75 * smoothedElevation!! + 0.25 * currentFused
        }
        smoothedElevation = smoothed

        // Hysteresis Ascent / Descent calculation
        if (elevationAnchor == null) {
            elevationAnchor = smoothed
        } else {
            val diff = smoothed - elevationAnchor!!
            if (diff >= hysteresisThresholdMeters) {
                totalAscentMeters += diff
                elevationAnchor = smoothed
            } else if (-diff >= hysteresisThresholdMeters) {
                totalDescentMeters += (-diff)
                elevationAnchor = smoothed
            }
        }

        // Calculate Grade (%) over a 30m - 50m distance window
        gradeHistory.addLast(Pair(cumulativeDistanceMeters, smoothed))
        while (gradeHistory.size > 2 && cumulativeDistanceMeters - gradeHistory.first().first > 50.0) {
            gradeHistory.removeFirst()
        }

        var gradePct = 0.0
        if (gradeHistory.isNotEmpty()) {
            val oldest = gradeHistory.first()
            val dDist = cumulativeDistanceMeters - oldest.first
            val dElev = smoothed - oldest.second
            if (dDist >= 20.0) {
                gradePct = ((dElev / dDist) * 100.0).coerceIn(-30.0, 30.0)
            }
        }

        return ElevationResult(
            currentElevationMeters = smoothed,
            totalAscentMeters = totalAscentMeters,
            totalDescentMeters = totalDescentMeters,
            gradePercentage = gradePct
        )
    }

    data class ElevationResult(
        val currentElevationMeters: Double,
        val totalAscentMeters: Double,
        val totalDescentMeters: Double,
        val gradePercentage: Double
    )
}

