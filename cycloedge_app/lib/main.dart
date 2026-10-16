import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'services/ble_service.dart';
import 'services/location_service.dart';
import 'ui/cockpit_screen.dart';

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
  late final LocationService _locationService;

  @override
  void initState() {
    super.initState();
    _bleService = BleService();
    _locationService = LocationService(bleService: _bleService);
  }

  @override
  void dispose() {
    _locationService.dispose();
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
      home: CockpitScreen(
        locationService: _locationService,
        bleService: _bleService,
      ),
    );
  }
}
