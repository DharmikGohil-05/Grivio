import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_scaffold.dart';
import 'screens/login_screen.dart';
import 'screens/setup_flow_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';

import 'core/theme/theme_controller.dart';

/// App entry point.
///
/// Order matters: the widget binding must be ready before any plugin
/// channel (secure storage) is touched, and the saved theme is awaited
/// *before* runApp so the very first frame is already Light/Dark — no
/// flash of the wrong theme on launch.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.loadThemeMode();
  runApp(const GrivioApp());
}

/// Root widget: builds both themes and lets ThemeController pick the mode.
///
/// The whole MaterialApp sits inside a ListenableBuilder on the controller,
/// so toggling Light/Dark/System rebuilds it instantly — no app restart.
class GrivioApp extends StatelessWidget {
  const GrivioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: ThemeController.instance.themeMode,
          home: const _AppEntry(),
        );
      },
    );
  }
}

/// Startup router — shows the animated splash while resolving, then:
///   not logged in            → LoginScreen
///   logged in, setup not done → SetupFlowScreen
///   logged in, setup done     → HomePlaceholderScreen (real Home in Phase 7)
/// It re-checks whenever login/logout/setup callbacks fire.
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  final _auth = AuthService();
  final _profiles = ProfileService();

  /// Minimum splash display time so the brand moment never feels rushed.
  static const _minSplash = Duration(milliseconds: 1600);
  final _startedAt = DateTime.now();
  bool _firstResolve = true;

  // null = still resolving (token + profile check in flight)
  bool? _loggedIn;
  bool _setupCompleted = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final loggedIn = await _auth.isLoggedIn();
    bool setupDone = false;
    if (loggedIn) {
      try {
        final p = await _profiles.getProfile();
        setupDone = p.setupCompleted;
      } catch (_) {
        // Profile fetch failed (e.g. server offline) — keep false so the
        // user is not blocked silently; backend enforces real auth anyway.
      }
    }
    // Hold the splash for its minimum duration on cold start only.
    // Why only the first resolve: _resolve() also runs after login, logout
    // and setup — those must route instantly instead of replaying the
    // splash every single time.
    if (_firstResolve) {
      _firstResolve = false;
      final elapsed = DateTime.now().difference(_startedAt);
      if (elapsed < _minSplash) {
        await Future<void>.delayed(_minSplash - elapsed);
      }
    }
    if (mounted) {
      setState(() {
        _loggedIn = loggedIn;
        _setupCompleted = setupDone;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn == null) {
      return const SplashScreen();
    }
    if (!_loggedIn!) {
      return LoginScreen(onLoggedIn: _resolve);
    }
    if (!_setupCompleted) {
      return SetupFlowScreen(onFinished: _resolve);
    }
    return MainScaffold(onLoggedOut: _resolve);
  }
}
