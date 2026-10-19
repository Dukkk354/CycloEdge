import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/activity_record.dart';
import 'gpx_service.dart';
import 'profile_service.dart';

class StravaSyncResult {
  final bool success;
  final String message;
  final String? activityId;

  const StravaSyncResult({
    required this.success,
    required this.message,
    this.activityId,
  });
}

class StravaService extends ChangeNotifier {
  final ProfileService _profileService;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;
  bool get isConnected => _profileService.profile.stravaAccessToken?.isNotEmpty ?? false;

  StravaService({required ProfileService profileService})
      : _profileService = profileService;

  Future<StravaSyncResult> uploadActivity(ActivityRecord activity) async {
    final token = _profileService.profile.stravaAccessToken;
    if (token == null || token.trim().isEmpty) {
      return const StravaSyncResult(
        success: false,
        message: 'Token Strava belum diatur. Masukkan Access Token di menu Profil.',
      );
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final gpxString = GpxService.exportToGpx(
        activityName: activity.title,
        coordinates: activity.breadcrumbs,
        startTime: activity.startTime,
        totalDistanceKm: activity.distanceKm,
        elevationGainM: activity.elevationGainM,
      );

      final uri = Uri.parse('https://www.strava.com/api/v3/uploads');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['data_type'] = 'gpx';
      request.fields['name'] = activity.title;
      request.fields['description'] =
          'Recorded with CycloEdge GPS • Dist: ${activity.distanceKm.toStringAsFixed(2)} km • HR Avg: ${activity.avgHr} bpm • Burn: ${activity.calories} kcal';
      request.fields['activity_type'] =
          activity.activityType == 'walking'
              ? 'walk'
              : (activity.activityType == 'running' ? 'run' : 'ride');

      request.files.add(http.MultipartFile.fromString(
        'file',
        gpxString,
        filename: 'cycloedge_${activity.id}.gpx',
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final uploadId = json['id_str'] ?? json['id']?.toString();
        return StravaSyncResult(
          success: true,
          message: 'Berhasil diunggah ke Strava! ID: $uploadId',
          activityId: uploadId,
        );
      } else {
        final errorMsg = response.body.isNotEmpty ? response.body : 'Error ${response.statusCode}';
        return StravaSyncResult(
          success: false,
          message: 'Gagal upload ke Strava: $errorMsg',
        );
      }
    } catch (e) {
      return StravaSyncResult(
        success: false,
        message: 'Koneksi error: $e',
      );
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
