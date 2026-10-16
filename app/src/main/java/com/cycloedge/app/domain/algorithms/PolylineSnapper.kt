package com.cycloedge.app.domain.algorithms

import kotlin.math.*

class PolylineSnapper(
    private val offRouteThresholdMeters: Double = 35.0,
    private val debounceSeconds: Int = 5
) {
    data class LatLng(val latitude: Double, val longitude: Double)

    private var consecutiveOffRouteCount = 0
    private var isCurrentlyOffRoute = false

    fun reset() {
        consecutiveOffRouteCount = 0
        isCurrentlyOffRoute = false
    }

    data class SnapResult(
        val snappedPoint: LatLng,
        val crossTrackDistanceMeters: Double,
        val isOffRoute: Boolean,
        val segmentBearingDegrees: Double
    )

    /**
     * Projects point P onto a polyline segment AB with direction awareness
     */
    fun snap(
        point: LatLng,
        headingDegrees: Double?,
        routePoints: List<LatLng>,
        lastProgressIndex: Int = 0,
        gpsAccuracyMeters: Float = 10f
    ): SnapResult? {
        if (routePoints.size < 2) return null

        // Search window: +/- 50 indices around last known progress
        val startIndex = max(0, lastProgressIndex - 20)
        val endIndex = min(routePoints.size - 1, lastProgressIndex + 50)

        var minDistance = Double.MAX_VALUE
        var bestSnappedPoint = point
        var bestBearing = 0.0

        for (i in startIndex until endIndex) {
            val a = routePoints[i]
            val b = routePoints[i + 1]

            val segBearing = calculateBearingDegrees(a, b)

            // If heading is known, verify directional alignment: cos(diff) >= 0.5 (within 60 degrees)
            if (headingDegrees != null) {
                val dAngle = Math.toRadians(headingDegrees - segBearing)
                if (cos(dAngle) < 0.5) {
                    continue // Skip opposing direction segments
                }
            }

            val projected = projectPointOnSegment(point, a, b)
            val dist = HaversineDistance.calculateMeters(
                point.latitude, point.longitude,
                projected.latitude, projected.longitude
            )

            if (dist < minDistance) {
                minDistance = dist
                bestSnappedPoint = projected
                bestBearing = segBearing
            }
        }

        val dynamicThreshold = max(offRouteThresholdMeters, 2.0 * gpsAccuracyMeters)
        if (minDistance > dynamicThreshold) {
            consecutiveOffRouteCount++
            if (consecutiveOffRouteCount >= debounceSeconds) {
                isCurrentlyOffRoute = true
            }
        } else {
            consecutiveOffRouteCount = 0
            isCurrentlyOffRoute = false
        }

        return SnapResult(
            snappedPoint = bestSnappedPoint,
            crossTrackDistanceMeters = minDistance,
            isOffRoute = isCurrentlyOffRoute,
            segmentBearingDegrees = bestBearing
        )
    }

    private fun projectPointOnSegment(p: LatLng, a: LatLng, b: LatLng): LatLng {
        val latRef = Math.toRadians(a.latitude)
        val mPerDegLat = 111132.954
        val mPerDegLon = 111132.954 * cos(latRef)

        val px = (p.longitude - a.longitude) * mPerDegLon
        val py = (p.latitude - a.latitude) * mPerDegLat

        val bx = (b.longitude - a.longitude) * mPerDegLon
        val by = (b.latitude - a.latitude) * mPerDegLat

        val segLenSq = bx * bx + by * by
        if (segLenSq == 0.0) return a

        val t = ((px * bx + py * by) / segLenSq).coerceIn(0.0, 1.0)

        val snapX = t * bx
        val snapY = t * by

        val snapLon = a.longitude + (snapX / mPerDegLon)
        val snapLat = a.latitude + (snapY / mPerDegLat)

        return LatLng(snapLat, snapLon)
    }

    private fun calculateBearingDegrees(a: LatLng, b: LatLng): Double {
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val dLon = Math.toRadians(b.longitude - a.longitude)

        val y = sin(dLon) * cos(lat2)
        val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        val brng = Math.toDegrees(atan2(y, x))
        return (brng + 360.0) % 360.0
    }
}

