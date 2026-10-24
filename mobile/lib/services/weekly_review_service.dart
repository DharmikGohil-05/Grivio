import 'api_client.dart';
import 'auth_storage.dart';

/// Weekly review models — mirrors the backend weekly review API.
///
/// The API is Monday-based: `weekStart` is the Monday of the week as a
/// yyyy-MM-dd string (the backend rejects any other day of the week), and
/// `weekEnd` is that Monday plus six days — the Sunday.
class WeeklyStats {
  final String weekStart;
  final String weekEnd;
  final int tasksCompleted;
  final int focusMinutes;
  final int goalsProgressed;
  final int completionRate;

  /// Active tasks that week (created or completed). Present in the AI
  /// review summary; the classic stats endpoint omits it (defaults to 0).
  final int tasksTotal;

  WeeklyStats({
    required this.weekStart,
    required this.weekEnd,
    required this.tasksCompleted,
    required this.focusMinutes,
    required this.goalsProgressed,
    required this.completionRate,
    this.tasksTotal = 0,
  });
  /// Note the key casing: this stats endpoint answers in camelCase, while
  /// review rows come back snake_case (see WeeklyReview.fromJson below).
  factory WeeklyStats.fromJson(Map<String, dynamic> j) => WeeklyStats(
    weekStart: j['weekStart'] as String,
    weekEnd: j['weekEnd'] as String,
    tasksCompleted: (j['tasksCompleted'] as num?)?.toInt() ?? 0,
    focusMinutes: (j['focusMinutes'] as num?)?.toInt() ?? 0,
    goalsProgressed: (j['goalsProgressed'] as num?)?.toInt() ?? 0,
    completionRate: (j['completionRate'] as num?)?.toInt() ?? 0,
    tasksTotal: (j['tasksTotal'] as num?)?.toInt() ?? 0,
  );
}

class WeeklyReview {
  final String id;
  final String weekStart;
  final String weekEnd;
  final String? summary;
  final String? biggestWin;
  final String? needsAttention;
  final String? nextWeekFocus;

  WeeklyReview({
    required this.id,
    required this.weekStart,
    required this.weekEnd,
    this.summary,
    this.biggestWin,
    this.needsAttention,
    this.nextWeekFocus,
  });
  /// Review rows use snake_case keys. The dates are cut to their first 10
  /// characters because the database may return full timestamps — the app
  /// only ever compares whole days.
  factory WeeklyReview.fromJson(Map<String, dynamic> j) => WeeklyReview(
    id: j['id'] as String,
    weekStart: j['week_start'] is String
        ? (j['week_start'] as String).substring(0, 10)
        : '',
    weekEnd: j['week_end'] is String
        ? (j['week_end'] as String).substring(0, 10)
        : '',
    summary: j['summary'] as String?,
    biggestWin: j['biggest_win'] as String?,
    needsAttention: j['needs_attention'] as String?,
    nextWeekFocus: j['next_week_focus'] as String?,
  );
}

/// API wrapper for /api/weekly-reviews.
class WeeklyReviewService {
  WeeklyReviewService({ApiClient? client, AuthStorage? storage})
    : _client = client ?? ApiClient(),
      _storage = storage ?? AuthStorage();

  final ApiClient _client;
  final AuthStorage _storage;

  Future<Map<String, dynamic>> getWeek(String weekStart) async {
    final token = await _storage.getToken();
    final res = await _client.get(
      '/weekly-reviews/week/$weekStart',
      token: token,
    );
    return {
      'stats': WeeklyStats.fromJson(res['stats'] as Map<String, dynamic>),
      'review': res['review'] != null
          ? WeeklyReview.fromJson(res['review'] as Map<String, dynamic>)
          : null,
    };
  }

  /// Saves the review for `weekStart`, creating it or replacing the one
  /// already stored for that exact week (the backend upserts on it). Only
  /// non-null fields are put in the body, so leaving a section blank
  /// deliberately stores it as empty rather than sending a placeholder.
  Future<WeeklyReview> upsert({
    required String weekStart,
    String? biggestWin,
    String? needsAttention,
    String? nextWeekFocus,
    String? summary,
  }) async {
    final token = await _storage.getToken();
    final res = await _client.post(
      '/weekly-reviews',
      body: {
        'weekStart': weekStart,
        if (biggestWin != null) 'biggestWin': biggestWin,
        if (needsAttention != null) 'needsAttention': needsAttention,
        if (nextWeekFocus != null) 'nextWeekFocus': nextWeekFocus,
        if (summary != null) 'summary': summary,
      },
      token: token,
    );
    return WeeklyReview.fromJson(res['review'] as Map<String, dynamic>);
  }

  Future<List<WeeklyReview>> list() async {
    final token = await _storage.getToken();
    final res = await _client.get('/weekly-reviews', token: token);
    return (res['reviews'] as List)
        .map((e) => WeeklyReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
