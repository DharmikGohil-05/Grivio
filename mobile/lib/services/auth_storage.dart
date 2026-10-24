import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure on-device storage for the auth token (Keychain/Keystore).
/// NEVER store the JWT in plain SharedPreferences.
class AuthStorage {
  AuthStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'grivio_auth_token';

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasToken() async => (await getToken()) != null;

  /// Logout = delete the token locally. JWT is stateless, so the
  /// server does not need to remember anything.
  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  // --- Active focus session recovery (Phase 8.1) ---
  // Only the session id + chosen duration are stored locally. The backend
  // remains the source of truth for elapsed time and status.
  static const _sessionKey = 'grivio_active_focus_session';
  static const _durationKey = 'grivio_active_focus_duration';

  Future<void> saveActiveSession(String id, int durationSeconds) async {
    try {
      await _storage.write(key: _sessionKey, value: id);
      await _storage.write(
        key: _durationKey,
        value: durationSeconds.toString(),
      );
    } catch (_) {}
  }

  Future<String?> getActiveSessionId() async {
    try {
      return await _storage.read(key: _sessionKey);
    } catch (_) {
      return null;
    }
  }

  Future<int?> getActiveSessionDuration() async {
    try {
      final v = await _storage.read(key: _durationKey);
      return v == null ? null : int.tryParse(v);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearActiveSession() async {
    try {
      await _storage.delete(key: _sessionKey);
      await _storage.delete(key: _durationKey);
    } catch (_) {}
  }

  // --- Theme mode preference (system | light | dark) ---
  static const _themeModeKey = 'grivio_theme_mode';

  Future<void> saveThemeMode(String mode) async {
    try {
      await _storage.write(key: _themeModeKey, value: mode);
    } catch (_) {}
  }

  Future<String?> getThemeMode() async {
    try {
      return await _storage.read(key: _themeModeKey);
    } catch (_) {
      return null;
    }
  }
}
