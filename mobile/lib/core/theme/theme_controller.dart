import 'package:flutter/material.dart';

import '../../services/auth_storage.dart';

/// Centralized controller for the application theme mode (System / Light / Dark).
/// Single source of truth across the entire app.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> loadThemeMode() async {
    final saved = await AuthStorage().getThemeMode();
    if (saved == 'light') {
      _themeMode = ThemeMode.light;
    } else if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final str = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
        ? 'dark'
        : 'system';
    await AuthStorage().saveThemeMode(str);
  }
}
