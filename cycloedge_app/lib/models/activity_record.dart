import 'package:latlong2/latlong.dart';

class ActivityRecord {
  final String id;
  final String title;
  final String activityType; // 'cycling', 'running', 'walking'
  final DateTime startTime;
  final Duration movingTime;
  final Duration elapsedTime;
  final double distanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double avgPaceMinPerKm;
  final double elevationGainM;
  final int avgHr;
  final int maxHr;
  final int calories;
  final List<LatLng> breadcrumbs;

  const ActivityRecord({
    required this.id,
    required this.title,
    this.activityType = 'cycling',
    required this.startTime,
    required this.movingTime,
    required this.elapsedTime,
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.avgPaceMinPerKm,
    required this.elevationGainM,
    required this.avgHr,
    required this.maxHr,
    required this.calories,
    required this.breadcrumbs,
  });

  String get formattedPace {
    if (avgPaceMinPerKm <= 0 || avgPaceMinPerKm > 99) return "--'--\"";
    final min = avgPaceMinPerKm.floor();
    final sec = ((avgPaceMinPerKm - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  String get formattedDuration {
    final hours = movingTime.inHours;
    final minutes = movingTime.inMinutes % 60;
    final seconds = movingTime.inSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'activityType': activityType,
      'startTime': startTime.toIso8601String(),
      'movingTimeMs': movingTime.inMilliseconds,
      'elapsedTimeMs': elapsedTime.inMilliseconds,
      'distanceKm': distanceKm,
      'avgSpeedKmh': avgSpeedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'avgPaceMinPerKm': avgPaceMinPerKm,
      'elevationGainM': elevationGainM,
      'avgHr': avgHr,
      'maxHr': maxHr,
      'calories': calories,
      'breadcrumbs': breadcrumbs
          .map((pt) => {'lat': pt.latitude, 'lon': pt.longitude})
          .toList(),
    };
  }

  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    final coords = (json['breadcrumbs'] as List<dynamic>?)
            ?.map((e) => LatLng(
                (e['lat'] as num).toDouble(), (e['lon'] as num).toDouble()))
            .toList() ??
        [];

    return ActivityRecord(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Sesi Olahraga',
      activityType: json['activityType'] as String? ?? 'cycling',
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ?? DateTime.now(),
      movingTime: Duration(milliseconds: (json['movingTimeMs'] as num?)?.toInt() ?? 0),
      elapsedTime: Duration(milliseconds: (json['elapsedTimeMs'] as num?)?.toInt() ?? 0),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      maxSpeedKmh: (json['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      avgPaceMinPerKm: (json['avgPaceMinPerKm'] as num?)?.toDouble() ?? 0.0,
      elevationGainM: (json['elevationGainM'] as num?)?.toDouble() ?? 0.0,
      avgHr: (json['avgHr'] as num?)?.toInt() ?? 0,
      maxHr: (json['maxHr'] as num?)?.toInt() ?? 0,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      breadcrumbs: coords,
    );
  }
}
