import 'package:latlong2/latlong.dart';

class RoutePoint {
  final LatLng coordinate;
  final double elevation; // meters
  final DateTime? timestamp;

  const RoutePoint({
    required this.coordinate,
    this.elevation = 0.0,
    this.timestamp,
  });

  double get latitude => coordinate.latitude;
  double get longitude => coordinate.longitude;
}

class RouteData {
  final String name;
  final List<RoutePoint> points;
  final double totalDistanceKm;
  final double elevationGainM;
  final double minElevationM;
  final double maxElevationM;

  const RouteData({
    required this.name,
    required this.points,
    this.totalDistanceKm = 0.0,
    this.elevationGainM = 0.0,
    this.minElevationM = 0.0,
    this.maxElevationM = 0.0,
  });

  List<LatLng> get coordinates => points.map((p) => p.coordinate).toList();

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  LatLng? get startingPoint => points.isNotEmpty ? points.first.coordinate : null;
  LatLng? get endingPoint => points.isNotEmpty ? points.last.coordinate : null;
}

