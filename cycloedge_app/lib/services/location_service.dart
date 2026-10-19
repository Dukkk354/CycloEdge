import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/telemetry_data.dart';
import 'ble_service.dart';
import 'profile_service.dart';

class LocationService extends ChangeNotifier {
  // Gentle jitter filter: only ignore GPS micro-drift under 0.6 meters & < 0.5 km/h
  static const double stationaryJitterDistanceM = 0.6;
  static const double stationaryJitterSpeedMs = 0.15; // ~0.5 km/h
  static const double elevationGainThresholdMeters = 1.0; // 1m vertical resolution

  final BleService _bleService;
  final ProfileService? _profileService;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _oneSecondTimer;

  TelemetryData _telemetry = const TelemetryData();
  final List<LatLng> _breadcrumbs = [];
  final List<int> _hrHistory = [];

  Position? _lastPosition;
  double _lastValidElevation = 0.0;
  DateTime? _rideStartTime;

  TelemetryData get telemetry => _telemetry;

  LocationService({
    required BleService bleService,
    ProfileService? profileService,
  })  : _bleService = bleService,
        _profileService = profileService {
    _bleService.addListener(_onBleUpdate);
    _initLocation();
  }

  void setActivityType(String type) {
    _telemetry = _telemetry.copyWith(activityType: type);
    notifyListeners();
  }

  void _onBleUpdate() {
    final hr = _bleService.heartRate;
    if (_telemetry.isRecording && !_telemetry.isPaused && hr > 30) {
      _hrHistory.add(hr);
    }

    _telemetry = _telemetry.copyWith(
      heartRate: hr,
      cadence: _bleService.cadence,
      power: _bleService.power,
    );
    notifyListeners();
  }

  /// Request permissions and initialize GPS stream
  Future<bool> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      // Configure iOS & Android high-accuracy sports tracking
      LocationSettings locationSettings;
      if (Platform.isIOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          distanceFilter: 1,
        );
      } else if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          intervalDuration: const Duration(seconds: 1),
          distanceFilter: 1,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: "CycloEdge GPS Tracker",
            notificationText: "Tracking your workout in background",
            enableWakeLock: true,
          ),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1,
        );
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(_onPositionReceived);

      return true;
    } catch (e) {
      debugPrint('Location error: $e');
      return false;
    }
  }

  void _onPositionReceived(Position pos) {
    final currentCoord = LatLng(pos.latitude, pos.longitude);
    double filteredSpeedKmh = 0.0;

    if (_lastPosition != null) {
      final double distanceM = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );

      final dtMs = pos.timestamp.difference(_lastPosition!.timestamp).inMilliseconds;
      final dtSec = dtMs > 0 ? dtMs / 1000.0 : 1.0;

      // Speed directly from GPS chip (in m/s)
      double rawSpeedMs = pos.speed >= 0 ? pos.speed : 0.0;

      // If hardware speed is zero or low, but distance moved is significant, calculate from distance/time
      if (rawSpeedMs < 0.2 && distanceM > 0.6 && dtSec > 0.3) {
        rawSpeedMs = distanceM / dtSec;
      }

      // Suppress stationary GPS jitter (standing still)
      if (distanceM < stationaryJitterDistanceM && rawSpeedMs < stationaryJitterSpeedMs) {
        filteredSpeedKmh = 0.0;
      } else {
        filteredSpeedKmh = rawSpeedMs * 3.6; // convert m/s to km/h

        // Accumulate distance when actively recording and not paused
        if (_telemetry.isRecording && !_telemetry.isPaused) {
          final newDist = _telemetry.distanceKm + (distanceM / 1000.0);
          _breadcrumbs.add(currentCoord);

          // Elevation gain filter
          double newGain = _telemetry.elevationGain;
          if (_lastValidElevation != 0.0 && pos.altitude > _lastValidElevation) {
            final eleDiff = pos.altitude - _lastValidElevation;
            if (eleDiff >= elevationGainThresholdMeters) {
              newGain += eleDiff;
              _lastValidElevation = pos.altitude;
            }
          } else if (_lastValidElevation == 0.0) {
            _lastValidElevation = pos.altitude;
          }

          _telemetry = _telemetry.copyWith(
            distanceKm: newDist,
            elevationGain: newGain,
            breadcrumbs: List.unmodifiable(_breadcrumbs),
          );
        }
      }
    } else {
      _lastValidElevation = pos.altitude;
    }

    _lastPosition = pos;

    // Max speed tracking
    final newMaxSpeed = math.max(_telemetry.maxSpeed, filteredSpeedKmh);

    _telemetry = _telemetry.copyWith(
      speed: filteredSpeedKmh,
      maxSpeed: newMaxSpeed,
      elevation: pos.altitude,
      currentPosition: currentCoord,
      heading: pos.heading >= 0 ? pos.heading : 0.0,
    );

    notifyListeners();
  }

  /// Start or resume workout recording
  void startRecording() {
    if (_telemetry.rideState == RideState.recording) return;

    if (_telemetry.rideState == RideState.idle) {
      _rideStartTime = DateTime.now();
      _breadcrumbs.clear();
      _hrHistory.clear();
      _telemetry = _telemetry.copyWith(
        distanceKm: 0.0,
        elevationGain: 0.0,
        maxSpeed: 0.0,
        avgSpeed: 0.0,
        elapsedTime: Duration.zero,
        movingTime: Duration.zero,
        rideState: RideState.recording,
        breadcrumbs: [],
        calories: 0,
      );
    } else {
      _telemetry = _telemetry.copyWith(rideState: RideState.recording);
    }

    _oneSecondTimer?.cancel();
    _oneSecondTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_telemetry.rideState != RideState.recording) return;

      final newElapsed = _telemetry.elapsedTime + const Duration(seconds: 1);
      final newMoving = _telemetry.movingTime + const Duration(seconds: 1);

      // Calculate Average Speed
      double newAvg = 0.0;
      if (newMoving.inSeconds > 0) {
        newAvg = (_telemetry.distanceKm / (newMoving.inSeconds / 3600.0));
      }

      // Calculate Calories dynamically
      int calculatedCals = _telemetry.calories;
      if (_profileService != null) {
        int avgHr = 0;
        if (_hrHistory.isNotEmpty) {
          avgHr = (_hrHistory.reduce((a, b) => a + b) / _hrHistory.length).round();
        } else if (_telemetry.heartRate > 30) {
          avgHr = _telemetry.heartRate;
        }

        calculatedCals = _profileService.profile.calculateCalories(
          duration: newMoving,
          avgHr: avgHr,
          activityType: _telemetry.activityType,
          distanceKm: _telemetry.distanceKm,
        ).round();
      }

      _telemetry = _telemetry.copyWith(
        elapsedTime: newElapsed,
        movingTime: newMoving,
        avgSpeed: newAvg,
        calories: calculatedCals,
      );
      notifyListeners();
    });

    notifyListeners();
  }

  /// Pause recording manually
  void pauseRecording() {
    _telemetry = _telemetry.copyWith(rideState: RideState.paused);
    notifyListeners();
  }

  /// Reset workout data
  void stopAndResetRide() {
    _oneSecondTimer?.cancel();
    _breadcrumbs.clear();
    _hrHistory.clear();
    _telemetry = _telemetry.copyWith(
      rideState: RideState.idle,
      distanceKm: 0.0,
      elevationGain: 0.0,
      maxSpeed: 0.0,
      avgSpeed: 0.0,
      elapsedTime: Duration.zero,
      movingTime: Duration.zero,
      breadcrumbs: [],
      calories: 0,
    );
    notifyListeners();
  }

  DateTime? get rideStartTime => _rideStartTime;

  int get averageHeartRate {
    if (_hrHistory.isEmpty) return _telemetry.heartRate;
    return (_hrHistory.reduce((a, b) => a + b) / _hrHistory.length).round();
  }

  @override
  void dispose() {
    _bleService.removeListener(_onBleUpdate);
    _positionSubscription?.cancel();
    _oneSecondTimer?.cancel();
    super.dispose();
  }
}
