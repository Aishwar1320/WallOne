import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode(); // Load theme when provider is initialized
  }

  void _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    String? theme = prefs.getString('themeMode');

    if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();

    if (mode == ThemeMode.dark) {
      await prefs.setString('themeMode', 'dark');
    } else if (mode == ThemeMode.light) {
      await prefs.setString('themeMode', 'light');
    } else {
      await prefs.setString('themeMode', 'system');
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
