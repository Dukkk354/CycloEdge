package com.cycloedge.app.domain.algorithms

import kotlin.math.*

object HaversineDistance {
    private const val EARTH_RADIUS_METERS = 6371008.8

    /**
     * Calculates distance in meters between two lat/lon coordinates in WGS84
     */
    fun calculateMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)

        val rLat1 = Math.toRadians(lat1)
        val rLat2 = Math.toRadians(lat2)

        val a = sin(dLat / 2.0).pow(2.0) +
                cos(rLat1) * cos(rLat2) * sin(dLon / 2.0).pow(2.0)
        val c = 2.0 * asin(sqrt(a).coerceAtMost(1.0))

        return EARTH_RADIUS_METERS * c
    }

    /**
     * Filters distance step to prevent drift accumulation when stationary
     */
    fun shouldAccumulateDistance(
        stepDistanceMeters: Double,
        speedMps: Double,
        gpsAccuracyMeters: Float?
    ): Boolean {
        if (speedMps < 0.5) return false

        val acc = (gpsAccuracyMeters ?: 10.0f).toDouble()
        val minThreshold = max(1.0, 0.5 * acc)

        return if (speedMps < 1.0) {
            stepDistanceMeters >= minThreshold
        } else {
            stepDistanceMeters > 0.2
        }
    }
}

