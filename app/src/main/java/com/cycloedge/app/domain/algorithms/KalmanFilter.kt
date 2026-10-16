package com.cycloedge.app.domain.algorithms

import kotlin.math.cos

/**
 * 4-State Linear Kalman Filter for GNSS position and velocity smoothing
 * State vector x = [pos_east, pos_north, vel_east, vel_north]^T in local ENU meters
 */
class KalmanFilter(
    private val accelerationNoiseSigma: Double = 1.5 // m/s^2
) {
    // Reference origin (lat0, lon0) in degrees
    private var refLat: Double? = null
    private var refLon: Double? = null

    // State vector: x = [pe, pn, ve, vn]
    private var pe = 0.0
    private var pn = 0.0
    private var ve = 0.0
    private var vn = 0.0

    // Covariance matrix P (4x4)
    private var p00 = 100.0; private var p01 = 0.0;   private var p02 = 0.0; private var p03 = 0.0
    private var p10 = 0.0;   private var p11 = 100.0; private var p12 = 0.0; private var p13 = 0.0
    private var p20 = 0.0;   private var p21 = 0.0;   private var p22 = 25.0; private var p23 = 0.0
    private var p30 = 0.0;   private var p31 = 0.0;   private var p32 = 0.0;  private var p33 = 25.0

    private var lastTimestampMs: Long = 0L
    private val earthRadiusMeters = 6378137.0

    fun reset() {
        refLat = null
        refLon = null
        lastTimestampMs = 0L
    }

    data class FilterResult(
        val latitude: Double,
        val longitude: Double,
        val speedMps: Double,
        val bearingDegrees: Double
    )

    fun filter(lat: Double, lon: Double, accuracyMeters: Float, timestampMs: Long): FilterResult {
        if (refLat == null || refLon == null) {
            refLat = lat
            refLon = lon
            pe = 0.0
            pn = 0.0
            ve = 0.0
            vn = 0.0
            lastTimestampMs = timestampMs
            return FilterResult(lat, lon, 0.0, 0.0)
        }

        val dt = ((timestampMs - lastTimestampMs).coerceAtLeast(100L) / 1000.0).coerceAtMost(5.0)
        lastTimestampMs = timestampMs

        // 1. Convert WGS84 to local ENU meters relative to refLat, refLon
        val dLatRad = Math.toRadians(lat - refLat!!)
        val dLonRad = Math.toRadians(lon - refLon!!)
        val latRad = Math.toRadians(refLat!!)

        val zEast = dLonRad * earthRadiusMeters * cos(latRad)
        val zNorth = dLatRad * earthRadiusMeters

        // 2. Predict Step
        // x = F * x
        pe += ve * dt
        pn += vn * dt

        // P = F * P * F^T + Q
        val dt2 = dt * dt
        val dt3 = dt2 * dt
        val dt4 = dt3 * dt
        val qVal = accelerationNoiseSigma * accelerationNoiseSigma

        val qPos = qVal * (dt4 / 4.0)
        val qPosVel = qVal * (dt3 / 2.0)
        val qVel = qVal * dt2

        p00 += 2 * p02 * dt + p22 * dt2 + qPos
        p02 += p22 * dt + qPosVel
        p20 = p02
        p22 += qVel

        p11 += 2 * p13 * dt + p33 * dt2 + qPos
        p13 += p33 * dt + qPosVel
        p31 = p13
        p33 += qVel

        // 3. Update Step with Measurement Z
        val r = (accuracyMeters * accuracyMeters).toDouble().coerceAtLeast(4.0)

        // Innovation y = z - H * x
        val yEast = zEast - pe
        val yNorth = zNorth - pn

        // Innovation covariance S = H * P * H^T + R
        val sEast = p00 + r
        val sNorth = p11 + r

        // Kalman Gain K = P * H^T * S^-1
        val k00 = p00 / sEast
        val k20 = p20 / sEast

        val k11 = p11 / sNorth
        val k31 = p31 / sNorth

        // State update x = x + K * y
        pe += k00 * yEast
        pn += k11 * yNorth
        ve += k20 * yEast
        vn += k31 * yNorth

        // Covariance update P = (I - K * H) * P
        p00 *= (1.0 - k00)
        p02 *= (1.0 - k00)
        p20 = p02
        p22 -= k20 * p02

        p11 *= (1.0 - k11)
        p13 *= (1.0 - k11)
        p31 = p13
        p33 -= k31 * p13

        // 4. Convert back to WGS84
        val outLat = refLat!! + Math.toDegrees(pn / earthRadiusMeters)
        val outLon = refLon!! + Math.toDegrees(pe / (earthRadiusMeters * cos(latRad)))

        val speed = kotlin.math.sqrt(ve * ve + vn * vn)
        var bearing = Math.toDegrees(kotlin.math.atan2(ve, vn))
        if (bearing < 0) bearing += 360.0

        return FilterResult(outLat, outLon, speed, bearing)
    }
}

