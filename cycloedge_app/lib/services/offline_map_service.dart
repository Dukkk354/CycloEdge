import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

class OfflineMapService extends ChangeNotifier {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _downloadedCount = 0;
  int _totalTiles = 0;
  int _cachedTileCount = 0;

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  int get downloadedCount => _downloadedCount;
  int get totalTiles => _totalTiles;
  int get cachedTileCount => _cachedTileCount;

  OfflineMapService() {
    _refreshCacheCount();
  }

  Future<void> _refreshCacheCount() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final tileDir = Directory('${dir.path}/offline_tiles');
      if (await tileDir.exists()) {
        final files = tileDir.listSync(recursive: true).whereType<File>();
        _cachedTileCount = files.length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error counting cached tiles: $e');
    }
  }

  /// Download and cache map tiles covering coordinates at zoom levels 13-15
  Future<void> cacheRouteArea(List<LatLng> coords, {int minZoom = 13, int maxZoom = 15}) async {
    if (coords.isEmpty || _isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadedCount = 0;
    notifyListeners();

    try {
      double minLat = coords.first.latitude;
      double maxLat = coords.first.latitude;
      double minLon = coords.first.longitude;
      double maxLon = coords.first.longitude;

      for (final pt in coords) {
        if (pt.latitude < minLat) minLat = pt.latitude;
        if (pt.latitude > maxLat) maxLat = pt.latitude;
        if (pt.longitude < minLon) minLon = pt.longitude;
        if (pt.longitude > maxLon) maxLon = pt.longitude;
      }

      // Add a margin around route
      const pad = 0.015; // ~1.5 km margin
      minLat -= pad;
      maxLat += pad;
      minLon -= pad;
      maxLon += pad;

      final dir = await getApplicationDocumentsDirectory();
      final baseDir = Directory('${dir.path}/offline_tiles');
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final List<Map<String, int>> tileQueue = [];

      for (int z = minZoom; z <= maxZoom; z++) {
        final minTile = _latLngToTile(minLat, minLon, z);
        final maxTile = _latLngToTile(maxLat, maxLon, z);

        final xStart = math.min(minTile['x']!, maxTile['x']!);
        final xEnd = math.max(minTile['x']!, maxTile['x']!);
        final yStart = math.min(minTile['y']!, maxTile['y']!);
        final yEnd = math.max(minTile['y']!, maxTile['y']!);

        for (int x = xStart; x <= xEnd; x++) {
          for (int y = yStart; y <= yEnd; y++) {
            tileQueue.add({'z': z, 'x': x, 'y': y});
          }
        }
      }

      // Limit max tiles to 300 to avoid excessive downloads
      _totalTiles = math.min(300, tileQueue.length);
      notifyListeners();

      for (int i = 0; i < _totalTiles; i++) {
        final t = tileQueue[i];
        final z = t['z']!;
        final x = t['x']!;
        final y = t['y']!;

        final localFile = File('${baseDir.path}/$z/$x/$y.png');
        if (!await localFile.exists()) {
          final url = 'https://a.basemaps.cartocdn.com/rastertiles/voyager/$z/$x/$y.png';
          try {
            final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
            if (res.statusCode == 200) {
              await localFile.parent.create(recursive: true);
              await localFile.writeAsBytes(res.bodyBytes);
            }
          } catch (_) {}
        }

        _downloadedCount++;
        _downloadProgress = _downloadedCount / _totalTiles;
        notifyListeners();
      }

      await _refreshCacheCount();
    } catch (e) {
      debugPrint('Error caching offline map: $e');
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Map<String, int> _latLngToTile(double lat, double lon, int zoom) {
    final n = math.pow(2.0, zoom);
    final x = ((lon + 180.0) / 360.0 * n).floor();
    final latRad = lat * math.pi / 180.0;
    final y = ((1.0 - math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) / math.pi) / 2.0 * n).floor();
    return {'x': x, 'y': y};
  }

  Future<void> clearCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final tileDir = Directory('${dir.path}/offline_tiles');
      if (await tileDir.exists()) {
        await tileDir.delete(recursive: true);
      }
      _cachedTileCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
