/// Backend configuration.
///
/// The base URL is injected at build/run time via --dart-define:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
///
/// Android emulator uses 10.0.2.2 to reach the host machine.
/// iOS simulator can use localhost.
class AppConfig {
  AppConfig._();

  // Android emulator uses 10.0.2.2 to reach the host machine; iOS
  // simulator can use localhost. Override with --dart-define as needed.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );

  static const Duration apiTimeout = Duration(seconds: 20);
}
