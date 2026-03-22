import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

enum AppThemeMode { light, dark }

class AppThemeService extends ChangeNotifier {
  AppThemeService._();

  static final AppThemeService instance = AppThemeService._();

  AppThemeMode _currentTheme = AppThemeMode.dark;

  AppThemeMode get currentTheme => _currentTheme;

  ThemeData get currentThemeData {
    return _currentTheme == AppThemeMode.light ? AppTheme.light : AppTheme.dark;
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(AppConstants.keyAppTheme);

      if (savedTheme != null) {
        _currentTheme = savedTheme == 'light'
            ? AppThemeMode.light
            : AppThemeMode.dark;
      }

      notifyListeners();
    } catch (_) {
      _currentTheme = AppThemeMode.dark;
    }
  }

  Future<void> setTheme(AppThemeMode theme) async {
    _currentTheme = theme;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        AppConstants.keyAppTheme,
        theme == AppThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {
      // Ignorar errores de persistencia, el tema cambió en memoria
    }

    notifyListeners();
  }
}
