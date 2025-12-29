import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode(); // Load theme when provider is initialized
  }

  void _loadThemeMode() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _themeMode = ThemeMode.system;
        notifyListeners();
        return;
      }

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        String? theme = doc.data()?['themeMode'] as String?;

        if (theme == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (theme == 'light') {
          _themeMode = ThemeMode.light;
        } else {
          _themeMode = ThemeMode.system;
        }
      } else {
        _themeMode = ThemeMode.system;
      }
    } catch (e) {
      _themeMode = ThemeMode.system;
    }

    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        notifyListeners();
        return;
      }

      String themeString = 'system';
      if (mode == ThemeMode.dark) {
        themeString = 'dark';
      } else if (mode == ThemeMode.light) {
        themeString = 'light';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'themeMode': themeString}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }

    notifyListeners();
  }
}

class ThemeSwitcher extends StatelessWidget {
  final ThemeProvider themeProvider;

  const ThemeSwitcher({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    final systemBrightness = MediaQuery.of(context).platformBrightness;

    return Switch(
      value: themeProvider.themeMode == ThemeMode.dark ||
          (themeProvider.themeMode == ThemeMode.system &&
              systemBrightness == Brightness.dark),
      onChanged: (value) {
        themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
      },
    );
  }
}
