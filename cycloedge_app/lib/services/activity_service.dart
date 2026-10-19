import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../models/activity_record.dart';

class ActivityService extends ChangeNotifier {
  final List<ActivityRecord> _activities = [];
  bool _isLoaded = false;

  List<ActivityRecord> get activities => List.unmodifiable(_activities);
  bool get isLoaded => _isLoaded;

  // Aggregate stats
  double get totalDistanceKm =>
      _activities.fold(0.0, (sum, a) => sum + a.distanceKm);
  Duration get totalDuration =>
      _activities.fold(Duration.zero, (sum, a) => sum + a.movingTime);
  int get totalCalories =>
      _activities.fold(0, (sum, a) => sum + a.calories);
  int get totalActivities => _activities.length;

  /// Current week distance (Monday to Sunday)
  double get currentWeekDistanceKm {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final mondayMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    return _activities
        .where((a) => a.startTime.isAfter(mondayMidnight))
        .fold(0.0, (sum, a) => sum + a.distanceKm);
  }

  // Personal Records (PRs)
  double get longestRideKm =>
      _activities.fold(0.0, (m, a) => math.max(m, a.distanceKm));

  double get maxSpeedEverKmh =>
      _activities.fold(0.0, (m, a) => math.max(m, a.maxSpeedKmh));

  double get maxElevationEverM =>
      _activities.fold(0.0, (m, a) => math.max(m, a.elevationGainM));

  double get fastestPaceMinPerKm {
    final runs = _activities.where((a) => a.avgPaceMinPerKm > 1.0).toList();
    if (runs.isEmpty) return 0.0;
    return runs.fold(999.0, (m, a) => math.min(m, a.avgPaceMinPerKm));
  }

  ActivityService() {
    loadActivities();
  }

  Future<void> loadActivities() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/cycloedge_activities.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _activities.clear();
        for (final item in jsonList) {
          _activities.add(ActivityRecord.fromJson(item as Map<String, dynamic>));
        }
      } else {
        // Add a demo activity to show preview
        _activities.add(ActivityRecord(
          id: 'demo_1',
          title: 'Gowes Pagi Dago Pakar',
          activityType: 'cycling',
          startTime: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          movingTime: const Duration(hours: 1, minutes: 14, seconds: 20),
          elapsedTime: const Duration(hours: 1, minutes: 22, seconds: 0),
          distanceKm: 24.8,
          avgSpeedKmh: 20.1,
          maxSpeedKmh: 48.5,
          avgPaceMinPerKm: 2.98,
          elevationGainM: 385.0,
          avgHr: 142,
          maxHr: 176,
          calories: 640,
          breadcrumbs: const [
            LatLng(-6.8915, 107.6107),
            LatLng(-6.8850, 107.6130),
            LatLng(-6.8720, 107.6150),
            LatLng(-6.8550, 107.6180),
            LatLng(-6.8400, 107.6200),
            LatLng(-6.8240, 107.6190),
            LatLng(-6.8120, 107.6175),
          ],
        ));
      }
    } catch (e) {
      debugPrint('Error loading activities: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> saveActivity(ActivityRecord activity) async {
    _activities.insert(0, activity); // newest first
    notifyListeners();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/cycloedge_activities.json');
      final jsonList = _activities.map((a) => a.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving activity: $e');
    }
  }

  Future<void> deleteActivity(String id) async {
    _activities.removeWhere((a) => a.id == id);
    notifyListeners();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/cycloedge_activities.json');
      final jsonList = _activities.map((a) => a.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error deleting activity: $e');
    }
  }
}
