import 'api_client.dart';
import 'auth_storage.dart';

/// Progress models — mirrors GET /api/progress response.
class ProgressSummary {
  final int tasksCompleted;
  final int focusMinutes;
  final int completionRate;
  final int activeGoals;

  ProgressSummary({
    required this.tasksCompleted,
    required this.focusMinutes,
    required this.completionRate,
    required this.activeGoals,
  });
  factory ProgressSummary.fromJson(Map<String, dynamic> j) => ProgressSummary(
    tasksCompleted: (j['tasksCompleted'] as num?)?.toInt() ?? 0,
    focusMinutes: (j['focusMinutes'] as num?)?.toInt() ?? 0,
    completionRate: (j['completionRate'] as num?)?.toInt() ?? 0,
    activeGoals: (j['activeGoals'] as num?)?.toInt() ?? 0,
  );
}

class TrendPoint {
  final DateTime date;
  final int value;
  TrendPoint(this.date, this.value);
}

class GoalProgressItem {
  final String id;
  final String name;
  final int progress;
  final DateTime? targetDate;

  GoalProgressItem({
    required this.id,
    required this.name,
    required this.progress,
    this.targetDate,
  });
  factory GoalProgressItem.fromJson(Map<String, dynamic> j) => GoalProgressItem(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    progress: (j['progress'] as num?)?.toInt() ?? 0,
    targetDate: j['targetDate'] != null
        ? DateTime.tryParse(j['targetDate'] as String)
        : null,
  );
}

class ProgressData {
  final ProgressSummary summary;
  final List<TrendPoint> taskTrend;
  final List<TrendPoint> focusTrend;
  final List<GoalProgressItem> goalProgress;
  final List<String> insights;

  ProgressData({
    required this.summary,
    required this.taskTrend,
    required this.focusTrend,
    required this.goalProgress,
    required this.insights,
  });
}

/// API wrapper for GET /api/progress.
class ProgressService {
  ProgressService({ApiClient? client, AuthStorage? storage})
    : _client = client ?? ApiClient(),
      _storage = storage ?? AuthStorage();

  final ApiClient _client;
  final AuthStorage _storage;

  Future<ProgressData> getProgress(String range) async {
    final token = await _storage.getToken();
    final res = await _client.get('/progress?range=$range', token: token);
    return ProgressData(
      summary: ProgressSummary.fromJson(res['summary'] as Map<String, dynamic>),
      taskTrend: (res['taskTrend'] as List)
          .map(
            (e) => TrendPoint(
              DateTime.parse(e['date'] as String),
              (e['count'] as num).toInt(),
            ),
          )
          .toList(),
      focusTrend: (res['focusTrend'] as List)
          .map(
            (e) => TrendPoint(
              DateTime.parse(e['date'] as String),
              (e['minutes'] as num).toInt(),
            ),
          )
          .toList(),
      goalProgress: (res['goalProgress'] as List)
          .map((e) => GoalProgressItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      insights: List<String>.from(res['insights'] ?? const []),
    );
  }
}
