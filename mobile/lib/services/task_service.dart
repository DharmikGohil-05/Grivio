import 'api_client.dart';
import 'auth_storage.dart';

/// Task + Subtask models matching the backend JSON.
class GrivioTask {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String priority;
  final int? estimatedMinutes;
  final String? category;
  final String status;
  final String? goalId;
  final String? milestoneId;
  final String? goalName;
  final String? milestoneTitle;
  final int subtaskCount;
  final int completedSubtasks;

  GrivioTask({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    required this.priority,
    this.estimatedMinutes,
    this.category,
    required this.status,
    this.goalId,
    this.milestoneId,
    this.goalName,
    this.milestoneTitle,
    required this.subtaskCount,
    required this.completedSubtasks,
  });

  factory GrivioTask.fromJson(Map<String, dynamic> json) => GrivioTask(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    dueDate: json['due_date'] != null
        ? DateTime.tryParse(json['due_date'] as String)
        : null,
    priority: json['priority'] as String? ?? 'medium',
    estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
    category: json['category'] as String?,
    status: json['status'] as String? ?? 'pending',
    goalId: json['goal_id'] as String?,
    milestoneId: json['milestone_id'] as String?,
    goalName: json['goal_name'] as String?,
    milestoneTitle: json['milestone_title'] as String?,
    subtaskCount: (json['subtask_count'] as num?)?.toInt() ?? 0,
    completedSubtasks: (json['completed_subtasks'] as num?)?.toInt() ?? 0,
  );
}

class Subtask {
  final String id;
  final String taskId;
  final String title;
  final bool isCompleted;
  final int position;

  Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isCompleted,
    required this.position,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
    id: json['id'] as String,
    taskId: json['task_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    isCompleted: json['is_completed'] as bool? ?? false,
    position: (json['position'] as num?)?.toInt() ?? 0,
  );
}

/// API wrapper for /api/tasks and /api/subtasks.
class TaskService {
  TaskService({ApiClient? client, AuthStorage? storage})
    : _client = client ?? ApiClient(),
      _storage = storage ?? AuthStorage();

  final ApiClient _client;
  final AuthStorage _storage;

  Future<List<GrivioTask>> listTasks({
    String? status,
    String? goalId,
    String? milestoneId,
  }) async {
    final token = await _storage.getToken();
    String path = '/tasks';
    final params = <String>[];
    if (status != null) params.add('status=$status');
    if (goalId != null) params.add('goalId=$goalId');
    if (milestoneId != null) params.add('milestoneId=$milestoneId');
    if (params.isNotEmpty) path += '?${params.join('&')}';
    final res = await _client.get(path, token: token);
    return (res['tasks'] as List)
        .map((e) => GrivioTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GrivioTask> createTask(Map<String, dynamic> fields) async {
    final token = await _storage.getToken();
    final res = await _client.post('/tasks', body: fields, token: token);
    return GrivioTask.fromJson(res['task'] as Map<String, dynamic>);
  }

  Future<GrivioTask> updateTask(String id, Map<String, dynamic> fields) async {
    final token = await _storage.getToken();
    final res = await _client.put('/tasks/$id', body: fields, token: token);
    return GrivioTask.fromJson(res['task'] as Map<String, dynamic>);
  }

  Future<GrivioTask> setTaskStatus(String id, String status) async {
    final token = await _storage.getToken();
    final res = await _client.patch(
      '/tasks/$id/status',
      body: {'status': status},
      token: token,
    );
    return GrivioTask.fromJson(res['task'] as Map<String, dynamic>);
  }

  Future<void> deleteTask(String id) async {
    final token = await _storage.getToken();
    await _client.delete('/tasks/$id', token: token);
  }

  Future<List<Subtask>> listSubtasks(String taskId) async {
    final token = await _storage.getToken();
    final res = await _client.get('/tasks/$taskId/subtasks', token: token);
    return (res['subtasks'] as List)
        .map((e) => Subtask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Subtask> createSubtask(String taskId, String title) async {
    final token = await _storage.getToken();
    final res = await _client.post(
      '/tasks/$taskId/subtasks',
      body: {'title': title},
      token: token,
    );
    return Subtask.fromJson(res['subtask'] as Map<String, dynamic>);
  }

  Future<Subtask> updateSubtask(String id, Map<String, dynamic> fields) async {
    final token = await _storage.getToken();
    final res = await _client.put('/subtasks/$id', body: fields, token: token);
    return Subtask.fromJson(res['subtask'] as Map<String, dynamic>);
  }

  Future<void> deleteSubtask(String id) async {
    final token = await _storage.getToken();
    await _client.delete('/subtasks/$id', token: token);
  }
}
