import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum RelativeWindType {
  calm,
  headwind,
  tailwind,
  crosswindRight,
  crosswindLeft,
}

class WindData {
  final double windSpeedKmh;
  final double windDirectionDeg; // 0-360 meteorology (from direction)
  final double windGustsKmh;
  final double temperatureC;
  final int weatherCode;
  final DateTime timestamp;
  final double riderHeadingDeg;

  const WindData({
    required this.windSpeedKmh,
    required this.windDirectionDeg,
    required this.windGustsKmh,
    required this.temperatureC,
    required this.weatherCode,
    required this.timestamp,
    this.riderHeadingDeg = 0.0,
  });

  /// Relative angle of incoming wind compared to rider heading (0 - 360)
  /// 0 = wind blowing straight into rider face (Headwind)
  /// 180 = wind blowing from behind rider (Tailwind)
  /// 90 = wind blowing from rider right (Crosswind right)
  /// 270 = wind blowing from rider left (Crosswind left)
  double get relativeAngleDeg {
    return (windDirectionDeg - riderHeadingDeg + 360.0) % 360.0;
  }

  /// Angle for UI arrow pointing in the direction wind is blowing relative to rider
  /// 0 deg = pointing UP (Tailwind pushing forward)
  /// 180 deg = pointing DOWN (Headwind resisting)
  double get arrowVisualAngleDeg {
    return (relativeAngleDeg + 180.0) % 360.0;
  }

  RelativeWindType get windType {
    if (windSpeedKmh < 3.0) return RelativeWindType.calm;
    final rel = relativeAngleDeg;
    if (rel >= 315 || rel <= 45) return RelativeWindType.headwind;
    if (rel >= 135 && rel <= 225) return RelativeWindType.tailwind;
    if (rel > 45 && rel < 135) return RelativeWindType.crosswindRight;
    return RelativeWindType.crosswindLeft;
  }

  /// Effective speed component: positive = helping push (tailwind), negative = resisting (headwind)
  double get effectiveAssistKmh {
    if (windSpeedKmh < 2.0) return 0.0;
    final rad = relativeAngleDeg * (math.pi / 180.0);
    return -math.cos(rad) * windSpeedKmh;
  }

  String get label {
    switch (windType) {
      case RelativeWindType.calm:
        return 'Tenang';
      case RelativeWindType.headwind:
        return 'Headwind (Lawan)';
      case RelativeWindType.tailwind:
        return 'Tailwind (Dorong)';
      case RelativeWindType.crosswindRight:
        return 'Crosswind Kanan';
      case RelativeWindType.crosswindLeft:
        return 'Crosswind Kiri';
    }
  }

  String get weatherDescription {
    switch (weatherCode) {
      case 0:
        return 'Cerah';
      case 1:
      case 2:
        return 'Sebagian Berawan';
      case 3:
        return 'Mendung';
      case 45:
      case 48:
        return 'Berkabut';
      case 51:
      case 53:
      case 55:
        return 'Gerimis';
      case 61:
      case 63:
      case 65:
        return 'Hujan';
      case 80:
      case 81:
      case 82:
        return 'Hujan Lebat';
      case 95:
      case 96:
        return 'Badai Petir';
      default:
        return 'Berawan';
    }
  }

  WindData withHeading(double heading) {
    return WindData(
      windSpeedKmh: windSpeedKmh,
      windDirectionDeg: windDirectionDeg,
      windGustsKmh: windGustsKmh,
      temperatureC: temperatureC,
      weatherCode: weatherCode,
      timestamp: timestamp,
      riderHeadingDeg: heading,
    );
  }
}

class WeatherService extends ChangeNotifier {
  WindData? _currentWind;
  bool _isLoading = false;
  String? _lastError;
  DateTime? _lastFetchTime;
  LatLng? _lastFetchPosition;
  Timer? _autoRefreshTimer;

  // Interval configured to 10 minutes as requested
  static const Duration refreshInterval = Duration(minutes: 10);

  WindData? get currentWind => _currentWind;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  DateTime? get lastFetchTime => _lastFetchTime;

  WeatherService() {
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(refreshInterval, (timer) {
      if (_lastFetchPosition != null) {
        fetchWeather(_lastFetchPosition!, force: true);
      }
    });
  }

  /// Update rider heading continuously without re-fetching network
  void updateHeading(double riderHeading) {
    if (_currentWind != null && _currentWind!.riderHeadingDeg != riderHeading) {
      _currentWind = _currentWind!.withHeading(riderHeading);
      notifyListeners();
    }
  }

  /// Manually force refresh current location weather immediately
  Future<void> refreshCurrentLocation() async {
    if (_lastFetchPosition != null) {
      await fetchWeather(_lastFetchPosition!, force: true);
    }
  }

  /// Called on GPS update: checks if 10 minutes passed or moved > 5 km
  void onPositionUpdate(LatLng? position, double riderHeading) {
    if (position == null) return;

    updateHeading(riderHeading);

    final now = DateTime.now();
    bool shouldFetch = false;

    if (_lastFetchTime == null || _currentWind == null) {
      shouldFetch = true;
    } else if (now.difference(_lastFetchTime!) >= refreshInterval) {
      shouldFetch = true; // 10 minutes elapsed
    } else if (_lastFetchPosition != null) {
      // Check distance moved > 5 km
      final distKm = const Distance().as(
        LengthUnit.Kilometer,
        _lastFetchPosition!,
        position,
      );
      if (distKm >= 5.0) {
        shouldFetch = true;
      }
    }

    if (shouldFetch && !_isLoading) {
      fetchWeather(position);
    }
  }

  /// Fetch Open-Meteo API
  Future<void> fetchWeather(LatLng position, {bool force = false}) async {
    if (_isLoading) return;

    final now = DateTime.now();
    if (!force && _lastFetchTime != null && now.difference(_lastFetchTime!) < const Duration(seconds: 30)) {
      return; // prevent rapid spam
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${position.latitude.toStringAsFixed(4)}'
        '&longitude=${position.longitude.toStringAsFixed(4)}'
        '&current=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m'
        '&wind_speed_unit=kmh',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];

        final speed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
        final dir = (current['wind_direction_10m'] as num?)?.toDouble() ?? 0.0;
        final gusts = (current['wind_gusts_10m'] as num?)?.toDouble() ?? speed;
        final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 28.0;
        final code = (current['weather_code'] as num?)?.toInt() ?? 0;

        final currentHeading = _currentWind?.riderHeadingDeg ?? 0.0;

        _currentWind = WindData(
          windSpeedKmh: speed,
          windDirectionDeg: dir,
          windGustsKmh: gusts,
          temperatureC: temp,
          weatherCode: code,
          timestamp: now,
          riderHeadingDeg: currentHeading,
        );

        _lastFetchTime = now;
        _lastFetchPosition = position;
      } else {
        _lastError = 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('WeatherService error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
