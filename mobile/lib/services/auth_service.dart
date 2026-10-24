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

  /// Creates the account and persists the JWT the backend returns, so the
  /// user stays logged in across restarts without logging in again.
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

  /// Logs in and stores the returned JWT exactly like register — both
  /// endpoints hand back a token that is saved before this future completes.
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

  /// True when a token merely *exists* locally — deliberately not a server
  /// round-trip. JWTs are stateless, so the backend stays the authority: an
  /// expired or forged token is simply rejected by the next real API call
  /// and never blocks app startup.
  Future<bool> isLoggedIn() => _storage.hasToken();

  Future<Map<String, dynamic>> me() async {
    final token = await _storage.getToken();
    return _client.get('/auth/me', token: token);
  }
}
