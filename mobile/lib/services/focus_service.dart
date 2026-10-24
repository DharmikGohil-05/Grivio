import 'api_client.dart';
import 'auth_storage.dart';

/// Focus session model matching the backend JSON.
class FocusSession {
  final String id;
  final String? taskId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String status;
  final DateTime? pausedAt;
  final int totalPauseSeconds;
  final String? productivityRating;
  final String? reflection;
  final String? taskTitle;

  FocusSession({
    required this.id,
    this.taskId,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    required this.status,
    this.pausedAt,
    required this.totalPauseSeconds,
    this.productivityRating,
    this.reflection,
    this.taskTitle,
  });

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
    id: json['id'] as String,
    taskId: json['task_id'] as String?,
    startedAt: DateTime.parse(json['started_at'] as String),
    endedAt: json['ended_at'] != null
        ? DateTime.parse(json['ended_at'] as String)
        : null,
    durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    status: json['status'] as String? ?? 'active',
    pausedAt: json['paused_at'] != null
        ? DateTime.parse(json['paused_at'] as String)
        : null,
    totalPauseSeconds: (json['total_pause_seconds'] as num?)?.toInt() ?? 0,
    productivityRating: json['productivity_rating'] as String?,
    reflection: json['reflection'] as String?,
    taskTitle: json['task_title'] as String?,
  );

  /// Actual focused seconds, excluding paused time. Timestamp-based, so
  /// it stays correct across Flutter rebuilds, backgrounding, and locks.
  int focusedSeconds(DateTime now) {
    var paused = totalPauseSeconds * 1000;
    if (pausedAt != null) paused += now.difference(pausedAt!).inMilliseconds;
    return (now.difference(startedAt).inMilliseconds - paused).clamp(
          0,
          1 << 31,
        ) ~/
        1000;
  }
}

/// API wrapper for /api/focus/sessions.
class FocusService {
  FocusService({ApiClient? client, AuthStorage? storage})
    : _client = client ?? ApiClient(),
      _storage = storage ?? AuthStorage();

  final ApiClient _client;
  final AuthStorage _storage;

  Future<FocusSession> start({String? taskId}) async {
    final token = await _storage.getToken();
    final res = await _client.post(
      '/focus/sessions',
      body: {if (taskId != null) 'task_id': taskId},
      token: token,
    );
    return FocusSession.fromJson(res['session'] as Map<String, dynamic>);
  }

  Future<FocusSession> get(String id) async {
    final token = await _storage.getToken();
    final res = await _client.get('/focus/sessions/$id', token: token);
    return FocusSession.fromJson(res['session'] as Map<String, dynamic>);
  }

  Future<FocusSession> pause(String id) async {
    final token = await _storage.getToken();
    final res = await _client.patch('/focus/sessions/$id/pause', token: token);
    return FocusSession.fromJson(res['session'] as Map<String, dynamic>);
  }

  Future<FocusSession> resume(String id) async {
    final token = await _storage.getToken();
    final res = await _client.patch('/focus/sessions/$id/resume', token: token);
    return FocusSession.fromJson(res['session'] as Map<String, dynamic>);
  }

  Future<FocusSession> complete(
    String id, {
    String? rating,
    String? reflection,
  }) async {
    final token = await _storage.getToken();
    final res = await _client.patch(
      '/focus/sessions/$id/complete',
      body: {
        if (rating != null) 'productivity_rating': rating,
        if (reflection != null && reflection.isNotEmpty)
          'reflection': reflection,
      },
      token: token,
    );
    return FocusSession.fromJson(res['session'] as Map<String, dynamic>);
  }

  Future<FocusSession> cancel(String id) async {
    final token = await _storage.getToken();
    final res = await _client.patch('/focus/sessions/$id/cancel', token: token);
    return FocusSession.fromJson(res['session'] as Map<String, dynamic>);
  }

  Future<List<FocusSession>> list() async {
    final token = await _storage.getToken();
    final res = await _client.get('/focus/sessions', token: token);
    return (res['sessions'] as List)
        .map((e) => FocusSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
