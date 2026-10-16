package com.cycloedge.app.ble

import com.cycloedge.app.domain.ble.HeartRateParser
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class HeartRateParserTest {

    @Test
    fun parse_standardUint8HeartRate_returnsCorrectBpm() {
        // Flags: 0x06 (Contact detected bit 1-2 = 3), Value: 142 bpm
        val bytes = byteArrayOf(0x06.toByte(), 142.toByte())
        val sample = HeartRateParser.parse(bytes)

        assertThat(sample).isNotNull()
        assertThat(sample!!.bpm).isEqualTo(142)
        assertThat(sample.sensorContactDetected).isTrue()
        assertThat(sample.rrIntervalsMs).isEmpty()
    }

    @Test
    fun parse_uint16HeartRateWithRrIntervals_returnsCorrectBpmAndRr() {
        // Flags: 0x17 (bit 0 = 1 (uint16), contact = 3, bit 4 = 1 (RR present))
        // BPM: 165 (0x00A5 -> bytes: 0xA5, 0x00)
        // RR: 1024 ticks (1000.0 ms -> bytes: 0x00, 0x04)
        val bytes = byteArrayOf(
            0x17.toByte(),
            0xA5.toByte(), 0x00.toByte(),
            0x00.toByte(), 0x04.toByte()
        )
        val sample = HeartRateParser.parse(bytes)

        assertThat(sample).isNotNull()
        assertThat(sample!!.bpm).isEqualTo(165)
        assertThat(sample.rrIntervalsMs).hasSize(1)
        assertThat(sample.rrIntervalsMs[0]).isWithin(1.0).of(1000.0)
    }

    @Test
    fun parse_zeroBpm_returnsNull() {
        val bytes = byteArrayOf(0x00.toByte(), 0.toByte())
        val sample = HeartRateParser.parse(bytes)
        assertThat(sample).isNull()
    }
}

