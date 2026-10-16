package com.cycloedge.app.export

import com.cycloedge.app.data.local.entities.ActivityEntity
import com.cycloedge.app.data.local.entities.TrackpointEntity
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object GpxExporter {

    fun exportAndSave(activity: ActivityEntity, trackpoints: List<TrackpointEntity>, outputFile: File): Boolean {
        return try {
            val isoDateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }

            val sb = java.lang.StringBuilder()
            sb.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
            sb.append("<gpx version=\"1.1\" creator=\"CycloEdge Mobile Bike Computer\" ")
            sb.append("xmlns=\"http://www.topografix.com/GPX/1/1\" ")
            sb.append("xmlns:gpxtpx=\"http://www.garmin.com/xmlschemas/TrackPointExtension/v1\">\n")
            sb.append("  <metadata>\n")
            sb.append("    <name>${activity.title}</name>\n")
            sb.append("    <time>${isoDateFormat.format(Date(activity.startTimeMs))}</time>\n")
            sb.append("  </metadata>\n")
            sb.append("  <trk>\n")
            sb.append("    <name>${activity.title}</name>\n")
            sb.append("    <type>Cycling</type>\n")
            sb.append("    <trkseg>\n")

            for (tp in trackpoints) {
                if (tp.latitude != null && tp.longitude != null) {
                    sb.append("      <trkpt lat=\"${tp.latitude}\" lon=\"${tp.longitude}\">\n")
                    tp.elevationMeters?.let { elev ->
                        sb.append("        <ele>${String.format(Locale.US, "%.1f", elev)}</ele>\n")
                    }
                    sb.append("        <time>${isoDateFormat.format(Date(tp.timestampMs))}</time>\n")

                    if (tp.heartRate != null || tp.cadence != null || tp.powerWatts != null) {
                        sb.append("        <extensions>\n")
                        sb.append("          <gpxtpx:TrackPointExtension>\n")
                        tp.heartRate?.let { hr ->
                            sb.append("            <gpxtpx:hr>$hr</gpxtpx:hr>\n")
                        }
                        tp.cadence?.let { cad ->
                            sb.append("            <gpxtpx:cad>$cad</gpxtpx:cad>\n")
                        }
                        sb.append("          </gpxtpx:TrackPointExtension>\n")
                        tp.powerWatts?.let { pwr ->
                            sb.append("          <power>$pwr</power>\n")
                        }
                        sb.append("        </extensions>\n")
                    }

                    sb.append("      </trkpt>\n")
                }
            }

            sb.append("    </trkseg>\n")
            sb.append("  </trk>\n")
            sb.append("</gpx>\n")

            FileOutputStream(outputFile).use { fos ->
                fos.write(sb.toString().toByteArray(Charsets.UTF_8))
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}

