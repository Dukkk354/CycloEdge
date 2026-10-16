import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/telemetry_data.dart';
import 'ble_service.dart';

class LocationService extends ChangeNotifier {
  static const double autoPauseThresholdKmh = 2.0; // km/h
  static const double deadbandSpeedThresholdMs = 0.55; // ~2.0 km/h
  static const double deadbandDistanceMeters = 2.5; // ignore GPS jitter < 2.5m
  static const double elevationGainThresholdMeters = 1.5; // vertical filter

  final BleService _bleService;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _oneSecondTimer;

  TelemetryData _telemetry = const TelemetryData();
  final List<LatLng> _breadcrumbs = [];

  Position? _lastPosition;
  double _lastValidElevation = 0.0;
  DateTime? _rideStartTime;
  bool _autoPauseEnabled = true;

  TelemetryData get telemetry => _telemetry;
  bool get autoPauseEnabled => _autoPauseEnabled;

  LocationService({required BleService bleService}) : _bleService = bleService {
    _bleService.addListener(_onBleUpdate);
    _initLocation();
  }

  void setAutoPause(bool enabled) {
    _autoPauseEnabled = enabled;
    notifyListeners();
  }

  void _onBleUpdate() {
    _telemetry = _telemetry.copyWith(
      heartRate: _bleService.heartRate,
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

      // Configure iOS & Android background navigation settings
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
            notificationText: "Tracking your cycling ride in background",
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

    // Apply Stationary Deadband Filter (ZUPT)
    if (_lastPosition != null) {
      final double distanceM = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );

      // Raw speed from GPS chip (in m/s)
      final rawSpeedMs = pos.speed >= 0 ? pos.speed : 0.0;

      if (rawSpeedMs < deadbandSpeedThresholdMs || distanceM < deadbandDistanceMeters) {
        // Stationary: clamp speed to 0 to prevent GPS drift
        filteredSpeedKmh = 0.0;
      } else {
        filteredSpeedKmh = rawSpeedMs * 3.6; // convert m/s to km/h

        // Accumulate distance only when actively recording and moving
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

    // Auto-Pause logic
    bool shouldAutoPause = false;
    if (_telemetry.isRecording && _autoPauseEnabled) {
      if (filteredSpeedKmh < autoPauseThresholdKmh) {
        shouldAutoPause = true;
      }
    }

    // Max speed tracking
    final newMaxSpeed = math.max(_telemetry.maxSpeed, filteredSpeedKmh);

    _telemetry = _telemetry.copyWith(
      speed: filteredSpeedKmh,
      maxSpeed: newMaxSpeed,
      elevation: pos.altitude,
      currentPosition: currentCoord,
      heading: pos.heading >= 0 ? pos.heading : 0.0,
      isAutoPaused: shouldAutoPause,
    );

    notifyListeners();
  }

  /// Start or resume ride recording
  void startRecording() {
    if (_telemetry.rideState == RideState.recording) return;

    if (_telemetry.rideState == RideState.idle) {
      _rideStartTime = DateTime.now();
      _breadcrumbs.clear();
      _telemetry = _telemetry.copyWith(
        distanceKm: 0.0,
        elevationGain: 0.0,
        maxSpeed: 0.0,
        avgSpeed: 0.0,
        elapsedTime: Duration.zero,
        movingTime: Duration.zero,
        rideState: RideState.recording,
        breadcrumbs: [],
      );
    } else {
      _telemetry = _telemetry.copyWith(rideState: RideState.recording);
    }

    _oneSecondTimer?.cancel();
    _oneSecondTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_telemetry.rideState != RideState.recording) return;

      final newElapsed = _telemetry.elapsedTime + const Duration(seconds: 1);
      Duration newMoving = _telemetry.movingTime;

      // Only advance moving time if not auto-paused
      if (!_telemetry.isAutoPaused) {
        newMoving += const Duration(seconds: 1);
      }

      // Calculate Average Speed
      double newAvg = 0.0;
      if (newMoving.inSeconds > 0) {
        newAvg = (_telemetry.distanceKm / (newMoving.inSeconds / 3600.0));
      }

      _telemetry = _telemetry.copyWith(
        elapsedTime: newElapsed,
        movingTime: newMoving,
        avgSpeed: newAvg,
      );
      notifyListeners();
    });

    notifyListeners();
  }

  /// Pause recording
  void pauseRecording() {
    _telemetry = _telemetry.copyWith(rideState: RideState.paused);
    notifyListeners();
  }

  /// Reset ride data
  void stopAndResetRide() {
    _oneSecondTimer?.cancel();
    _breadcrumbs.clear();
    _telemetry = _telemetry.copyWith(
      rideState: RideState.idle,
      isAutoPaused: false,
      distanceKm: 0.0,
      elevationGain: 0.0,
      maxSpeed: 0.0,
      avgSpeed: 0.0,
      elapsedTime: Duration.zero,
      movingTime: Duration.zero,
      breadcrumbs: [],
    );
    notifyListeners();
  }

  DateTime? get rideStartTime => _rideStartTime;

  @override
  void dispose() {
    _bleService.removeListener(_onBleUpdate);
    _positionSubscription?.cancel();
    _oneSecondTimer?.cancel();
    super.dispose();
  }
}

