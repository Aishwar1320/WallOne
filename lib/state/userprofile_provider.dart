import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileProvider extends ChangeNotifier {
  String? userName;
  String? coverImagePath;

  UserProfileProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    userName = prefs.getString('userName');
    coverImagePath = prefs.getString('coverImagePath');
    notifyListeners();
  }

  Future<void> setName(String name) async {
    userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    notifyListeners();
  }

  Future<void> setImagePath(String path) async {
    coverImagePath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('coverImagePath', path);
    notifyListeners();
  }

  // optional helper to clear profile
  Future<void> clear() async {
    userName = null;
    coverImagePath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    await prefs.remove('coverImagePath');
    notifyListeners();
  }
}
