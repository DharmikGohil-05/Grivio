import 'api_client.dart';
import 'auth_storage.dart';

/// Talks to the backend auth endpoints and keeps the local token.
/// Screens call this service instead of doing raw HTTP themselves.
class AuthService {
  AuthService({ApiClient? client, AuthStorage? storage})
    : _client = client ?? ApiClient(),
      _storage = storage ?? AuthStorage();

  final ApiClient _client;
  final AuthStorage _storage;

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _client.post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    await _storage.saveToken(res['token'] as String);
    return res;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    await _storage.saveToken(res['token'] as String);
    return res;
  }

  /// Logout: remove the token locally, then best-effort server ping.
  Future<void> logout() async {
    final token = await _storage.getToken();
    if (token != null) {
      try {
        await _client.post('/auth/logout', token: token);
      } catch (_) {
        // Token is discarded locally even if the network call fails.
      }
    }
    await _storage.clearToken();
    // A new user on the same device must never recover the old session.
    await _storage.clearActiveSession();
  }

  Future<bool> isLoggedIn() => _storage.hasToken();

  Future<Map<String, dynamic>> me() async {
    final token = await _storage.getToken();
    return _client.get('/auth/me', token: token);
  }
}
