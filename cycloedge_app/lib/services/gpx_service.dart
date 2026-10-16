import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import '../models/route_data.dart';

class GpxService {
  static const Distance _distanceCalc = Distance();

  /// Parse GPX string into structured RouteData
  static RouteData parseGpx(String xmlContent, {String defaultName = 'Imported Route'}) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final gpx = document.rootElement;

      // Extract route name
      String routeName = defaultName;
      final nameNode = gpx.findAllElements('name').firstOrNull;
      if (nameNode != null && nameNode.innerText.trim().isNotEmpty) {
        routeName = nameNode.innerText.trim();
      }

      final List<RoutePoint> points = [];
      double totalDistanceMeters = 0.0;
      double elevationGainMeters = 0.0;
      double minEle = double.infinity;
      double maxEle = -double.infinity;
      double? lastEle;
      LatLng? lastCoord;

      // Find all track points (<trkpt>) or route points (<rtept>)
      var pointElements = gpx.findAllElements('trkpt').toList();
      if (pointElements.isEmpty) {
        pointElements = gpx.findAllElements('rtept').toList();
      }

      for (final elem in pointElements) {
        final latStr = elem.getAttribute('lat');
        final lonStr = elem.getAttribute('lon');
        if (latStr == null || lonStr == null) continue;

        final lat = double.tryParse(latStr);
        final lon = double.tryParse(lonStr);
        if (lat == null || lon == null) continue;

        double ele = 0.0;
        final eleNode = elem.findElements('ele').firstOrNull;
        if (eleNode != null) {
          ele = double.tryParse(eleNode.innerText) ?? 0.0;
        }

        DateTime? time;
        final timeNode = elem.findElements('time').firstOrNull;
        if (timeNode != null) {
          time = DateTime.tryParse(timeNode.innerText);
        }

        final currentCoord = LatLng(lat, lon);

        // Distance accumulator
        if (lastCoord != null) {
          final stepDist = _distanceCalc.as(LengthUnit.Meter, lastCoord, currentCoord);
          totalDistanceMeters += stepDist;
        }
        lastCoord = currentCoord;

        // Elevation metrics
        if (ele != 0.0) {
          minEle = math.min(minEle, ele);
          maxEle = math.max(maxEle, ele);

          if (lastEle != null) {
            final diff = ele - lastEle;
            // Filter noise < 1.0m
            if (diff > 1.0) {
              elevationGainMeters += diff;
            }
          }
          lastEle = ele;
        }

        points.add(RoutePoint(
          coordinate: currentCoord,
          elevation: ele,
          timestamp: time,
        ));
      }

      if (minEle == double.infinity) minEle = 0.0;
      if (maxEle == -double.infinity) maxEle = 0.0;

      return RouteData(
        name: routeName,
        points: points,
        totalDistanceKm: totalDistanceMeters / 1000.0,
        elevationGainM: elevationGainMeters,
        minElevationM: minEle,
        maxElevationM: maxEle,
      );
    } catch (e) {
      // Return empty route on error
      return RouteData(
        name: defaultName,
        points: [],
      );
    }
  }

  /// Export recorded points to standard GPX 1.1 format
  static String exportToGpx({
    required String activityName,
    required List<LatLng> coordinates,
    required DateTime startTime,
    double totalDistanceKm = 0.0,
    double elevationGainM = 0.0,
  }) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('gpx', attributes: {
      'version': '1.1',
      'creator': 'CycloEdge GPS Bike Computer',
      'xmlns': 'http://www.topografix.com/GPX/1/1',
      'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
      'xsi:schemaLocation':
          'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd',
    }, nest: () {
      builder.element('metadata', nest: () {
        builder.element('name', nest: activityName);
        builder.element('time', nest: startTime.toUtc().toIso8601String());
      });

      builder.element('trk', nest: () {
        builder.element('name', nest: activityName);
        builder.element('type', nest: 'Cycling');
        builder.element('trkseg', nest: () {
          for (int i = 0; i < coordinates.length; i++) {
            final pt = coordinates[i];
            builder.element('trkpt', attributes: {
              'lat': pt.latitude.toStringAsFixed(6),
              'lon': pt.longitude.toStringAsFixed(6),
            }, nest: () {
              builder.element('ele', nest: '0.0');
              builder.element(
                'time',
                nest: startTime.add(Duration(seconds: i)).toUtc().toIso8601String(),
              );
            });
          }
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }
}

