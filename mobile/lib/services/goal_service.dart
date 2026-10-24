import 'api_client.dart';
import 'auth_storage.dart';

/// Goal + Milestone models matching the backend JSON.
class Goal {
  final String id;
  final String name;
  final String? description;
  final String? whyItMatters;
  final String? growthArea;
  final DateTime? targetDate;
  final String status;
  final int progress;
  final int milestoneCount;
  final int completedMilestones;

  Goal({
    required this.id,
    required this.name,
    this.description,
    this.whyItMatters,
    this.growthArea,
    this.targetDate,
    required this.status,
    required this.progress,
    required this.milestoneCount,
    required this.completedMilestones,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    whyItMatters: json['why_it_matters'] as String?,
    growthArea: json['growth_area'] as String?,
    targetDate: json['target_date'] != null
        ? DateTime.tryParse(json['target_date'] as String)
        : null,
    status: json['status'] as String? ?? 'active',
    progress: (json['progress'] as num?)?.toInt() ?? 0,
    milestoneCount: (json['milestone_count'] as num?)?.toInt() ?? 0,
    completedMilestones: (json['completed_milestones'] as num?)?.toInt() ?? 0,
  );
}

class Milestone {
  final String id;
  final String goalId;
  final String title;
  final String? description;
  final int position;
  final String status;

  Milestone({
    required this.id,
    required this.goalId,
    required this.title,
    this.description,
    required this.position,
    required this.status,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
    id: json['id'] as String,
    goalId: json['goal_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    position: (json['position'] as num?)?.toInt() ?? 0,
    status: json['status'] as String? ?? 'pending',
  );
}

/// API wrapper for /api/goals and /api/milestones.
class GoalService {
  GoalService({ApiClient? client, AuthStorage? storage})
    : _client = client ?? ApiClient(),
      _storage = storage ?? AuthStorage();

  final ApiClient _client;
  final AuthStorage _storage;

  Future<List<Goal>> listGoals({String? status}) async {
    final token = await _storage.getToken();
    final res = await _client.get(
      '/goals${status != null ? '?status=$status' : ''}',
      token: token,
    );
    return (res['goals'] as List)
        .map((e) => Goal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Goal> getGoal(String id) async {
    final token = await _storage.getToken();
    final res = await _client.get('/goals/$id', token: token);
    return Goal.fromJson(res['goal'] as Map<String, dynamic>);
  }

  Future<Goal> createGoal(Map<String, dynamic> fields) async {
    final token = await _storage.getToken();
    final res = await _client.post('/goals', body: fields, token: token);
    return Goal.fromJson(res['goal'] as Map<String, dynamic>);
  }

  Future<Goal> updateGoal(String id, Map<String, dynamic> fields) async {
    final token = await _storage.getToken();
    final res = await _client.put('/goals/$id', body: fields, token: token);
    return Goal.fromJson(res['goal'] as Map<String, dynamic>);
  }

  Future<void> deleteGoal(String id) async {
    final token = await _storage.getToken();
    await _client.delete('/goals/$id', token: token);
  }

  Future<List<Milestone>> listMilestones(String goalId) async {
    final token = await _storage.getToken();
    final res = await _client.get('/goals/$goalId/milestones', token: token);
    return (res['milestones'] as List)
        .map((e) => Milestone.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Milestone> createMilestone(
    String goalId,
    Map<String, dynamic> fields,
  ) async {
    final token = await _storage.getToken();
    final res = await _client.post(
      '/goals/$goalId/milestones',
      body: fields,
      token: token,
    );
    return Milestone.fromJson(res['milestone'] as Map<String, dynamic>);
  }

  Future<Milestone> updateMilestone(
    String id,
    Map<String, dynamic> fields,
  ) async {
    final token = await _storage.getToken();
    final res = await _client.put(
      '/milestones/$id',
      body: fields,
      token: token,
    );
    return Milestone.fromJson(res['milestone'] as Map<String, dynamic>);
  }

  Future<void> deleteMilestone(String id) async {
    final token = await _storage.getToken();
    await _client.delete('/milestones/$id', token: token);
  }
}
