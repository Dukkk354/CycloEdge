import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/route_data.dart';
import '../models/telemetry_data.dart';
import '../services/ble_service.dart';
import '../services/gpx_service.dart';
import '../services/location_service.dart';
import 'sensor_modal.dart';
import 'widgets/map_view_widget.dart';
import 'widgets/rain_lock_overlay.dart';

class CockpitScreen extends StatefulWidget {
  final LocationService locationService;
  final BleService bleService;

  const CockpitScreen({
    super.key,
    required this.locationService,
    required this.bleService,
  });

  @override
  State<CockpitScreen> createState() => _CockpitScreenState();
}

class _CockpitScreenState extends State<CockpitScreen> {
  RouteData? _importedRoute;
  bool _isRainLocked = false;
  bool _isMapFullscreen = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.locationService, widget.bleService]),
      builder: (context, _) {
        final telemetry = widget.locationService.telemetry;
        final connectedCount = widget.bleService.connectedSensors.length;

        return Scaffold(
          backgroundColor: Colors.black, // Pure AMOLED Black
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    // Top Status Bar (Clock, GPS, BLE, GPX, Rain Lock)
                    _buildTopBar(telemetry, connectedCount),

                    // Main Content (Split between Cockpit & Map)
                    Expanded(
                      child: _isMapFullscreen
                          ? _buildFullscreenMap(telemetry)
                          : _buildSplitCockpit(telemetry),
                    ),

                    // Bottom Floating Cycling Controls
                    _buildBottomControlBar(telemetry),
                  ],
                ),

                // Rain & Sweat Lock Overlay Shield
                if (_isRainLocked)
                  RainLockOverlay(
                    onUnlock: () {
                      setState(() => _isRainLocked = false);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Top Bar with Status Icons and Quick Action Buttons
  Widget _buildTopBar(TelemetryData telemetry, int connectedSensorsCount) {
    final timeStr = DateFormat('HH:mm').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Time & GPS Indicator
          Row(
            children: [
              Text(
                timeStr,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: telemetry.currentPosition != null
                      ? const Color(0xFF00E676)
                      : Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                telemetry.currentPosition != null ? 'GPS 3D' : 'SEARCHING',
                style: TextStyle(
                  color: telemetry.currentPosition != null
                      ? const Color(0xFF00E676)
                      : Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Action Pills: BLE, GPX, Rain Lock
          Row(
            children: [
              // BLE Sensors Pill
              GestureDetector(
                onTap: () => SensorModal.show(context, widget.bleService),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: connectedSensorsCount > 0
                        ? const Color(0xFF00E5FF).withOpacity(0.15)
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: connectedSensorsCount > 0
                          ? const Color(0xFF00E5FF)
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bluetooth,
                        size: 14,
                        color: connectedSensorsCount > 0
                            ? const Color(0xFF00E5FF)
                            : Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        connectedSensorsCount > 0 ? '$connectedSensorsCount SENSORS' : 'BLE',
                        style: TextStyle(
                          color: connectedSensorsCount > 0
                              ? const Color(0xFF00E5FF)
                              : Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // GPX Route Button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.folder_open,
                  color: _importedRoute != null ? const Color(0xFF00E5FF) : Colors.white70,
                  size: 20,
                ),
                tooltip: 'Import GPX Route',
                onPressed: _pickGpxFile,
              ),

              // Rain & Sweat Lock Button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.water_drop_outlined, color: Colors.white70, size: 20),
                tooltip: 'Rain & Sweat Lock',
                onPressed: () {
                  setState(() => _isRainLocked = true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Split Cockpit (Large Speed, HR Zones, Metrics Grid, Integrated Map)
  Widget _buildSplitCockpit(TelemetryData telemetry) {
    return Column(
      children: [
        // 1. Massive Speed Readout
        _buildSpeedDisplay(telemetry),

        // 2. HR Zone Bar
        _buildHrZoneBar(telemetry),

        // 3. Telemetry Metrics Grid
        _buildMetricsGrid(telemetry),

        const SizedBox(height: 8),

        // 4. Map Container (Takes remaining height)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: MapViewWidget(
              currentPosition: telemetry.currentPosition,
              heading: telemetry.heading,
              breadcrumbs: telemetry.breadcrumbs,
              gpxRoute: _importedRoute,
              isExpanded: false,
              onToggleExpand: () {
                setState(() => _isMapFullscreen = true);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Fullscreen Map with Floating Mini HUD
  Widget _buildFullscreenMap(TelemetryData telemetry) {
    return Stack(
      children: [
        MapViewWidget(
          currentPosition: telemetry.currentPosition,
          heading: telemetry.heading,
          breadcrumbs: telemetry.breadcrumbs,
          gpxRoute: _importedRoute,
          isExpanded: true,
          onToggleExpand: () {
            setState(() => _isMapFullscreen = false);
          },
        ),

        // Mini HUD Floating Card
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SPEED', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(
                      telemetry.speed.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DIST (KM)', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(
                      telemetry.distanceKm.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HR (BPM)', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(
                      telemetry.heartRate > 0 ? '${telemetry.heartRate}' : '--',
                      style: TextStyle(
                        color: telemetry.hrZoneColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Huge High-Contrast Speedometer Typography
  Widget _buildSpeedDisplay(TelemetryData telemetry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                telemetry.speed.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 78,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'KM/H',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'MAX: ${telemetry.maxSpeed.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(width: 16),
              Text(
                'AVG: ${telemetry.avgSpeed.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              if (telemetry.isAutoPaused) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AUTO PAUSED',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Heart Rate Zones Z1-Z5 Bar
  Widget _buildHrZoneBar(TelemetryData telemetry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite, color: telemetry.hrZoneColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    telemetry.heartRate > 0 ? '${telemetry.heartRate} BPM' : '-- BPM',
                    style: TextStyle(
                      color: telemetry.hrZoneColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                telemetry.hrZoneName,
                style: TextStyle(
                  color: telemetry.hrZoneColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(5, (index) {
              final zone = index + 1;
              final isActive = telemetry.hrZone == zone;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? telemetry.hrZoneColor
                        : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 4-card Telemetry Grid: Cadence, Power, Distance, Moving Time
  Widget _buildMetricsGrid(TelemetryData telemetry) {
    final hours = telemetry.movingTime.inHours.toString().padLeft(2, '0');
    final minutes = (telemetry.movingTime.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (telemetry.movingTime.inSeconds % 60).toString().padLeft(2, '0');
    final timeFormatted = telemetry.movingTime.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              label: 'CADENCE',
              value: telemetry.cadence > 0 ? '${telemetry.cadence}' : '--',
              unit: 'RPM',
              accentColor: const Color(0xFF00E676),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricCard(
              label: 'POWER',
              value: telemetry.power > 0 ? '${telemetry.power}' : '--',
              unit: 'W',
              accentColor: const Color(0xFFFFB300),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricCard(
              label: 'DISTANCE',
              value: telemetry.distanceKm.toStringAsFixed(2),
              unit: 'KM',
              accentColor: const Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricCard(
              label: 'TIME',
              value: timeFormatted,
              unit: '',
              accentColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String unit,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: const TextStyle(color: Colors.white38, fontSize: 8),
            ),
        ],
      ),
    );
  }

  /// Bottom Ride Recording Controls
  Widget _buildBottomControlBar(TelemetryData telemetry) {
    final isRecording = telemetry.isRecording;
    final isPaused = telemetry.isPaused;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reset / Save GPX Button (if recorded points exist)
          if (telemetry.breadcrumbs.isNotEmpty || telemetry.rideState != RideState.idle)
            IconButton(
              icon: const Icon(Icons.share, color: Color(0xFF00E5FF)),
              tooltip: 'Export GPX Ride',
              onPressed: () => _exportRideGpx(telemetry),
            ),

          // Primary Record / Pause Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isRecording
                  ? (isPaused ? const Color(0xFF00E676) : Colors.amber)
                  : const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              elevation: 4,
            ),
            onPressed: () {
              if (isRecording && !isPaused) {
                widget.locationService.pauseRecording();
              } else {
                widget.locationService.startRecording();
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRecording
                      ? (isPaused ? Icons.play_arrow : Icons.pause)
                      : Icons.fiber_manual_record,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isRecording ? (isPaused ? 'RESUME' : 'PAUSE') : 'START RIDE',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // Stop / Finish Ride Button
          if (isRecording || isPaused)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 32),
              tooltip: 'Finish & Reset Ride',
              onPressed: () => _showFinishDialog(telemetry),
            ),
        ],
      ),
    );
  }

  /// Pick GPX file from device filesystem
  Future<void> _pickGpxFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        final xmlString = await file.readAsString();
        final route = GpxService.parseGpx(xmlString, defaultName: result.files.single.name);

        setState(() {
          _importedRoute = route;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPX Loaded: ${route.name} (${route.totalDistanceKm.toStringAsFixed(1)} km)'),
              backgroundColor: const Color(0xFF1E1E1E),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading GPX: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Export current ride to GPX file and open iOS / Android native share sheet
  Future<void> _exportRideGpx(TelemetryData telemetry) async {
    try {
      final now = DateTime.now();
      final gpxContent = GpxService.exportToGpx(
        activityName: 'CycloEdge Ride ${DateFormat('yyyy-MM-dd HH:mm').format(now)}',
        coordinates: telemetry.breadcrumbs,
        startTime: widget.locationService.rideStartTime ?? now,
        totalDistanceKm: telemetry.distanceKm,
        elevationGainM: telemetry.elevationGain,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ride_${now.millisecondsSinceEpoch}.gpx');
      await file.writeAsString(gpxContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'CycloEdge Ride Export (${telemetry.distanceKm.toStringAsFixed(1)} km)',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFinishDialog(TelemetryData telemetry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Finish Ride?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Total Distance: ${telemetry.distanceKm.toStringAsFixed(2)} km\n'
          'Moving Time: ${telemetry.movingTime.inMinutes} mins\n\n'
          'Would you like to export GPX before resetting?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.locationService.stopAndResetRide();
            },
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _exportRideGpx(telemetry);
              widget.locationService.stopAndResetRide();
            },
            child: const Text('Export & Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

