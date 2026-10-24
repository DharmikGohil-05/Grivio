import 'package:flutter/material.dart';

// The one non-secret preference the app persists (the theme choice) reuses
// the AuthStorage secure-storage wrapper instead of pulling in a second
// storage plugin for a single string.
import '../../services/auth_storage.dart';

/// Centralized controller for the application theme mode (System / Light / Dark).
/// Single source of truth across the entire app.
///
/// It extends ChangeNotifier because widgets must rebuild the instant the
/// mode changes: main.dart wraps MaterialApp in a ListenableBuilder on this
/// instance, and notifyListeners is what triggers that rebuild. The private
/// constructor plus the static `instance` make it a singleton so every
/// caller (app root, settings screen) shares one state instead of drifting.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Loads the persisted choice (awaited in main() before runApp). Anything
  /// other than a stored 'light'/'dark' — including first launch, where
  /// nothing is saved yet — falls back to following the system setting.
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

  /// Applies the mode immediately (notify first so the UI feels instant);
  /// the slower storage write only decides what the *next* launch shows.
  /// The early return skips pointless work when the mode did not change.
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
