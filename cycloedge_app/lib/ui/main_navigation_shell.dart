import 'package:flutter/material.dart';

import '../services/activity_service.dart';
import '../services/audio_cue_service.dart';
import '../services/ble_service.dart';
import '../services/crash_detection_service.dart';
import '../services/location_service.dart';
import '../services/offline_map_service.dart';
import '../services/profile_service.dart';
import '../services/strava_service.dart';
import 'cockpit_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final LocationService locationService;
  final BleService bleService;
  final ActivityService activityService;
  final ProfileService profileService;
  final StravaService? stravaService;
  final CrashDetectionService? crashDetectionService;
  final OfflineMapService? offlineMapService;
  final AudioCueService? audioCueService;

  const MainNavigationShell({
    super.key,
    required this.locationService,
    required this.bleService,
    required this.activityService,
    required this.profileService,
    this.stravaService,
    this.crashDetectionService,
    this.offlineMapService,
    this.audioCueService,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // In Landscape mode while recording (Cockpit), give 100% of the screen to Cockpit & Huge Map!
    if (isLandscape && _currentIndex == 1) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildCockpitTab(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildCockpitTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          border: Border(top: BorderSide(color: Color(0xFF202020))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF00E5FF),
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              activeIcon: Icon(Icons.fitness_center, color: Color(0xFF00E5FF)),
              label: 'Aktivitas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_filled, size: 28),
              activeIcon: Icon(Icons.play_circle_filled, size: 28, color: Color(0xFF00E5FF)),
              label: 'Rekam',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              activeIcon: Icon(Icons.person, color: Color(0xFF00E5FF)),
              label: 'Profil & Zona',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return HomeScreen(
      activityService: widget.activityService,
      profileService: widget.profileService,
      locationService: widget.locationService,
      bleService: widget.bleService,
      stravaService: widget.stravaService,
      onStartRecord: () {
        setState(() => _currentIndex = 1); // Switch to Cockpit
      },
    );
  }

  Widget _buildCockpitTab() {
    return CockpitScreen(
      locationService: widget.locationService,
      bleService: widget.bleService,
      activityService: widget.activityService,
      profileService: widget.profileService,
      stravaService: widget.stravaService,
      crashDetectionService: widget.crashDetectionService,
      offlineMapService: widget.offlineMapService,
    );
  }

  Widget _buildProfileTab() {
    return ProfileScreen(
      profileService: widget.profileService,
      bleService: widget.bleService,
      crashDetectionService: widget.crashDetectionService,
    );
  }
}

