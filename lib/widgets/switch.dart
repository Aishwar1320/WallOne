import 'package:flutter/material.dart';
import 'package:wallone/state/theme_provider.dart';

class ThemeSwitcher extends StatefulWidget {
  final ThemeProvider themeProvider;
  const ThemeSwitcher({super.key, required this.themeProvider});

  @override
  _ThemeSwitcherState createState() => _ThemeSwitcherState();
}

class _ThemeSwitcherState extends State<ThemeSwitcher> {
  @override
  Widget build(BuildContext context) {
    // Detect system brightness
    final systemBrightness = MediaQuery.of(context).platformBrightness;

    return Switch(
      value: widget.themeProvider.themeMode == ThemeMode.dark ||
          (widget.themeProvider.themeMode == ThemeMode.system &&
              systemBrightness == Brightness.dark),
      onChanged: (value) {
        widget.themeProvider.setThemeMode(
          value ? ThemeMode.dark : ThemeMode.light,
        );
      },
    );
  }
}
