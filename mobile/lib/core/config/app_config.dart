/// Backend configuration.
///
/// The base URL is chosen at compile time via --dart-define=API_BASE_URL:
///
///   Production (default, no flag needed) — the Render deployment:
///     flutter run
///
///   Local development — the Express backend running on this machine:
///     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
///     (10.0.2.2 is the Android emulator's alias for the host PC's loopback;
///      iOS simulator uses http://localhost:5000/api instead)
class AppConfig {
  AppConfig._();

  /// Live backend deployed on Render (HTTPS) — the default target, so the
  /// app works without running a backend locally and release builds can
  /// never ship the emulator-only address below.
  static const String productionApiBaseUrl =
      'https://grivio-api.onrender.com/api';

  /// Local development backend: 10.0.2.2 reaches this PC from the Android
  /// emulator, and the Express server listens on port 5000.
  static const String localApiBaseUrl = 'http://10.0.2.2:5000/api';

  // String.fromEnvironment is inlined at *compile* time, so the URL is baked
  // into each build and can never change at runtime — switching servers means
  // rebuilding with a different --dart-define. Every request (including
  // authenticated ones) goes through ApiClient, which reads this value.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: productionApiBaseUrl,
  );

  // Applied to every request in ApiClient so a dead or slow network fails
  // fast instead of leaving the UI spinning forever.
  // Note: a Render instance that has been asleep (free tier) can take longer
  // than this to answer its first request; retry once if that happens.
  static const Duration apiTimeout = Duration(seconds: 20);
}
