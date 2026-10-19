import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';

class ProfileService extends ChangeNotifier {
  UserProfile _profile = const UserProfile();
  bool _isLoaded = false;

  UserProfile get profile => _profile;
  bool get isLoaded => _isLoaded;

  ProfileService() {
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/cycloedge_profile.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        _profile = UserProfile.fromJson(json);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> updateProfile(UserProfile newProfile) async {
    _profile = newProfile;
    notifyListeners();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/cycloedge_profile.json');
      await file.writeAsString(jsonEncode(_profile.toJson()));
    } catch (e) {
      debugPrint('Error saving profile: $e');
    }
  }
}

