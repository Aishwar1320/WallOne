import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode(); // Load theme when provider is initialized
  }

  void _loadThemeMode() {
    _loadThemeModeAsync();
  }

  Future<void> _loadThemeModeAsync() async {
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
      debugPrint('Error loading theme: $e');
      _themeMode = ThemeMode.system;
    }

    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _setThemeModeAsync(mode);
  }

  Future<void> _setThemeModeAsync(ThemeMode mode) async {
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
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class ThemeSwitcher extends StatelessWidget {
  final ThemeProvider themeProvider;

  const ThemeSwitcher({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, provider, _) {
        final systemBrightness = MediaQuery.of(context).platformBrightness;
        final isDark = provider.themeMode == ThemeMode.dark ||
            (provider.themeMode == ThemeMode.system &&
                systemBrightness == Brightness.dark);

        return Switch(
          value: isDark,
          onChanged: (value) {
            provider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
          },
        );
      },
    );
  }
}
