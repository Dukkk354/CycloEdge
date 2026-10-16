import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/route_data.dart';

enum MapThemeType { light, satellite, dark }

class MapViewWidget extends StatefulWidget {
  final LatLng? currentPosition;
  final double heading;
  final List<LatLng> breadcrumbs;
  final RouteData? gpxRoute;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const MapViewWidget({
    super.key,
    required this.currentPosition,
    required this.heading,
    required this.breadcrumbs,
    this.gpxRoute,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  State<MapViewWidget> createState() => _MapViewWidgetState();
}

class _MapViewWidgetState extends State<MapViewWidget> {
  final MapController _mapController = MapController();
  MapThemeType _currentTheme = MapThemeType.dark;
  bool _followRider = true;

  @override
  void didUpdateWidget(covariant MapViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_followRider && widget.currentPosition != null) {
      if (oldWidget.currentPosition != widget.currentPosition) {
        _mapController.move(widget.currentPosition!, _mapController.camera.zoom);
      }
    }
  }

  void _centerOnRider() {
    setState(() => _followRider = true);
    if (widget.currentPosition != null) {
      _mapController.move(widget.currentPosition!, 16.0);
    }
  }

  void _fitRoute() {
    if (widget.gpxRoute != null && widget.gpxRoute!.isNotEmpty) {
      setState(() => _followRider = false);
      final coords = widget.gpxRoute!.coordinates;
      final bounds = LatLngBounds.fromPoints(coords);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(32),
        ),
      );
    }
  }

  String _getTileUrl() {
    switch (_currentTheme) {
      case MapThemeType.light:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapThemeType.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapThemeType.dark:
        return 'https://a.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.currentPosition ??
        (widget.gpxRoute?.startingPoint ?? const LatLng(-6.8016, 107.6186));

    final polylines = <Polyline>[];

    // GPX Planned Route (Cyan)
    if (widget.gpxRoute != null && widget.gpxRoute!.isNotEmpty) {
      polylines.add(
        Polyline(
          points: widget.gpxRoute!.coordinates,
          strokeWidth: 4.5,
          color: const Color(0xFF00E5FF),
        ),
      );
    }

    // Live Rider Breadcrumbs (Electric Green)
    if (widget.breadcrumbs.isNotEmpty) {
      polylines.add(
        Polyline(
          points: widget.breadcrumbs,
          strokeWidth: 4.0,
          color: const Color(0xFF00E676),
        ),
      );
    }

    // Markers
    final markers = <Marker>[];

    if (widget.gpxRoute != null && widget.gpxRoute!.isNotEmpty) {
      final start = widget.gpxRoute!.startingPoint;
      if (start != null) {
        markers.add(
          Marker(
            point: start,
            width: 28,
            height: 28,
            child: const Icon(Icons.play_circle_fill, color: Color(0xFF00E676), size: 24),
          ),
        );
      }
      final end = widget.gpxRoute!.endingPoint;
      if (end != null) {
        markers.add(
          Marker(
            point: end,
            width: 28,
            height: 28,
            child: const Icon(Icons.flag_circle, color: Color(0xFFFF1744), size: 24),
          ),
        );
      }
    }

    // Rider Position Marker
    if (widget.currentPosition != null) {
      markers.add(
        Marker(
          point: widget.currentPosition!,
          width: 40,
          height: 40,
          child: Transform.rotate(
            angle: (widget.heading * (3.141592653589793 / 180.0)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF00E5FF), blurRadius: 6),
                    ],
                  ),
                ),
                const Icon(Icons.navigation, color: Colors.black, size: 10),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.isExpanded ? 0 : 12),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _followRider) {
                  setState(() => _followRider = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _getTileUrl(),
                userAgentPackageName: 'com.cycloedge.app',
                maxZoom: 19,
              ),
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),

          // Map Theme Switcher Bar (Terang, Satelit, Gelap) - Exact Preview.html Style
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildThemeButton('Terang', MapThemeType.light),
                  _buildThemeButton('Satelit', MapThemeType.satellite),
                  _buildThemeButton('Gelap', MapThemeType.dark),
                ],
              ),
            ),
          ),

          // Action Floating Buttons (Center & Fit Route & Fullscreen)
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSmallBtn(
                  icon: _followRider ? Icons.gps_fixed : Icons.gps_not_fixed,
                  iconColor: _followRider ? const Color(0xFF00E5FF) : Colors.white70,
                  onPressed: _centerOnRider,
                ),
                if (widget.gpxRoute != null && widget.gpxRoute!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildSmallBtn(
                    icon: Icons.alt_route,
                    iconColor: const Color(0xFF00E5FF),
                    onPressed: _fitRoute,
                  ),
                ],
                const SizedBox(width: 6),
                _buildSmallBtn(
                  icon: widget.isExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                  iconColor: Colors.white,
                  onPressed: widget.onToggleExpand,
                ),
              ],
            ),
          ),

          // Route info badge in bottom-left
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.82),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Text(
                widget.gpxRoute != null && widget.gpxRoute!.isNotEmpty
                    ? 'RUTE: ${widget.gpxRoute!.name.toUpperCase()} (${widget.gpxRoute!.totalDistanceKm.toStringAsFixed(1)} KM)'
                    : 'RUTE: SIAP GOWES / IMPORT GPX',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton(String label, MapThemeType theme) {
    final isSelected = _currentTheme == theme;
    return GestureDetector(
      onTap: () => setState(() => _currentTheme = theme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBtn({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
      ),
    );
  }
}
