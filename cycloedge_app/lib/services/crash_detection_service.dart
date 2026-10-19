import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/telemetry_data.dart';
import 'profile_service.dart';

class CrashDetectionService extends ChangeNotifier {
  final ProfileService _profileService;
  bool _isIncidentTriggered = false;
  int _countdownSeconds = 30;
  Timer? _countdownTimer;

  double _previousSpeedKmh = 0.0;
  DateTime _lastSpeedTime = DateTime.now();
  LatLng? _lastKnownPosition;

  bool get isIncidentTriggered => _isIncidentTriggered;
  int get countdownSeconds => _countdownSeconds;
  LatLng? get lastKnownPosition => _lastKnownPosition;

  CrashDetectionService({required ProfileService profileService})
      : _profileService = profileService;

  void processTelemetry(TelemetryData telemetry) {
    if (!_profileService.profile.crashDetectionEnabled) return;
    if (!telemetry.isRecording || telemetry.isPaused) return;

    final now = DateTime.now();
    final dtSec = now.difference(_lastSpeedTime).inMilliseconds / 1000.0;
    _lastKnownPosition = telemetry.currentPosition;

    // Detect sudden deceleration impact:
    // Speed drops from > 18 km/h to < 1.5 km/h in less than 1.2 seconds
    if (_previousSpeedKmh > 18.0 && telemetry.speed < 1.5 && dtSec > 0.3 && dtSec < 1.5) {
      if (!_isIncidentTriggered) {
        triggerIncident();
      }
    }

    _previousSpeedKmh = telemetry.speed;
    _lastSpeedTime = now;
  }

  void triggerIncident() {
    _isIncidentTriggered = true;
    _countdownSeconds = 30;
    notifyListeners();

    HapticFeedback.heavyImpact();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        _countdownSeconds--;
        HapticFeedback.mediumImpact();
        notifyListeners();
      } else {
        _countdownTimer?.cancel();
        _sendEmergencyAlert();
      }
    });
  }

  void cancelIncident() {
    _countdownTimer?.cancel();
    _isIncidentTriggered = false;
    _countdownSeconds = 30;
    notifyListeners();
  }

  Future<void> _sendEmergencyAlert() async {
    final phone = _profileService.profile.emergencyContactPhone.trim();
    final name = _profileService.profile.name;
    final lat = _lastKnownPosition?.latitude ?? -6.8915;
    final lon = _lastKnownPosition?.longitude ?? 107.6107;
    final mapsLink = 'https://maps.google.com/?q=$lat,$lon';

    final message =
        '🚨 PESAN DARURAT OTOMATIS CYCLOEDGE: $name terdeteksi mengalami insiden / benturan saat berolahraga dan tidak merespon alarm dalam 30 detik. Lokasi GPS terakhir: $mapsLink';

    try {
      if (phone.isNotEmpty) {
        final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
        final waUrl = Uri.parse('whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(waUrl)) {
          await launchUrl(waUrl);
          return;
        }

        final smsUrl = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(smsUrl)) {
          await launchUrl(smsUrl);
          return;
        }
      }

      // Fallback: copy to clipboard or open maps
      final genericUrl = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(genericUrl)) {
        await launchUrl(genericUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error sending emergency alert: $e');
    }
  }
}
