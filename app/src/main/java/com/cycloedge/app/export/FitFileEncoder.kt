package com.cycloedge.app.export

import com.cycloedge.app.data.local.entities.ActivityEntity
import com.cycloedge.app.data.local.entities.TrackpointEntity
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

/**
 * Pure binary Garmin FIT activity file encoder adhering to the Garmin FIT Protocol
 */
object FitFileEncoder {
    // FIT Epoch: 1989-12-31 00:00:00 UTC (631065600 seconds after Unix epoch)
    private const val FIT_EPOCH_OFFSET_SECONDS = 631065600L

    fun encodeAndSave(activity: ActivityEntity, trackpoints: List<TrackpointEntity>, outputFile: File): Boolean {
        return try {
            val dataStream = ByteArrayOutputStream()

            // 1. Write File ID Definition & Data Message
            writeFileIdMessage(dataStream, activity.startTimeMs)

            // 2. Write Event: Timer Start
            writeTimerEventMessage(dataStream, activity.startTimeMs, eventType = 0) // 0 = start

            // 3. Write 1 Hz Records
            for (tp in trackpoints) {
                writeRecordMessage(dataStream, tp)
            }

            // 4. Write Event: Timer Stop
            val endTimeMs = activity.endTimeMs ?: (activity.startTimeMs + activity.elapsedSeconds * 1000L)
            writeTimerEventMessage(dataStream, endTimeMs, eventType = 4) // 4 = stop_all

            val dataBytes = dataStream.toByteArray()

            // 5. Construct 14-byte FIT File Header
            val headerStream = ByteArrayOutputStream()
            headerStream.write(14) // Header size
            headerStream.write(0x20) // Protocol version 2.0
            writeUInt16LE(headerStream, 2100) // Profile version (21.00)
            writeUInt32LE(headerStream, dataBytes.size.toLong()) // Data size
            headerStream.write(".FIT".toByteArray(Charsets.US_ASCII))

            val headerBytesWithoutCrc = headerStream.toByteArray()
            val headerCrc = computeCrc16(headerBytesWithoutCrc)
            writeUInt16LE(headerStream, headerCrc)

            val fullHeaderBytes = headerStream.toByteArray()

            // 6. Compute Data CRC-16
            val dataCrc = computeCrc16(dataBytes)

            // 7. Write to File
            FileOutputStream(outputFile).use { fos ->
                fos.write(fullHeaderBytes)
                fos.write(dataBytes)
                // Write 2-byte CRC at end of file
                val crcBuffer = ByteArrayOutputStream()
                writeUInt16LE(crcBuffer, dataCrc)
                fos.write(crcBuffer.toByteArray())
            }

            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun writeFileIdMessage(stream: ByteArrayOutputStream, startTimeMs: Long) {
        // Definition Message: Local Msg 0, Global Msg 0 (File ID), 4 fields
        stream.write(0x40) // Definition message header
        stream.write(0)    // Reserved
        stream.write(0)    // Little endian
        writeUInt16LE(stream, 0) // Global Message Number: 0 (File ID)
        stream.write(4)    // 4 fields

        // Field 0: type (enum, 1 byte)
        stream.write(0); stream.write(1); stream.write(0)
        // Field 1: manufacturer (uint16, 2 bytes)
        stream.write(1); stream.write(2); stream.write(132)
        // Field 2: product (uint16, 2 bytes)
        stream.write(2); stream.write(2); stream.write(132)
        // Field 3: time_created (uint32, 4 bytes)
        stream.write(3); stream.write(4); stream.write(134)

        // Data Message
        stream.write(0x00) // Data message header (Local Msg 0)
        stream.write(4)    // Type: 4 (Activity)
        writeUInt16LE(stream, 1) // Manufacturer: Garmin/Development
        writeUInt16LE(stream, 1001) // Product ID
        val fitTimestamp = (startTimeMs / 1000L) - FIT_EPOCH_OFFSET_SECONDS
        writeUInt32LE(stream, fitTimestamp)
    }

    private fun writeTimerEventMessage(stream: ByteArrayOutputStream, timestampMs: Long, eventType: Int) {
        // Definition Message: Local Msg 1, Global Msg 21 (Event), 2 fields
        stream.write(0x41)
        stream.write(0)
        stream.write(0)
        writeUInt16LE(stream, 21) // Global Message Number: 21 (Event)
        stream.write(2)

        // Field 253: timestamp (uint32)
        stream.write(253); stream.write(4); stream.write(134)
        // Field 1: event_type (enum, 1 byte)
        stream.write(1); stream.write(1); stream.write(0)

        // Data Message
        stream.write(0x01)
        val fitTimestamp = (timestampMs / 1000L) - FIT_EPOCH_OFFSET_SECONDS
        writeUInt32LE(stream, fitTimestamp)
        stream.write(eventType)
    }

    private fun writeRecordMessage(stream: ByteArrayOutputStream, tp: TrackpointEntity) {
        // Definition Message: Local Msg 2, Global Msg 20 (Record), 7 fields
        stream.write(0x42)
        stream.write(0)
        stream.write(0)
        writeUInt16LE(stream, 20) // Global Message Number: 20 (Record)
        stream.write(7)

        // Field 253: timestamp (uint32)
        stream.write(253); stream.write(4); stream.write(134)
        // Field 0: position_lat (sint32, semicircles)
        stream.write(0); stream.write(4); stream.write(133)
        // Field 1: position_long (sint32, semicircles)
        stream.write(1); stream.write(4); stream.write(133)
        // Field 5: distance (uint32, 100 * meters)
        stream.write(5); stream.write(4); stream.write(134)
        // Field 73: enhanced_speed (uint32, 1000 * m/s)
        stream.write(73); stream.write(4); stream.write(134)
        // Field 3: heart_rate (uint8)
        stream.write(3); stream.write(1); stream.write(2)
        // Field 4: cadence (uint8)
        stream.write(4); stream.write(1); stream.write(2)

        // Data Message
        stream.write(0x02)
        val fitTimestamp = (tp.timestampMs / 1000L) - FIT_EPOCH_OFFSET_SECONDS
        writeUInt32LE(stream, fitTimestamp)

        // Semicircles: deg * (2^31 / 180)
        val latSemicircles = ((tp.latitude ?: 0.0) * (2147483648.0 / 180.0)).toLong().toInt()
        val lonSemicircles = ((tp.longitude ?: 0.0) * (2147483648.0 / 180.0)).toLong().toInt()
        writeSInt32LE(stream, latSemicircles)
        writeSInt32LE(stream, lonSemicircles)

        val distCm = (tp.distanceMeters * 100.0).toLong()
        writeUInt32LE(stream, distCm)

        val speedMmS = ((tp.speedMps ?: 0.0) * 1000.0).toLong()
        writeUInt32LE(stream, speedMmS)

        stream.write(tp.heartRate ?: 0)
        stream.write(tp.cadence ?: 0)
    }

    private fun writeUInt16LE(stream: ByteArrayOutputStream, value: Int) {
        stream.write(value and 0xFF)
        stream.write((value shr 8) and 0xFF)
    }

    private fun writeUInt32LE(stream: ByteArrayOutputStream, value: Long) {
        stream.write((value and 0xFF).toInt())
        stream.write(((value shr 8) and 0xFF).toInt())
        stream.write(((value shr 16) and 0xFF).toInt())
        stream.write(((value shr 24) and 0xFF).toInt())
    }

    private fun writeSInt32LE(stream: ByteArrayOutputStream, value: Int) {
        writeUInt32LE(stream, value.toLong())
    }

    // CCITT-CRC with polynomial 0x1021
    private fun computeCrc16(bytes: ByteArray): Int {
        var crc = 0
        for (b in bytes) {
            val byteVal = b.toInt() and 0xFF
            for (i in 0 until 8) {
                val bit = ((byteVal shr (7 - i)) and 1) == 1
                val c15 = ((crc shr 15) and 1) == 1
                crc = (crc shl 1) and 0xFFFF
                if (c15 xor bit) {
                    crc = crc xor 0x1021
                }
            }
        }
        return crc and 0xFFFF
    }
}

