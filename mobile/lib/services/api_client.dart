import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';

/// Minimal API client — every network call to the Grivio backend
/// goes through here so headers/errors/token handling live in one place.
/// Each verb also applies AppConfig.apiTimeout, so no request can hang the
/// UI indefinitely.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final res = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}$path'),
          headers: _headers(token),
        )
        .timeout(AppConfig.apiTimeout);
    return _parse(res);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final res = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}$path'),
          headers: _headers(token),
          body: jsonEncode(body ?? {}),
        )
        .timeout(AppConfig.apiTimeout);
    return _parse(res);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final res = await _client
        .put(
          Uri.parse('${AppConfig.apiBaseUrl}$path'),
          headers: _headers(token),
          body: jsonEncode(body ?? {}),
        )
        .timeout(AppConfig.apiTimeout);
    return _parse(res);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final res = await _client
        .patch(
          Uri.parse('${AppConfig.apiBaseUrl}$path'),
          headers: _headers(token),
          body: jsonEncode(body ?? {}),
        )
        .timeout(AppConfig.apiTimeout);
    return _parse(res);
  }

  Future<Map<String, dynamic>> delete(String path, {String? token}) async {
    final res = await _client
        .delete(
          Uri.parse('${AppConfig.apiBaseUrl}$path'),
          headers: _headers(token),
        )
        .timeout(AppConfig.apiTimeout);
    return _parse(res);
  }

  // JSON content type always; the Authorization header only appears when a
  // token is passed, so public calls (login/register) send no credentials.
  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // The backend always responds with { success, message, ... }.
  // Throws an ApiException with the server's safe message on failure.
  Map<String, dynamic> _parse(http.Response res) {
    final Map<String, dynamic> json =
        jsonDecode(res.body) as Map<String, dynamic>;
    if (json['success'] == true) return json;
    throw ApiException(
      json['message']?.toString() ?? 'Request failed',
      statusCode: res.statusCode,
    );
  }
}

/// Thrown when the backend answers with `success: false`. `message` is the
/// server's own message, written to be safe to show to the user; the
/// optional `statusCode` is kept so callers can branch on it
/// (e.g. 404 = resource gone, 409 = conflict).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
