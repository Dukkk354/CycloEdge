import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/telemetry_data.dart';
import 'profile_service.dart';

class AudioCueService extends ChangeNotifier {
  final ProfileService _profileService;
  int _lastAnnouncedKm = 0;
  int _zone5DurationSec = 0;
  bool _isZone5AlertActive = false;
  String? _lastAnnouncement;

  String? get lastAnnouncement => _lastAnnouncement;
  bool get isZone5AlertActive => _isZone5AlertActive;

  AudioCueService({required ProfileService profileService})
      : _profileService = profileService;

  void processTelemetry(TelemetryData telemetry) {
    if (!telemetry.isRecording || telemetry.isPaused) {
      _zone5DurationSec = 0;
      _isZone5AlertActive = false;
      return;
    }

    final voiceEnabled = _profileService.profile.voiceCuesEnabled;

    // 1. Check Kilometer Splits (every 1 km)
    final currentKm = telemetry.distanceKm.floor();
    if (currentKm > _lastAnnouncedKm && currentKm >= 1) {
      _lastAnnouncedKm = currentKm;
      if (voiceEnabled) {
        _announceKmSplit(currentKm, telemetry);
      }
    }

    // 2. Zone 5 Safety Warning (Heart Rate > 90% Max HR for > 15s)
    if (telemetry.hrZone == 5) {
      _zone5DurationSec++;
      if (_zone5DurationSec >= 15 && !_isZone5AlertActive) {
        _isZone5AlertActive = true;
        _triggerZone5Warning(telemetry.heartRate);
        notifyListeners();
      }
    } else {
      _zone5DurationSec = 0;
      if (_isZone5AlertActive) {
        _isZone5AlertActive = false;
        notifyListeners();
      }
    }
  }

  void _announceKmSplit(int km, TelemetryData telemetry) {
    final mins = telemetry.movingTime.inMinutes;
    final pace = telemetry.formattedPace;
    final speed = telemetry.speed.toStringAsFixed(1);

    final isRunOrWalk = telemetry.activityType != 'cycling';
    final announcement = isRunOrWalk
        ? 'Kilometer $km: Waktu $mins menit, Pace $pace per km'
        : 'Kilometer $km: Waktu $mins menit, Kecepatan $speed km/jam';

    _lastAnnouncement = announcement;
    notifyListeners();

    // Haptic feedback pattern
    HapticFeedback.heavyImpact();

    debugPrint('[AudioCue] $announcement');
  }

  void _triggerZone5Warning(int hr) {
    HapticFeedback.vibrate();
    _lastAnnouncement = 'PERINGATAN: Detak jantung $hr BPM berada di Zona 5 (Maksimal)! Kurangi intensitas.';
    notifyListeners();
    debugPrint('[AudioCue Alert] $_lastAnnouncement');
  }

  void reset() {
    _lastAnnouncedKm = 0;
    _zone5DurationSec = 0;
    _isZone5AlertActive = false;
    _lastAnnouncement = null;
    notifyListeners();
  }
}
