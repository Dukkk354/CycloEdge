# Keep Room Entities and DAOs
-keep class androidx.room.** { *; }
-dontwarn androidx.room.**

# Keep MapLibre SDK
-keep class org.maplibre.android.** { *; }
-dontwarn org.maplibre.android.**

# Keep Garmin FIT SDK classes if bundled
-keep class com.garmin.fit.** { *; }

# Keep data models serialized with JSON
-keepclassmembers class com.cycloedge.app.domain.model.** { *; }

