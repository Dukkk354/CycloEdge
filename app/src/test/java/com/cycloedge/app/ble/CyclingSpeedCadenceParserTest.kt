package com.cycloedge.app.ble

import com.cycloedge.app.domain.ble.CyclingSpeedCadenceParser
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class CyclingSpeedCadenceParserTest {

    @Test
    fun parse_wheelAndCrankData_computesSpeedAndCadence() {
        val parser = CyclingSpeedCadenceParser(wheelCircumferenceMeters = 2.1)

        // Sample 1: Baseline (Flags: 0x03 -> wheel & crank present)
        // Wheel: 100 revs, Time: 1024 ticks (1 sec)
        // Crank: 50 revs, Time: 1024 ticks (1 sec)
        val s1 = byteArrayOf(
            0x03.toByte(),
            100.toByte(), 0x00, 0x00, 0x00, // Wheel revs = 100
            0x00.toByte(), 0x04.toByte(),   // Wheel time = 1024
            50.toByte(), 0x00,              // Crank revs = 50
            0x00.toByte(), 0x04.toByte()    // Crank time = 1024
        )
        val sample1 = parser.parse(s1)
        assertThat(sample1).isNotNull()
        // First sample is baseline, so speed/cadence are null
        assertThat(sample1!!.speedMps).isNull()
        assertThat(sample1.cadenceRpm).isNull()

        // Sample 2: 1 second later (1024 ticks later = 2048 ticks = 0x0800)
        // Wheel: 104 revs (+4 revs in 1 sec -> speed = 4 * 2.1 / 1 = 8.4 m/s)
        // Crank: 51.5? (say 52 revs -> +2 revs in 1 sec -> cadence = 2 * 60 = 120 rpm)
        val s2 = byteArrayOf(
            0x03.toByte(),
            104.toByte(), 0x00, 0x00, 0x00, // Wheel revs = 104
            0x00.toByte(), 0x08.toByte(),   // Wheel time = 2048
            52.toByte(), 0x00,              // Crank revs = 52
            0x00.toByte(), 0x08.toByte()    // Crank time = 2048
        )
        val sample2 = parser.parse(s2)
        assertThat(sample2).isNotNull()
        assertThat(sample2!!.speedMps).isWithin(0.1).of(8.4) // 8.4 m/s = 30.24 km/h
        assertThat(sample2.cadenceRpm).isEqualTo(120)
    }

    @Test
    fun parse_timerRollover_computesCorrectly() {
        val parser = CyclingSpeedCadenceParser(wheelCircumferenceMeters = 2.1)

        // Baseline near 16-bit uint16 max: time = 65000 (0xFDE8)
        val s1 = byteArrayOf(
            0x01.toByte(), // Wheel only
            0x00.toByte(), 0x00, 0x00, 0x00,
            0xE8.toByte(), 0xFD.toByte() // 65000
        )
        parser.parse(s1)

        // Next: time rolled over past 65535 to 500 (delta = (500 - 65000 + 65536) = 1036 ticks ~ 1.0117 sec)
        // Wheel revs: +4
        val s2 = byteArrayOf(
            0x01.toByte(),
            0x04.toByte(), 0x00, 0x00, 0x00,
            0xF4.toByte(), 0x01.toByte() // 500
        )
        val sample2 = parser.parse(s2)
        assertThat(sample2).isNotNull()
        assertThat(sample2!!.speedMps).isNotNull()
        assertThat(sample2.speedMps!!).isGreaterThan(5.0)
    }
}

