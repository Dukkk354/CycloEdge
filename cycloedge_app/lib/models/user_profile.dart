import 'dart:math' as math;
import 'package:flutter/material.dart';

class UserProfile {
  final String name;
  final int age;
  final String gender; // 'male' or 'female'
  final double weightKg;
  final double heightCm;
  final int restingHr;
  final int? customMaxHr;
  final String defaultActivity; // 'cycling', 'running', 'walking'
  final String speedUnit; // 'km/h' or 'pace'
  final double weeklyGoalKm;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String? stravaAccessToken;
  final bool voiceCuesEnabled;
  final bool crashDetectionEnabled;

  const UserProfile({
    this.name = 'Atlet CycloEdge',
    this.age = 28,
    this.gender = 'male',
    this.weightKg = 70.0,
    this.heightCm = 175.0,
    this.restingHr = 60,
    this.customMaxHr,
    this.defaultActivity = 'cycling',
    this.speedUnit = 'km/h',
    this.weeklyGoalKm = 100.0,
    this.emergencyContactName = 'Kontak Darurat',
    this.emergencyContactPhone = '',
    this.stravaAccessToken,
    this.voiceCuesEnabled = true,
    this.crashDetectionEnabled = true,
  });

  /// Maximum Heart Rate calculation
  /// Using Tanaka formula: 208 - (0.7 * age) for general athletes
  int get maxHr {
    if (customMaxHr != null && customMaxHr! > 100) {
      return customMaxHr!;
    }
    return (208 - (0.7 * age)).round();
  }

  // ==========================================
  // Heart Rate Zones (5-Zone Standard Model)
  // ==========================================
  
  /// Zone 1: Active Recovery (50% - 60% Max HR)
  int get z1Min => (maxHr * 0.50).round();
  int get z1Max => (maxHr * 0.60).round();

  /// Zone 2: Aerobic / Endurance (60% - 70% Max HR)
  int get z2Min => z1Max;
  int get z2Max => (maxHr * 0.70).round();

  /// Zone 3: Tempo / Aerobic Power (70% - 80% Max HR)
  int get z3Min => z2Max;
  int get z3Max => (maxHr * 0.80).round();

  /// Zone 4: Lactate Threshold (80% - 90% Max HR)
  int get z4Min => z3Max;
  int get z4Max => (maxHr * 0.90).round();

  /// Zone 5: VO2 Max / Anaerobic (> 90% Max HR)
  int get z5Min => z4Max;
  int get z5Max => maxHr;

  /// Calculate zone number (1-5) for a given HR
  int calculateZone(int hr) {
    if (hr <= 0) return 0;
    if (hr < z2Min) return 1;
    if (hr < z3Min) return 2;
    if (hr < z4Min) return 3;
    if (hr < z5Min) return 4;
    return 5;
  }

  String getZoneName(int zone) {
    switch (zone) {
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
        return 'REST';
    }
  }

  Color getZoneColor(int zone) {
    switch (zone) {
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

  /// Calories burned calculation
  /// Keytel Metabolic Formula
  double calculateCalories({
    required Duration duration,
    required int avgHr,
    required String activityType,
    required double distanceKm,
  }) {
    final double hours = duration.inSeconds / 3600.0;
    if (hours <= 0) return 0.0;

    if (avgHr > 40) {
      final double calPerMin;
      if (gender.toLowerCase() == 'female') {
        calPerMin = ((-20.4022 + (0.4472 * avgHr) - (0.1263 * weightKg) + (0.074 * age)) / 4.184);
      } else {
        calPerMin = ((-55.0969 + (0.6309 * avgHr) + (0.1988 * weightKg) + (0.2017 * age)) / 4.184);
      }
      return math.max(0.0, calPerMin * (duration.inSeconds / 60.0));
    } else {
      double met = 8.0; // Cycling moderate
      if (activityType == 'walking') met = 3.5;
      if (activityType == 'running') met = 9.8;
      return math.max(0.0, met * weightKg * hours);
    }
  }

  UserProfile copyWith({
    String? name,
    int? age,
    String? gender,
    double? weightKg,
    double? heightCm,
    int? restingHr,
    int? customMaxHr,
    String? defaultActivity,
    String? speedUnit,
    double? weeklyGoalKm,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? stravaAccessToken,
    bool? voiceCuesEnabled,
    bool? crashDetectionEnabled,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      restingHr: restingHr ?? this.restingHr,
      customMaxHr: customMaxHr ?? this.customMaxHr,
      defaultActivity: defaultActivity ?? this.defaultActivity,
      speedUnit: speedUnit ?? this.speedUnit,
      weeklyGoalKm: weeklyGoalKm ?? this.weeklyGoalKm,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      stravaAccessToken: stravaAccessToken ?? this.stravaAccessToken,
      voiceCuesEnabled: voiceCuesEnabled ?? this.voiceCuesEnabled,
      crashDetectionEnabled: crashDetectionEnabled ?? this.crashDetectionEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'restingHr': restingHr,
      'customMaxHr': customMaxHr,
      'defaultActivity': defaultActivity,
      'speedUnit': speedUnit,
      'weeklyGoalKm': weeklyGoalKm,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'stravaAccessToken': stravaAccessToken,
      'voiceCuesEnabled': voiceCuesEnabled,
      'crashDetectionEnabled': crashDetectionEnabled,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? 'Atlet CycloEdge',
      age: (json['age'] as num?)?.toInt() ?? 28,
      gender: json['gender'] as String? ?? 'male',
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70.0,
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 175.0,
      restingHr: (json['restingHr'] as num?)?.toInt() ?? 60,
      customMaxHr: (json['customMaxHr'] as num?)?.toInt(),
      defaultActivity: json['defaultActivity'] as String? ?? 'cycling',
      speedUnit: json['speedUnit'] as String? ?? 'km/h',
      weeklyGoalKm: (json['weeklyGoalKm'] as num?)?.toDouble() ?? 100.0,
      emergencyContactName: json['emergencyContactName'] as String? ?? 'Kontak Darurat',
      emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '',
      stravaAccessToken: json['stravaAccessToken'] as String?,
      voiceCuesEnabled: json['voiceCuesEnabled'] as bool? ?? true,
      crashDetectionEnabled: json['crashDetectionEnabled'] as bool? ?? true,
    );
  }
}
