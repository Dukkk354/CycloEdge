package com.cycloedge.app.domain.ble

import com.cycloedge.app.domain.model.CSCSample

class CyclingSpeedCadenceParser(
    private val wheelCircumferenceMeters: Double = 2.105 // Default 700x25c
) {
    private var lastWheelRevs: Long? = null
    private var lastWheelEventTime: Int? = null

    private var lastCrankRevs: Int? = null
    private var lastCrankEventTime: Int? = null

    fun reset() {
        lastWheelRevs = null
        lastWheelEventTime = null
        lastCrankRevs = null
        lastCrankEventTime = null
    }

    fun parse(bytes: ByteArray?): CSCSample? {
        if (bytes == null || bytes.isEmpty()) return null

        val flags = bytes[0].toInt() and 0xFF
        val hasWheel = (flags and 0x01) != 0
        val hasCrank = (flags and 0x02) != 0

        var offset = 1
        var calculatedSpeedMps: Double? = null
        var currentWheelRevs: Long? = null

        if (hasWheel) {
            if (bytes.size < offset + 6) return null
            // Cumulative Wheel Revolutions (uint32)
            val rev0 = bytes[offset].toLong() and 0xFF
            val rev1 = bytes[offset + 1].toLong() and 0xFF
            val rev2 = bytes[offset + 2].toLong() and 0xFF
            val rev3 = bytes[offset + 3].toLong() and 0xFF
            val wheelRevs = rev0 or (rev1 shl 8) or (rev2 shl 16) or (rev3 shl 24)

            // Last Wheel Event Time (uint16, unit: 1/1024 s)
            val time0 = bytes[offset + 4].toInt() and 0xFF
            val time1 = bytes[offset + 5].toInt() and 0xFF
            val wheelEventTime = time0 or (time1 shl 8)
            offset += 6

            currentWheelRevs = wheelRevs

            if (lastWheelRevs != null && lastWheelEventTime != null) {
                // Modular arithmetic for 32-bit and 16-bit rollover
                val dRevs = (wheelRevs - lastWheelRevs!! + 0x100000000L) % 0x100000000L
                val dTicks = (wheelEventTime - lastWheelEventTime!! + 0x10000) % 0x10000

                if (dTicks > 0 && dTicks <= 4096) { // Max 4 seconds interval
                    val dt = dTicks / 1024.0
                    val speed = (dRevs * wheelCircumferenceMeters) / dt
                    // Sanity check: <= 40 m/s (144 km/h)
                    if (speed in 0.0..40.0) {
                        calculatedSpeedMps = speed
                    }
                } else if (dTicks == 0) {
                    calculatedSpeedMps = 0.0
                }
            }
            lastWheelRevs = wheelRevs
            lastWheelEventTime = wheelEventTime
        }

        var calculatedCadenceRpm: Int? = null
        var currentCrankRevs: Int? = null

        if (hasCrank) {
            if (bytes.size < offset + 4) return null
            // Cumulative Crank Revolutions (uint16)
            val crank0 = bytes[offset].toInt() and 0xFF
            val crank1 = bytes[offset + 1].toInt() and 0xFF
            val crankRevs = crank0 or (crank1 shl 8)

            // Last Crank Event Time (uint16, unit: 1/1024 s)
            val cTime0 = bytes[offset + 2].toInt() and 0xFF
            val cTime1 = bytes[offset + 3].toInt() and 0xFF
            val crankEventTime = cTime0 or (cTime1 shl 8)
            offset += 4

            currentCrankRevs = crankRevs

            if (lastCrankRevs != null && lastCrankEventTime != null) {
                val dCrank = (crankRevs - lastCrankRevs!! + 0x10000) % 0x10000
                val dTicks = (crankEventTime - lastCrankEventTime!! + 0x10000) % 0x10000

                if (dTicks > 0 && dTicks <= 4096) {
                    val dt = dTicks / 1024.0
                    val cadence = ((dCrank / dt) * 60.0).toInt()
                    // Sanity check: 0..250 RPM
                    if (cadence in 0..250) {
                        calculatedCadenceRpm = cadence
                    }
                } else if (dTicks == 0) {
                    calculatedCadenceRpm = 0
                }
            }
            lastCrankRevs = crankRevs
            lastCrankEventTime = crankEventTime
        }

        return CSCSample(
            speedMps = calculatedSpeedMps,
            cadenceRpm = calculatedCadenceRpm,
            wheelRevolutions = currentWheelRevs,
            crankRevolutions = currentCrankRevs
        )
    }
}

