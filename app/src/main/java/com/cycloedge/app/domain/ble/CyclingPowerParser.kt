package com.cycloedge.app.domain.ble

import com.cycloedge.app.domain.model.CyclingPowerSample

class CyclingPowerParser {
    private var lastCrankRevs: Int? = null
    private var lastCrankEventTime: Int? = null

    fun reset() {
        lastCrankRevs = null
        lastCrankEventTime = null
    }

    fun parse(bytes: ByteArray?): CyclingPowerSample? {
        if (bytes == null || bytes.size < 4) return null

        val flags = (bytes[0].toInt() and 0xFF) or ((bytes[1].toInt() and 0xFF) shl 8)
        // Instantaneous power is signed 16-bit integer
        val powerWatts = (bytes[2].toInt() and 0xFF) or (bytes[3].toInt() shl 8)

        var offset = 4
        var pedalBalancePercent: Double? = null
        var isRightPedal: Boolean? = null

        // Bit 0: Pedal Power Balance Present
        if ((flags and 0x0001) != 0 && bytes.size > offset) {
            val rawBalance = bytes[offset].toInt() and 0xFF
            offset += 1
            isRightPedal = (rawBalance and 0x80) != 0
            val balanceVal = (rawBalance and 0x7F) * 0.5
            pedalBalancePercent = balanceVal
        }

        // Bit 1: Pedal Power Balance Reference (not adding bytes)

        // Bit 2: Accumulated Torque (uint16)
        if ((flags and 0x0004) != 0) {
            offset += 2
        }

        // Bit 4: Wheel Revolution Data (uint32 revs + uint16 time)
        if ((flags and 0x0010) != 0) {
            offset += 6
        }

        // Bit 5: Crank Revolution Data (uint16 revs + uint16 time)
        var calculatedCadenceRpm: Int? = null
        if ((flags and 0x0020) != 0 && bytes.size >= offset + 4) {
            val crank0 = bytes[offset].toInt() and 0xFF
            val crank1 = bytes[offset + 1].toInt() and 0xFF
            val crankRevs = crank0 or (crank1 shl 8)

            val time0 = bytes[offset + 2].toInt() and 0xFF
            val time1 = bytes[offset + 3].toInt() and 0xFF
            val crankTime = time0 or (time1 shl 8)
            offset += 4

            if (lastCrankRevs != null && lastCrankEventTime != null) {
                val dCrank = (crankRevs - lastCrankRevs!! + 0x10000) % 0x10000
                val dTicks = (crankTime - lastCrankEventTime!! + 0x10000) % 0x10000

                if (dTicks > 0 && dTicks <= 4096) {
                    val dt = dTicks / 1024.0
                    val cadence = ((dCrank / dt) * 60.0).toInt()
                    if (cadence in 0..250) {
                        calculatedCadenceRpm = cadence
                    }
                } else if (dTicks == 0) {
                    calculatedCadenceRpm = 0
                }
            }
            lastCrankRevs = crankRevs
            lastCrankEventTime = crankTime
        }

        return CyclingPowerSample(
            instantaneousPowerWatts = maxOf(0, powerWatts),
            pedalBalancePercent = pedalBalancePercent,
            isRightPedal = isRightPedal,
            cadenceRpm = calculatedCadenceRpm
        )
    }
}

