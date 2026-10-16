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
  int _currentLap = 1;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.locationService, widget.bleService]),
      builder: (context, _) {
        final telemetry = widget.locationService.telemetry;
        final connectedCount = widget.bleService.connectedSensors.length;

        return Scaffold(
          backgroundColor: Colors.black, // Pure AMOLED Pitch Black
          body: SafeArea(
            child: Stack(
              children: [
                OrientationBuilder(
                  builder: (context, orientation) {
                    final isLandscape = orientation == Orientation.landscape;

                    if (_isMapFullscreen) {
                      return _buildFullscreenMap(telemetry);
                    }

                    return isLandscape
                        ? _buildLandscapeLayout(telemetry, connectedCount)
                        : _buildPortraitLayout(telemetry, connectedCount);
                  },
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

  // ==========================================
  // 1. PORTRAIT LAYOUT (Matches preview.html)
  // ==========================================
  Widget _buildPortraitLayout(TelemetryData telemetry, int connectedCount) {
    return Column(
      children: [
        // Auto Pause Red Banner
        if (telemetry.isAutoPaused) _buildAutoPauseBanner(),

        // Top Status Bar (GPS FIX, Time, Lap, BLE, GPX, Lock)
        _buildTopStatusBar(telemetry, connectedCount),

        // Map Area on TOP (Takes 36% of screen height)
        Expanded(
          flex: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

        // Metric Grid on BOTTOM (Takes remaining ~52% of height)
        Expanded(
          flex: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: _buildMetricGrid(telemetry, isLandscape: false),
          ),
        ),

        // Action Bar (LOCK, + LAP, START/PAUSE, STOP)
        _buildBottomActionBar(telemetry),
      ],
    );
  }

  // ==========================================
  // 2. LANDSCAPE LAYOUT (BIG EXPANSIVE MAP)
  // ==========================================
  Widget _buildLandscapeLayout(TelemetryData telemetry, int connectedCount) {
    return Row(
      children: [
        // LEFT: HUGE EXPANSIVE MAP (Takes 60% of horizontal width)
        Expanded(
          flex: 60,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
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

        // RIGHT: STATUS, METRIC GRID & ACTION BAR (Takes 40% of horizontal width)
        Expanded(
          flex: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                if (telemetry.isAutoPaused) _buildAutoPauseBanner(),

                // Compact Status Bar
                _buildTopStatusBar(telemetry, connectedCount, isCompact: true),

                const SizedBox(height: 4),

                // 3-Row Metric Grid for Landscape
                Expanded(
                  child: _buildMetricGrid(telemetry, isLandscape: true),
                ),

                // Action Bar
                _buildBottomActionBar(telemetry, isCompact: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. FULLSCREEN MAP MODE
  // ==========================================
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

        // Mini HUD Floating Card in Top-Left
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SPEED', style: TextStyle(color: Colors.white54, fontSize: 9)),
                    Text(
                      telemetry.speed.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DIST', style: TextStyle(color: Colors.white54, fontSize: 9)),
                    Text(
                      telemetry.distanceKm.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HR', style: TextStyle(color: Colors.white54, fontSize: 9)),
                    Text(
                      telemetry.heartRate > 0 ? '${telemetry.heartRate}' : '--',
                      style: TextStyle(
                        color: telemetry.hrZoneColor,
                        fontSize: 18,
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

  // ==========================================
  // 4. UI COMPONENTS (Identical to preview.html)
  // ==========================================

  Widget _buildAutoPauseBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFF1744),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: const Text(
        'AUTO-PAUSED (KECEPATAN < 2 KM/H)',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTopStatusBar(TelemetryData telemetry, int connectedCount, {bool isCompact = false}) {
    final hours = telemetry.movingTime.inHours.toString().padLeft(2, '0');
    final minutes = (telemetry.movingTime.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (telemetry.movingTime.inSeconds % 60).toString().padLeft(2, '0');
    final timeStr = telemetry.movingTime.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // GPS Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: telemetry.currentPosition != null
                      ? const Color(0xFF00E676)
                      : Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                telemetry.currentPosition != null ? 'GPS FIX' : 'SEARCHING',
                style: TextStyle(
                  color: telemetry.currentPosition != null
                      ? const Color(0xFF00E676)
                      : Colors.orangeAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Time Badge (Centered)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),

          // LAP & SENSORS
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lap Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LAP $_currentLap',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // BLE Sensor Pill
              GestureDetector(
                onTap: () => SensorModal.show(context, widget.bleService),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: connectedCount > 0
                        ? const Color(0xFF00E676).withOpacity(0.15)
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: connectedCount > 0
                          ? const Color(0xFF00E676)
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bluetooth,
                        size: 11,
                        color: connectedCount > 0
                            ? const Color(0xFF00E676)
                            : Colors.white54,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        connectedCount > 0 ? '$connectedCount' : 'BLE',
                        style: TextStyle(
                          color: connectedCount > 0
                              ? const Color(0xFF00E676)
                              : Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // GPX Import Icon
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.folder_open,
                  color: _importedRoute != null ? const Color(0xFF00E5FF) : Colors.white70,
                  size: 18,
                ),
                tooltip: 'Import GPX',
                onPressed: _pickGpxFile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3-Row Metric Grid (Exact structure from preview.html)
  Widget _buildMetricGrid(TelemetryData telemetry, {required bool isLandscape}) {
    return Column(
      children: [
        // Row 1: Kecepatan & Jarak
        Expanded(
          flex: isLandscape ? 10 : 12,
          child: Row(
            children: [
              Expanded(
                flex: 12,
                child: _buildMetricCard(
                  title: 'KECEPATAN',
                  badgeText: 'LIVE 1Hz',
                  badgeColor: const Color(0xFF00E676),
                  valueText: telemetry.speed.toStringAsFixed(1),
                  unitText: 'km/h',
                  isHuge: true,
                  valueColor: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 9,
                child: _buildMetricCard(
                  title: 'JARAK',
                  valueText: telemetry.distanceKm.toStringAsFixed(2),
                  unitText: 'km',
                  valueColor: const Color(0xFF00E5FF),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Row 2: Kadens & Detak Jantung
        Expanded(
          flex: 10,
          child: Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'KADENS',
                  valueText: telemetry.cadence > 0 ? '${telemetry.cadence}' : '--',
                  unitText: 'rpm',
                  valueColor: const Color(0xFF00E676),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricCard(
                  title: 'DETAK JANTUNG',
                  badgeText: telemetry.hrZoneName,
                  badgeColor: telemetry.hrZoneColor,
                  valueText: telemetry.heartRate > 0 ? '${telemetry.heartRate}' : '--',
                  unitText: 'bpm',
                  valueColor: telemetry.hrZoneColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Row 3: Power (3s) & Total Ascent
        Expanded(
          flex: 10,
          child: Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'POWER (3s)',
                  badgeText: telemetry.power > 0 ? 'NP ${telemetry.power}W' : null,
                  badgeColor: const Color(0xFFFFB300),
                  valueText: telemetry.power > 0 ? '${telemetry.power}' : '--',
                  unitText: 'W',
                  valueColor: const Color(0xFFFFB300),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricCard(
                  title: 'TOTAL ASCENT',
                  badgeText: 'MAX ${telemetry.maxSpeed.toStringAsFixed(1)}',
                  badgeColor: Colors.white54,
                  valueText: '${telemetry.elevationGain.round()}',
                  unitText: 'm',
                  valueColor: const Color(0xFF00E5FF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    String? badgeText,
    Color? badgeColor,
    required String valueText,
    required String unitText,
    Color valueColor = Colors.white,
    bool isHuge = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header Row (Title & Badge)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? const Color(0xFF00E676)).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor ?? const Color(0xFF00E676),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),

          // Value and Unit Row
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  valueText,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: isHuge ? 44 : 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unitText,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Action Bar (LOCK, + LAP, START/PAUSE, STOP)
  Widget _buildBottomActionBar(TelemetryData telemetry, {bool isCompact = false}) {
    final isRecording = telemetry.isRecording;
    final isPaused = telemetry.isPaused;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: isCompact ? 6 : 8),
      color: Colors.black,
      child: Row(
        children: [
          // 1. LOCK BUTTON (Rain & Sweat Lock)
          Expanded(
            flex: 2,
            child: _buildActionButton(
              label: 'LOCK',
              color: const Color(0xFF2A2A2A),
              textColor: const Color(0xFFFFF01F),
              onPressed: () => setState(() => _isRainLocked = true),
            ),
          ),
          const SizedBox(width: 6),

          // 2. + LAP BUTTON
          Expanded(
            flex: 2,
            child: _buildActionButton(
              label: '+ LAP',
              color: const Color(0xFF2A2A2A),
              textColor: const Color(0xFF00E5FF),
              onPressed: () {
                setState(() => _currentLap++);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lap $_currentLap Tercatat!'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: const Color(0xFF1E1E1E),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),

          // 3. PRIMARY START / PAUSE / RESUME BUTTON
          Expanded(
            flex: 3,
            child: _buildActionButton(
              label: isRecording ? (isPaused ? 'RESUME' : 'PAUSE') : 'START',
              color: isRecording
                  ? (isPaused ? const Color(0xFF00E676) : const Color(0xFFFFB300))
                  : const Color(0xFF00E5FF),
              textColor: Colors.black,
              isPrimary: true,
              onPressed: () {
                if (isRecording && !isPaused) {
                  widget.locationService.pauseRecording();
                } else {
                  widget.locationService.startRecording();
                }
              },
            ),
          ),
          const SizedBox(width: 6),

          // 4. STOP & EXPORT BUTTON
          Expanded(
            flex: 2,
            child: _buildActionButton(
              label: 'STOP*',
              color: const Color(0xFF2A2A2A),
              textColor: const Color(0xFFFF1744),
              onPressed: () => _showFinishDialog(telemetry),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: isPrimary ? 3 : 0,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ==========================================
  // 5. GPX IMPORT & EXPORT
  // ==========================================

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
              content: Text('GPX Terbaca: ${route.name} (${route.totalDistanceKm.toStringAsFixed(1)} km)'),
              backgroundColor: const Color(0xFF1E1E1E),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membaca GPX: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

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
          SnackBar(content: Text('Export gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFinishDialog(TelemetryData telemetry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Selesai Gowes?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Total Jarak: ${telemetry.distanceKm.toStringAsFixed(2)} km\n'
          'Waktu Bergerak: ${telemetry.movingTime.inMinutes} menit\n'
          'Kecepatan Rata-rata: ${telemetry.avgSpeed.toStringAsFixed(1)} km/h\n\n'
          'Apakah Anda ingin mengekspor file GPX sebelum reset?',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.locationService.stopAndResetRide();
              setState(() => _currentLap = 1);
            },
            child: const Text('Buang', style: TextStyle(color: Colors.redAccent)),
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
              setState(() => _currentLap = 1);
            },
            child: const Text('Ekspor & Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
