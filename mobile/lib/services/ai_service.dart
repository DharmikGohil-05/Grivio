import 'api_client.dart';
import 'auth_storage.dart';
import 'weekly_review_service.dart';

/// A single AI-generated subtask suggestion (untrusted until user-approved).
class SubtaskSuggestion {
  String title;
  String? description;
  int? estimatedMinutes;
  // Mutable and defaults to selected so the bottom sheet can edit these
  // suggestions in place, and the user opts OUT rather than opting in.
  bool selected;

  SubtaskSuggestion({
    required this.title,
    this.description,
    this.estimatedMinutes,
    this.selected = true,
  });

  factory SubtaskSuggestion.fromJson(Map<String, dynamic> j) =>
      SubtaskSuggestion(
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        estimatedMinutes: (j['estimatedMinutes'] as num?)?.toInt(),
      );

  // Only the fields the backend expects are serialized (null optionals
  // omitted); `selected` is purely UI state and is deliberately not sent.
  Map<String, dynamic> toJson() => {
    'title': title,
    if (description != null) 'description': description,
    if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
  };
}

/// API wrapper for the AI subtask generator.
class AIService {
  AIService({ApiClient? client, AuthStorage? storage})
    : _client = client ?? ApiClient(),
      _storage = storage ?? AuthStorage();

  final ApiClient _client;
  final AuthStorage _storage;
  // Every AI call follows one path: Flutter → GRIVIO backend → Groq. The
  // app only attaches the user's auth token; the Groq API key lives on
  // the backend and is never shipped inside the app.

  /// Asks the backend (which calls Groq) for subtask suggestions.
  /// Returns user-reviewable suggestions — nothing is saved automatically.
  Future<List<SubtaskSuggestion>> generateSubtasks({
    required String taskId,
    String? instructions,
  }) async {
    final token = await _storage.getToken();
    final res = await _client.post(
      '/ai/subtasks/generate',
      body: {
        'taskId': taskId,
        if (instructions != null && instructions.trim().isNotEmpty)
          'instructions': instructions.trim(),
      },
      token: token,
    );
    final list = (res['data']?['suggestions'] as List?) ?? const [];
    return list
        .map((e) => SubtaskSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Feature A (Phase 13): improvement proposal for an existing task
  /// (taskId) or an unsaved task (title/description). Preview-only —
  /// the user chooses which fields to apply via the task update API.
  Future<TaskImprovement> improveTask({
    String? taskId,
    String? title,
    String? description,
    String? instructions,
  }) async {
    final token = await _storage.getToken();
    final res = await _client.post(
      '/ai/tasks/improve',
      // Either identify an existing task by id, or send the unsaved title
      // (plus optional description) — the backend branches on which one
      // is present, so the two never appear together.
      body: {
        if (taskId != null) 'taskId': taskId,
        if (taskId == null) ...{
          'title': title ?? '',
          if (description != null && description.isNotEmpty)
            'description': description,
        },
        if (instructions != null && instructions.trim().isNotEmpty)
          'instructions': instructions.trim(),
      },
      token: token,
    );
    return TaskImprovement.fromJson(
      res['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// Feature B (Phase 13): proposed breakdown (phases → tasks) for an
  /// existing goal or an unsaved one. Preview-only until confirmed.
  Future<BreakdownProposal> generateBreakdown({
    String? goalId,
    String? title,
    String? description,
    String? instructions,
  }) async {
    final token = await _storage.getToken();
    final res = await _client.post(
      '/ai/breakdown/generate',
      // Same contract as improveTask: an existing goalId, or the draft
      // title/description for a goal that does not exist yet.
      body: {
        if (goalId != null) 'goalId': goalId,
        if (goalId == null) ...{
          'title': title ?? '',
          if (description != null && description.isNotEmpty)
            'description': description,
        },
        if (instructions != null && instructions.trim().isNotEmpty)
          'instructions': instructions.trim(),
      },
      token: token,
    );
    return BreakdownProposal.fromJson(
      res['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// Phase 14: AI daily planner. `dailyContext` is the user's free-text
  /// "what should my day look like" note (bounded server-side to 1000
  /// chars). Preview-only — nothing is persisted by generating.
  Future<DailyPlan> generateDailyPlan({
    required String date,
    required int availableMinutes,
    String? startTime,
    String? endTime,
    int? breakMinutes,
    String? dailyContext,
  }) async {
    final token = await _storage.getToken();
    final res = await _client.post(
      '/ai/daily-plan/generate',
      body: {
        'date': date,
        'availableMinutes': availableMinutes,
        if (startTime != null && startTime.isNotEmpty) 'startTime': startTime,
        if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,
        if (breakMinutes != null) 'breakMinutes': breakMinutes,
        if (dailyContext != null && dailyContext.trim().isNotEmpty)
          'dailyContext': dailyContext.trim(),
      },
      token: token,
    );
    return DailyPlan.fromJson(res['data'] as Map<String, dynamic>? ?? const {});
  }

  /// Phase 15: AI weekly growth review for a Monday-start week.
  /// Read-only — generation never writes anything; the result lives in
  /// client state until dismissed.
  Future<AIWeeklyReview> generateWeeklyReview(String weekStart) async {
    final token = await _storage.getToken();
    final res = await _client.post(
      '/ai/weekly-review/generate',
      body: {'weekStart': weekStart},
      token: token,
    );
    return AIWeeklyReview.fromJson(
      res['data'] as Map<String, dynamic>? ?? const {},
    );
  }
}

/// A scheduled slot in a generated daily plan.
class PlanSlot {
  String taskId;
  final String title;
  final String priority;
  // `start` and `minutes` are mutable: the daily planner lets the user
  // edit them and then re-times the rest of the schedule in memory.
  String start;
  int minutes;
  final bool isFallbackEstimate;

  PlanSlot({
    required this.taskId,
    required this.title,
    required this.priority,
    required this.start,
    required this.minutes,
    this.isFallbackEstimate = false,
  });

  /// 'HH:mm' parsed into minutes since midnight so slots can be
  /// compared and shifted arithmetically.
  int get startMinutes {
    final p = start.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  /// Derived end time (start + minutes), formatted 'HH:mm'. Computed on
  /// the client — the backend only sends `start` and `minutes`.
  String get end {
    final total = startMinutes + minutes;
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  factory PlanSlot.fromJson(Map<String, dynamic> j) => PlanSlot(
    taskId: j['taskId'] as String? ?? '',
    title: j['title'] as String? ?? '',
    priority: j['priority'] as String? ?? 'medium',
    start: j['start'] as String? ?? '00:00',
    minutes: (j['minutes'] as num?)?.toInt() ?? 30,
    // Backend flag: this slot's duration was a fallback estimate rather
    // than a duration the task itself specified.
    isFallbackEstimate: j['isFallbackEstimate'] as bool? ?? false,
  );
}

/// A task that could not be scheduled, with a reason.
class UnscheduledItem {
  final String taskId;
  final String title;
  final String priority;
  final String reason;
  const UnscheduledItem({
    required this.taskId,
    required this.title,
    required this.priority,
    required this.reason,
  });

  factory UnscheduledItem.fromJson(Map<String, dynamic> j) => UnscheduledItem(
    taskId: j['taskId'] as String? ?? '',
    title: j['title'] as String? ?? '',
    priority: j['priority'] as String? ?? 'medium',
    reason: j['reason'] as String? ?? '',
  );
}

/// Break slot in a plan.
class PlanBreak {
  final String start;
  final int minutes;
  const PlanBreak({required this.start, required this.minutes});

  factory PlanBreak.fromJson(Map<String, dynamic> j) => PlanBreak(
    start: j['start'] as String? ?? '00:00',
    minutes: (j['minutes'] as num?)?.toInt() ?? 0,
  );
}

/// Generated daily plan (preview until the user accepts it).
class DailyPlan {
  final String date;
  final int availableMinutes;
  final String startTime;
  final String endTime;
  final int breakMinutes;
  final int capacityMinutes;
  final int plannedMinutes;
  final int remainingMinutes;
  final bool contextApplied;
  final List<PlanSlot> scheduled;
  final List<UnscheduledItem> unscheduled;
  final List<PlanBreak> breaks;
  /// Notes the backend attaches to the plan; parsed defensively as
  /// strings (the planner screen does not currently render them).
  final List<String> warnings;

  const DailyPlan({
    required this.date,
    required this.availableMinutes,
    required this.startTime,
    required this.endTime,
    required this.breakMinutes,
    required this.capacityMinutes,
    required this.plannedMinutes,
    required this.remainingMinutes,
    required this.contextApplied,
    required this.scheduled,
    required this.unscheduled,
    required this.breaks,
    required this.warnings,
  });

  factory DailyPlan.fromJson(Map<String, dynamic> j) => DailyPlan(
    date: j['date'] as String? ?? '',
    availableMinutes: (j['availableMinutes'] as num?)?.toInt() ?? 0,
    startTime: j['startTime'] as String? ?? '09:00',
    endTime: j['endTime'] as String? ?? '18:00',
    breakMinutes: (j['breakMinutes'] as num?)?.toInt() ?? 0,
    capacityMinutes: (j['capacityMinutes'] as num?)?.toInt() ?? 0,
    plannedMinutes: (j['plannedMinutes'] as num?)?.toInt() ?? 0,
    remainingMinutes: (j['remainingMinutes'] as num?)?.toInt() ?? 0,
    contextApplied: j['contextApplied'] as bool? ?? false,
    // JSON keys differ from field names (scheduledTasks → scheduled,
    // unscheduledTasks → unscheduled); absent lists become empty ones so
    // callers never have to null-check.
    scheduled: ((j['scheduledTasks'] as List?) ?? const [])
        .map((e) => PlanSlot.fromJson(e as Map<String, dynamic>))
        .toList(),
    unscheduled: ((j['unscheduledTasks'] as List?) ?? const [])
        .map((e) => UnscheduledItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    breaks: ((j['breaks'] as List?) ?? const [])
        .map((e) => PlanBreak.fromJson(e as Map<String, dynamic>))
        .toList(),
    warnings: ((j['warnings'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}

/// A field-level improvement proposal — only fields the model returned.
class TaskImprovement {
  final String? title;
  final String? description;
  final String? category;
  final String? priority;
  final int? estimatedMinutes;
  final List<String> subtasks;

  const TaskImprovement({
    this.title,
    this.description,
    this.category,
    this.priority,
    this.estimatedMinutes,
    this.subtasks = const [],
  });

  factory TaskImprovement.fromJson(Map<String, dynamic> j) => TaskImprovement(
    title: j['title'] as String?,
    description: j['description'] as String?,
    category: j['category'] as String?,
    priority: j['priority'] as String?,
    estimatedMinutes: (j['estimatedMinutes'] as num?)?.toInt(),
    // Subtasks may arrive as plain strings or as {title: ...} maps; both
    // shapes are accepted and blank results are dropped.
    subtasks: ((j['subtasks'] as List?) ?? const [])
        .map((e) => (e is Map ? e['title'] : e)?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList(),
  );
}

/// A proposed phase/task hierarchy for Feature B.
class BreakdownProposal {
  final List<BreakdownPhase> phases;
  const BreakdownProposal({this.phases = const []});

  factory BreakdownProposal.fromJson(Map<String, dynamic> j) =>
      BreakdownProposal(
        phases: ((j['phases'] as List?) ?? const [])
            .map((e) => BreakdownPhase.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class BreakdownPhase {
  String title;
  String? description;
  // Mutable + selected-by-default, same editable-preview contract as
  // SubtaskSuggestion: the sheet edits these in place and the user
  // unchecks what they don't want created.
  bool selected;
  List<BreakdownTask> tasks;

  BreakdownPhase({
    required this.title,
    this.description,
    this.selected = true,
    required this.tasks,
  });

  factory BreakdownPhase.fromJson(Map<String, dynamic> j) => BreakdownPhase(
    title: j['title'] as String? ?? '',
    description: j['description'] as String?,
    tasks: ((j['tasks'] as List?) ?? const [])
        .map((e) => BreakdownTask.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class BreakdownTask {
  String title;
  String? description;
  int? estimatedMinutes;
  bool selected;

  BreakdownTask({
    required this.title,
    this.description,
    this.estimatedMinutes,
    this.selected = true,
  });

  factory BreakdownTask.fromJson(Map<String, dynamic> j) => BreakdownTask(
    title: j['title'] as String? ?? '',
    description: j['description'] as String?,
    estimatedMinutes: (j['estimatedMinutes'] as num?)?.toInt(),
  );
}

/// Phase 15: structured AI weekly growth review (read-only preview).
/// `summary` is always backend-computed from real records; the section
/// lists are AI interpretation and are labeled as such in the UI.
class AIWeeklyReview {
  final String weekStart;
  final String weekEnd;
  /// Backend flag: the week had little activity to interpret, so the
  /// narrative lists below may be thin or empty.
  final bool lowData;
  /// Real, backend-computed totals for the week (not AI-generated).
  final WeeklyStats summary;
  final List<String> wins;
  final List<String> progressHighlights;
  final List<String> patterns;
  final List<String> challenges;
  final List<String> nextWeekPriorities;
  final List<String> suggestedActions;
  final List<String> dataLimitations;

  const AIWeeklyReview({
    required this.weekStart,
    required this.weekEnd,
    required this.lowData,
    required this.summary,
    required this.wins,
    required this.progressHighlights,
    required this.patterns,
    required this.challenges,
    required this.nextWeekPriorities,
    required this.suggestedActions,
    required this.dataLimitations,
  });

  factory AIWeeklyReview.fromJson(Map<String, dynamic> j) {
    List<String> list(String key) =>
        ((j[key] as List?) ?? const []).map((e) => e.toString()).toList();
    final weekStart = j['weekStart'] as String? ?? '';
    final weekEnd = j['weekEnd'] as String? ?? '';
    // Summary is always backend-computed; fall back to week bounds if absent.
    final rawSummary = j['summary'] is Map<String, dynamic>
        ? j['summary'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return AIWeeklyReview(
      weekStart: weekStart,
      weekEnd: weekEnd,
      lowData: j['lowData'] as bool? ?? false,
      summary: WeeklyStats.fromJson({
        ...rawSummary,
        'weekStart': rawSummary['weekStart'] ?? weekStart,
        'weekEnd': rawSummary['weekEnd'] ?? weekEnd,
      }),
      wins: list('wins'),
      progressHighlights: list('progressHighlights'),
      patterns: list('patterns'),
      challenges: list('challenges'),
      nextWeekPriorities: list('nextWeekPriorities'),
      suggestedActions: list('suggestedActions'),
      dataLimitations: list('dataLimitations'),
    );
  }
}
