package com.cycloedge.app.domain.ble

import com.cycloedge.app.domain.model.HeartRateSample

object HeartRateParser {

    fun parse(bytes: ByteArray?): HeartRateSample? {
        if (bytes == null || bytes.isEmpty()) return null

        val flags = bytes[0].toInt() and 0xFF
        val isHr16Bit = (flags and 0x01) != 0
        val contactStatus = (flags shr 1) and 0x03
        val hasEnergyExpended = (flags and 0x08) != 0
        val hasRrIntervals = (flags and 0x10) != 0

        val sensorContactDetected = (contactStatus == 3)

        var offset = 1
        val bpm = if (isHr16Bit) {
            if (bytes.size < offset + 2) return null
            val value = (bytes[offset].toInt() and 0xFF) or ((bytes[offset + 1].toInt() and 0xFF) shl 8)
            offset += 2
            value
        } else {
            if (bytes.size < offset + 1) return null
            val value = bytes[offset].toInt() and 0xFF
            offset += 1
            value
        }

        if (hasEnergyExpended) {
            offset += 2
        }

        val rrList = mutableListOf<Double>()
        if (hasRrIntervals) {
            while (offset + 1 < bytes.size) {
                val rawRr = (bytes[offset].toInt() and 0xFF) or ((bytes[offset + 1].toInt() and 0xFF) shl 8)
                val rrMs = (rawRr * 1000.0) / 1024.0
                rrList.add(rrMs)
                offset += 2
            }
        }

        if (bpm == 0) return null

        return HeartRateSample(
            bpm = bpm,
            sensorContactDetected = sensorContactDetected,
            rrIntervalsMs = rrList
        )
    }
}

