import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'services/activity_service.dart';
import 'services/audio_cue_service.dart';
import 'services/ble_service.dart';
import 'services/crash_detection_service.dart';
import 'services/location_service.dart';
import 'services/offline_map_service.dart';
import 'services/profile_service.dart';
import 'services/strava_service.dart';
import 'ui/main_navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep screen awake while app is active on handlebars
  try {
    await WakelockPlus.enable();
  } catch (e) {
    debugPrint('Wakelock not available: $e');
  }

  // Set system chrome to edge-to-edge dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CycloEdgeApp());
}

class CycloEdgeApp extends StatefulWidget {
  const CycloEdgeApp({super.key});

  @override
  State<CycloEdgeApp> createState() => _CycloEdgeAppState();
}

class _CycloEdgeAppState extends State<CycloEdgeApp> {
  late final BleService _bleService;
  late final ProfileService _profileService;
  late final ActivityService _activityService;
  late final LocationService _locationService;
  late final StravaService _stravaService;
  late final CrashDetectionService _crashDetectionService;
  late final AudioCueService _audioCueService;
  late final OfflineMapService _offlineMapService;

  @override
  void initState() {
    super.initState();
    _bleService = BleService();
    _profileService = ProfileService();
    _activityService = ActivityService();
    _stravaService = StravaService(profileService: _profileService);
    _crashDetectionService = CrashDetectionService(profileService: _profileService);
    _audioCueService = AudioCueService(profileService: _profileService);
    _offlineMapService = OfflineMapService();
    _locationService = LocationService(
      bleService: _bleService,
      profileService: _profileService,
    );

    _locationService.addListener(_onLocationUpdate);
  }

  void _onLocationUpdate() {
    final telemetry = _locationService.telemetry;
    _crashDetectionService.processTelemetry(telemetry);
    _audioCueService.processTelemetry(telemetry);
  }

  @override
  void dispose() {
    _locationService.removeListener(_onLocationUpdate);
    _locationService.dispose();
    _crashDetectionService.dispose();
    _audioCueService.dispose();
    _offlineMapService.dispose();
    _activityService.dispose();
    _profileService.dispose();
    _bleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CycloEdge GPS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
          surface: Color(0xFF121212),
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: MainNavigationShell(
        locationService: _locationService,
        bleService: _bleService,
        activityService: _activityService,
        profileService: _profileService,
        stravaService: _stravaService,
        crashDetectionService: _crashDetectionService,
        offlineMapService: _offlineMapService,
        audioCueService: _audioCueService,
      ),
    );
  }
}
