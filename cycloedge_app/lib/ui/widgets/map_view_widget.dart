import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/route_data.dart';

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
  bool _useDarkMap = true;
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
          padding: const EdgeInsets.all(40),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Default initial location: rider position or Bandung / Lembang default
    final initialCenter = widget.currentPosition ??
        (widget.gpxRoute?.startingPoint ?? const LatLng(-6.8016, 107.6186));

    final polylines = <Polyline>[];

    // 1. GPX Planned Route (Electric Cyan)
    if (widget.gpxRoute != null && widget.gpxRoute!.isNotEmpty) {
      polylines.add(
        Polyline(
          points: widget.gpxRoute!.coordinates,
          strokeWidth: 4.5,
          color: const Color(0xFF00E5FF),
        ),
      );
    }

    // 2. Rider Breadcrumbs (Neon Green)
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

    // GPX Start & End pins
    if (widget.gpxRoute != null && widget.gpxRoute!.isNotEmpty) {
      final start = widget.gpxRoute!.startingPoint;
      if (start != null) {
        markers.add(
          Marker(
            point: start,
            width: 32,
            height: 32,
            child: const Icon(Icons.play_circle_fill, color: Color(0xFF00E676), size: 28),
          ),
        );
      }

      final end = widget.gpxRoute!.endingPoint;
      if (end != null) {
        markers.add(
          Marker(
            point: end,
            width: 32,
            height: 32,
            child: const Icon(Icons.flag_circle, color: Color(0xFFFF1744), size: 28),
          ),
        );
      }
    }

    // Current Rider Marker
    if (widget.currentPosition != null) {
      markers.add(
        Marker(
          point: widget.currentPosition!,
          width: 44,
          height: 44,
          child: Transform.rotate(
            angle: (widget.heading * (3.141592653589793 / 180.0)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF00E5FF), blurRadius: 8),
                    ],
                  ),
                ),
                const Icon(
                  Icons.navigation,
                  color: Colors.black,
                  size: 12,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tileUrl = _useDarkMap
        ? 'https://a.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.isExpanded ? 0 : 16),
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
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.cycloedge.app',
                maxZoom: 19,
              ),
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),

          // Map Control Buttons (Floating)
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                _buildMapButton(
                  icon: widget.isExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                  onPressed: widget.onToggleExpand,
                  tooltip: widget.isExpanded ? 'Minimize Map' : 'Full Map',
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: _followRider ? Icons.gps_fixed : Icons.gps_not_fixed,
                  iconColor: _followRider ? const Color(0xFF00E5FF) : Colors.white,
                  onPressed: _centerOnRider,
                  tooltip: 'Center on Me',
                ),
                if (widget.gpxRoute != null && widget.gpxRoute!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildMapButton(
                    icon: Icons.alt_route,
                    onPressed: _fitRoute,
                    tooltip: 'Fit GPX Route',
                  ),
                ],
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: _useDarkMap ? Icons.dark_mode : Icons.light_mode,
                  onPressed: () => setState(() => _useDarkMap = !_useDarkMap),
                  tooltip: 'Toggle Map Theme',
                ),
              ],
            ),
          ),

          // Route info badge if GPX loaded
          if (widget.gpxRoute != null && widget.gpxRoute!.isNotEmpty)
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.gpxRoute!.name} • ${widget.gpxRoute!.totalDistanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color iconColor = Colors.white,
    String? tooltip,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.92),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: IconButton(
        iconSize: 18,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}

