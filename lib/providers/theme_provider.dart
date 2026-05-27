// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool('isDarkMode') ?? true;
      notifyListeners();
    } catch (_) {}
  }

  void toggleTheme() async {
    _isDark = !_isDark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDark);
    } catch (_) {}
  }
}
