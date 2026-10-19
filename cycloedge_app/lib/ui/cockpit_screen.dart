import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/activity_record.dart';
import '../models/route_data.dart';
import '../models/telemetry_data.dart';
import '../models/user_profile.dart';
import '../services/activity_service.dart';
import '../services/ble_service.dart';
import '../services/crash_detection_service.dart';
import '../services/gpx_service.dart';
import '../services/location_service.dart';
import '../services/offline_map_service.dart';
import '../services/profile_service.dart';
import '../services/strava_service.dart';
import 'sensor_modal.dart';
import 'share/activity_share_screen.dart';
import 'widgets/elevation_profile_widget.dart';
import 'widgets/map_view_widget.dart';
import 'widgets/rain_lock_overlay.dart';

class CockpitScreen extends StatefulWidget {
  final LocationService locationService;
  final BleService bleService;
  final ActivityService? activityService;
  final ProfileService? profileService;
  final StravaService? stravaService;
  final CrashDetectionService? crashDetectionService;
  final OfflineMapService? offlineMapService;

  const CockpitScreen({
    super.key,
    required this.locationService,
    required this.bleService,
    this.activityService,
    this.profileService,
    this.stravaService,
    this.crashDetectionService,
    this.offlineMapService,
  });

  @override
  State<CockpitScreen> createState() => _CockpitScreenState();
}

class _CockpitScreenState extends State<CockpitScreen> {
  RouteData? _importedRoute;
  bool _isRainLocked = false;
  bool _isMapFullscreen = false;
  int _currentLap = 1;
  bool _preferPace = false; // Toggle between Speed (km/h) and Pace (min/km)
  bool _showClimbPro = false; // Toggle ClimbPro Elevation Profile HUD

  List<ElevationPoint> _getElevationPoints(TelemetryData telemetry) {
    if (_importedRoute != null && _importedRoute!.points.isNotEmpty) {
      double runningDist = 0.0;
      final pts = <ElevationPoint>[];
      for (int i = 0; i < _importedRoute!.points.length; i++) {
        final p = _importedRoute!.points[i];
        if (i > 0) {
          final prev = _importedRoute!.points[i - 1];
          runningDist += const Distance().as(LengthUnit.Kilometer, prev.coordinate, p.coordinate);
        }
        pts.add(ElevationPoint(distanceKm: runningDist, elevationM: p.elevation));
      }
      return pts;
    }

    if (telemetry.breadcrumbs.length > 1) {
      final pts = <ElevationPoint>[];
      final stepKm = telemetry.distanceKm / (telemetry.breadcrumbs.length - 1);
      for (int i = 0; i < telemetry.breadcrumbs.length; i++) {
        final elev = telemetry.elevation - (telemetry.breadcrumbs.length - 1 - i) * 0.4;
        pts.add(ElevationPoint(distanceKm: i * stepKm, elevationM: math.max(10.0, elev)));
      }
      return pts;
    }

    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.locationService,
        widget.bleService,
        if (widget.crashDetectionService != null) widget.crashDetectionService!,
        if (widget.offlineMapService != null) widget.offlineMapService!,
      ]),
      builder: (context, _) {
        final telemetry = widget.locationService.telemetry;
        final connectedCount = widget.bleService.connectedSensors.length;
        final isCrashIncident = widget.crashDetectionService?.isIncidentTriggered == true;

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

                // Crash Detection SOS Incident Overlay
                if (isCrashIncident && widget.crashDetectionService != null)
                  _buildCrashIncidentOverlay(widget.crashDetectionService!),

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
  // 1. PORTRAIT LAYOUT
  // ==========================================
  Widget _buildPortraitLayout(TelemetryData telemetry, int connectedCount) {
    return Column(
      children: [
        // Top Status Bar (GPS FIX, Time, Lap, BLE, GPX, Activity Mode)
        _buildTopStatusBar(telemetry, connectedCount),

        // Map Area on TOP (Takes ~32% if ClimbPro enabled, else ~36%)
        Expanded(
          flex: _showClimbPro ? 30 : 36,
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

        // ClimbPro Live Elevation Profile HUD (When active)
        if (_showClimbPro)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: ElevationProfileWidget(
              points: _getElevationPoints(telemetry),
              currentDistanceKm: telemetry.distanceKm,
              currentElevationM: telemetry.elevation,
              height: 105,
              showClimbHud: true,
            ),
          ),

        // Metric Grid on BOTTOM (Takes remaining height)
        Expanded(
          flex: _showClimbPro ? 48 : 54,
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
  // 2. LANDSCAPE LAYOUT (HUGE 60% MAP)
  // ==========================================
  Widget _buildLandscapeLayout(TelemetryData telemetry, int connectedCount) {
    return Row(
      children: [
        // LEFT: HUGE EXPANSIVE MAP (Takes 60% of horizontal width) + ClimbPro if active
        Expanded(
          flex: 60,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Expanded(
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
                if (_showClimbPro)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ElevationProfileWidget(
                      points: _getElevationPoints(telemetry),
                      currentDistanceKm: telemetry.distanceKm,
                      currentElevationM: telemetry.elevation,
                      height: 80,
                      showClimbHud: false,
                    ),
                  ),
              ],
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
    final showPace = _preferPace || telemetry.activityType != 'cycling';

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
                    Text(
                      showPace ? 'PACE' : 'SPEED',
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                    Text(
                      showPace ? telemetry.formattedPace : telemetry.speed.toStringAsFixed(1),
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
  // 4. UI COMPONENTS
  // ==========================================

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
          // GPS Badge & Activity Selector
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
                telemetry.currentPosition != null ? 'GPS FIX' : 'SEARCH',
                style: TextStyle(
                  color: telemetry.currentPosition != null
                      ? const Color(0xFF00E676)
                      : Colors.orangeAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),

              // Activity Switcher Chip (Tap to cycle 🚴 -> 🏃 -> 🚶)
              GestureDetector(
                onTap: _cycleActivityType,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        telemetry.activityType == 'walking'
                            ? Icons.directions_walk
                            : telemetry.activityType == 'running'
                                ? Icons.directions_run
                                : Icons.directions_bike,
                        size: 11,
                        color: const Color(0xFF00E5FF),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        telemetry.activityType.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Moving Time Badge (Centered)
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

          // LAP, SENSORS & GPX
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

              // ClimbPro Toggle Icon
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.terrain,
                  color: _showClimbPro ? const Color(0xFF00E676) : Colors.white38,
                  size: 18,
                ),
                tooltip: 'ClimbPro Elevation Profile',
                onPressed: () {
                  setState(() => _showClimbPro = !_showClimbPro);
                },
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

  void _cycleActivityType() {
    final current = widget.locationService.telemetry.activityType;
    String next = 'cycling';
    if (current == 'cycling') {
      next = 'running';
    } else if (current == 'running') {
      next = 'walking';
    } else {
      next = 'cycling';
    }
    widget.locationService.setActivityType(next);
  }

  /// 3-Row Metric Grid (Dynamic Pace & Speed based on activity)
  Widget _buildMetricGrid(TelemetryData telemetry, {required bool isLandscape}) {
    final isRunOrWalk = telemetry.activityType != 'cycling';
    final showPaceAsPrimary = _preferPace || isRunOrWalk;

    return Column(
      children: [
        // Row 1: Primary Speed/Pace & Jarak
        Expanded(
          flex: isLandscape ? 10 : 12,
          child: Row(
            children: [
              Expanded(
                flex: 12,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _preferPace = !_preferPace);
                  },
                  child: _buildMetricCard(
                    title: showPaceAsPrimary ? 'PACE (TAP UBAH)' : 'KECEPATAN (TAP UBAH)',
                    badgeText: showPaceAsPrimary
                        ? 'AVG ${telemetry.formattedAvgPace}'
                        : 'LIVE 1Hz',
                    badgeColor: const Color(0xFF00E676),
                    valueText: showPaceAsPrimary
                        ? telemetry.formattedPace
                        : telemetry.speed.toStringAsFixed(1),
                    unitText: showPaceAsPrimary ? '/km' : 'km/h',
                    isHuge: true,
                    valueColor: Colors.white,
                  ),
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

        // Row 2: Kadens / Pace Sekunder & Detak Jantung
        Expanded(
          flex: 10,
          child: Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: isRunOrWalk ? 'KECEPATAN' : 'KADENS',
                  badgeText: isRunOrWalk ? 'AVG ${telemetry.avgSpeed.toStringAsFixed(1)}' : null,
                  badgeColor: const Color(0xFF00E676),
                  valueText: isRunOrWalk
                      ? telemetry.speed.toStringAsFixed(1)
                      : (telemetry.cadence > 0 ? '${telemetry.cadence}' : '--'),
                  unitText: isRunOrWalk ? 'km/h' : 'rpm',
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

        // Row 3: Kalori / Power & Total Ascent
        Expanded(
          flex: 10,
          child: Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: isRunOrWalk ? 'KALORI' : 'POWER (3s)',
                  badgeText: isRunOrWalk
                      ? 'KEYTEL'
                      : (telemetry.power > 0 ? 'NP ${telemetry.power}W' : 'BURN ${telemetry.calories} kcal'),
                  badgeColor: const Color(0xFFFFB300),
                  valueText: isRunOrWalk
                      ? '${telemetry.calories}'
                      : (telemetry.power > 0 ? '${telemetry.power}' : '${telemetry.calories}'),
                  unitText: isRunOrWalk ? 'kcal' : (telemetry.power > 0 ? 'W' : 'kcal'),
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

          // 4. STOP & FINISH BUTTON
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
              action: widget.offlineMapService != null
                  ? SnackBarAction(
                      label: 'Cache Offline',
                      textColor: const Color(0xFF00E5FF),
                      onPressed: () {
                        widget.offlineMapService!.cacheRouteArea(route.coordinates);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mengunduh tile peta offline untuk rute ini...'),
                            backgroundColor: Color(0xFF00E5FF),
                          ),
                        );
                      },
                    )
                  : null,
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
        activityName: 'CycloEdge ${telemetry.activityType.toUpperCase()} ${DateFormat('yyyy-MM-dd HH:mm').format(now)}',
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

  // ==========================================
  // 6. FINISH & SAVE WORKOUT DIALOG
  // ==========================================

  void _showFinishDialog(TelemetryData telemetry) {
    final actType = telemetry.activityType;
    final actName = actType == 'walking'
        ? 'Jalan Santai'
        : actType == 'running'
            ? 'Lari Sore'
            : 'Gowes Sepeda';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Selesai Olahraga?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Total Jarak: ${telemetry.distanceKm.toStringAsFixed(2)} km\n'
          'Waktu: ${telemetry.movingTime.inMinutes} menit\n'
          'Kecepatan Rata2: ${telemetry.avgSpeed.toStringAsFixed(1)} km/h\n'
          'Pace Rata2: ${telemetry.formattedAvgPace} /km\n'
          'Kalori Terbakar: ${telemetry.calories} kcal\n\n'
          'Simpan sesi ini untuk dibagikan dengan template kartu ala Strava?',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          // Buang (Discard)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.locationService.stopAndResetRide();
              setState(() => _currentLap = 1);
            },
            child: const Text('Buang', style: TextStyle(color: Colors.redAccent)),
          ),

          // Ekspor GPX
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _exportRideGpx(telemetry);
              widget.locationService.stopAndResetRide();
              setState(() => _currentLap = 1);
            },
            child: const Text('Ekspor GPX', style: TextStyle(color: Colors.white70)),
          ),

          // Simpan & Bagikan (Save & Open Strava Share Card)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFC4C02), // Strava orange
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              final newRecord = ActivityRecord(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: '$actName ${DateFormat('dd MMM').format(DateTime.now())}',
                activityType: actType,
                startTime: widget.locationService.rideStartTime ?? DateTime.now(),
                movingTime: telemetry.movingTime,
                elapsedTime: telemetry.elapsedTime,
                distanceKm: telemetry.distanceKm,
                avgSpeedKmh: telemetry.avgSpeed,
                maxSpeedKmh: telemetry.maxSpeed,
                avgPaceMinPerKm: telemetry.avgPaceMinutesPerKm,
                elevationGainM: telemetry.elevationGain,
                avgHr: widget.locationService.averageHeartRate,
                maxHr: telemetry.heartRate,
                calories: telemetry.calories,
                breadcrumbs: List.from(telemetry.breadcrumbs),
              );

              if (widget.activityService != null) {
                await widget.activityService!.saveActivity(newRecord);
              }

              widget.locationService.stopAndResetRide();
              setState(() => _currentLap = 1);

              if (mounted) {
                final prof = widget.profileService?.profile ?? const UserProfile();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityShareScreen(
                      activity: newRecord,
                      profile: prof,
                      stravaService: widget.stravaService,
                    ),
                  ),
                );
              }
            },
            child: const Text('Simpan & Bagikan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCrashIncidentOverlay(CrashDetectionService crash) {
    return Container(
      color: Colors.black.withOpacity(0.94),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF1744).withOpacity(0.2),
              border: Border.all(color: const Color(0xFFFF1744), width: 3),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF1744), size: 60),
          ),
          const SizedBox(height: 24),
          const Text(
            'BENTURAN TERDETEKSI!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Apakah Anda baik-baik saja? Penurunan kecepatan drastis terdeteksi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Text(
            '${crash.countdownSeconds}',
            style: const TextStyle(
              color: Color(0xFFFF1744),
              fontSize: 68,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'detik sebelum pesan SOS dikirim ke WhatsApp / SMS kontak darurat',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                crash.cancelIncident();
              },
              child: const Text(
                'SAYA AMAN (BATALKAN SOS)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
