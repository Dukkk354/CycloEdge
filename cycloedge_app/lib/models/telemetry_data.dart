import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum RideState { idle, recording, paused }

class TelemetryData {
  final double speed; // km/h
  final double maxSpeed; // km/h
  final double avgSpeed; // km/h
  final int cadence; // RPM (or steps/min for running/walking)
  final int heartRate; // BPM
  final int power; // Watts
  final double distanceKm; // km
  final double elevation; // meters
  final double elevationGain; // meters
  final Duration elapsedTime;
  final Duration movingTime;
  final RideState rideState;
  final LatLng? currentPosition;
  final double heading; // degrees (0-360)
  final List<LatLng> breadcrumbs;
  final String activityType; // 'cycling', 'running', 'walking'
  final int calories; // kcal

  const TelemetryData({
    this.speed = 0.0,
    this.maxSpeed = 0.0,
    this.avgSpeed = 0.0,
    this.cadence = 0,
    this.heartRate = 0,
    this.power = 0,
    this.distanceKm = 0.0,
    this.elevation = 0.0,
    this.elevationGain = 0.0,
    this.elapsedTime = Duration.zero,
    this.movingTime = Duration.zero,
    this.rideState = RideState.idle,
    this.currentPosition,
    this.heading = 0.0,
    this.breadcrumbs = const [],
    this.activityType = 'cycling',
    this.calories = 0,
  });

  bool get isRecording => rideState == RideState.recording;
  bool get isPaused => rideState == RideState.paused;

  /// Current Pace in minutes per kilometer
  double get paceMinutesPerKm {
    if (speed < 0.4) return 0.0;
    return 60.0 / speed;
  }

  /// Formatted Live Pace string (e.g. 5'32" /km or --'--")
  String get formattedPace {
    if (speed < 0.4 || paceMinutesPerKm <= 0 || paceMinutesPerKm > 99) {
      return "--'--\"";
    }
    final min = paceMinutesPerKm.floor();
    final sec = ((paceMinutesPerKm - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  /// Average Pace in minutes per kilometer
  double get avgPaceMinutesPerKm {
    if (avgSpeed < 0.4) return 0.0;
    return 60.0 / avgSpeed;
  }

  /// Formatted Average Pace string
  String get formattedAvgPace {
    if (avgSpeed < 0.4 || avgPaceMinutesPerKm <= 0 || avgPaceMinutesPerKm > 99) {
      return "--'--\"";
    }
    final min = avgPaceMinutesPerKm.floor();
    final sec = ((avgPaceMinutesPerKm - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  /// Heart Rate Zone (Standard 5-zone model)
  int get hrZone {
    if (heartRate <= 0) return 0;
    if (heartRate < 114) return 1; // < 60%
    if (heartRate < 133) return 2; // 60-70% (Aerobic / Endurance)
    if (heartRate < 152) return 3; // 70-80% (Tempo)
    if (heartRate < 171) return 4; // 80-90% (Threshold)
    return 5; // > 90% (VO2 Max / Anaerobic)
  }

  String get hrZoneName {
    switch (hrZone) {
      case 1:
        return 'Z1 RECOVERY';
      case 2:
        return 'Z2 ENDURANCE';
      case 3:
        return 'Z3 TEMPO';
      case 4:
        return 'Z4 THRESHOLD';
      case 5:
        return 'Z5 VO2 MAX';
      default:
        return 'HR REST';
    }
  }

  Color get hrZoneColor {
    switch (hrZone) {
      case 1:
        return const Color(0xFF64B5F6); // Soft Blue
      case 2:
        return const Color(0xFF00E5FF); // Electric Cyan
      case 3:
        return const Color(0xFF00E676); // Neon Green
      case 4:
        return const Color(0xFFFFB300); // Amber / Orange
      case 5:
        return const Color(0xFFFF1744); // Racing Red
      default:
        return const Color(0xFF757575); // Grey
    }
  }

  TelemetryData copyWith({
    double? speed,
    double? maxSpeed,
    double? avgSpeed,
    int? cadence,
    int? heartRate,
    int? power,
    double? distanceKm,
    double? elevation,
    double? elevationGain,
    Duration? elapsedTime,
    Duration? movingTime,
    RideState? rideState,
    LatLng? currentPosition,
    double? heading,
    List<LatLng>? breadcrumbs,
    String? activityType,
    int? calories,
  }) {
    return TelemetryData(
      speed: speed ?? this.speed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      cadence: cadence ?? this.cadence,
      heartRate: heartRate ?? this.heartRate,
      power: power ?? this.power,
      distanceKm: distanceKm ?? this.distanceKm,
      elevation: elevation ?? this.elevation,
      elevationGain: elevationGain ?? this.elevationGain,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      movingTime: movingTime ?? this.movingTime,
      rideState: rideState ?? this.rideState,
      currentPosition: currentPosition ?? this.currentPosition,
      heading: heading ?? this.heading,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      activityType: activityType ?? this.activityType,
      calories: calories ?? this.calories,
    );
  }
}
