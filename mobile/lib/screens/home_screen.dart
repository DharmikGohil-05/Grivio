import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/goal_service.dart';
import '../services/profile_service.dart';
import '../services/task_service.dart';
import '../widgets/neumorphic.dart';
import 'add_task_screen.dart';
import 'daily_planner_screen.dart';
import 'goal_detail_screen.dart';
import 'goals_screen.dart';
import 'task_detail_screen.dart';
import 'tasks_screen.dart';
import 'weekly_review_screen.dart';

/// GRIVIO Home — "Today at a glance."
/// Clear, motivating overview answering:
/// - What should I focus on today?
/// - What progress have I made?
/// - Which goal matters right now?
/// - What should I do next?
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _profileService = ProfileService();
  final _goalService = GoalService();
  final _taskService = TaskService();

  UserProfile? _profile;
  List<GrivioTask> _allTasks = [];
  List<Goal> _goals = [];
  List<Milestone> _milestones = [];
  Map<String, dynamic>? _todayReflection;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _profileService.getProfile();
      final tasks = await _taskService.listTasks();
      final goals = await _goalService.listGoals(status: 'active');
      Map<String, dynamic>? todayReflection;
      try {
        todayReflection = await _profileService.getTodayReflection();
      } catch (_) {}

      List<Milestone> milestones = [];
      final active = _pickActiveGoal(goals);
      if (active != null) {
        milestones = await _goalService.listMilestones(active.id);
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _allTasks = tasks;
          _goals = goals;
          _milestones = milestones;
          _todayReflection = todayReflection;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load your day. Pull to retry.';
          _loading = false;
        });
      }
    }
  }

  List<GrivioTask> _todayTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _allTasks.where((t) {
      if (t.status == 'cancelled') return false;
      if (t.dueDate == null) return t.status != 'completed';
      final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return !d.isAfter(today);
    }).toList()..sort((a, b) {
      const rank = {'high': 0, 'medium': 1, 'low': 2};
      final aDone = a.status == 'completed' ? 1 : 0;
      final bDone = b.status == 'completed' ? 1 : 0;
      if (aDone != bDone) return aDone - bDone;
      return (rank[a.priority] ?? 1).compareTo(rank[b.priority] ?? 1);
    });
  }

  Goal? _pickActiveGoal(List<Goal> goals) {
    if (goals.isEmpty) return null;
    final withDate = goals.where((g) => g.targetDate != null).toList()
      ..sort((a, b) => a.targetDate!.compareTo(b.targetDate!));
    return withDate.isNotEmpty ? withDate.first : goals.first;
  }

  Future<void> _toggleTask(GrivioTask t) async {
    final previous = t.status;
    setState(() {
      final i = _allTasks.indexWhere((x) => x.id == t.id);
      if (i >= 0) {
        _allTasks[i] = GrivioTask(
          id: t.id,
          title: t.title,
          description: t.description,
          dueDate: t.dueDate,
          priority: t.priority,
          estimatedMinutes: t.estimatedMinutes,
          category: t.category,
          status: t.status == 'completed' ? 'pending' : 'completed',
          goalId: t.goalId,
          milestoneId: t.milestoneId,
          goalName: t.goalName,
          milestoneTitle: t.milestoneTitle,
          subtaskCount: t.subtaskCount,
          completedSubtasks: t.completedSubtasks,
        );
      }
    });

    try {
      await _taskService.setTaskStatus(
        t.id,
        previous == 'completed' ? 'pending' : 'completed',
      );
      final tasks = await _taskService.listTasks();
      final goals = await _goalService.listGoals(status: 'active');
      List<Milestone> milestones = [];
      final active = _pickActiveGoal(goals);
      if (active != null) {
        milestones = await _goalService.listMilestones(active.id);
      }
      if (mounted) {
        setState(() {
          _allTasks = tasks;
          _goals = goals;
          _milestones = milestones;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final i = _allTasks.indexWhere((x) => x.id == t.id);
          if (i >= 0) {
            _allTasks[i] = GrivioTask(
              id: t.id,
              title: t.title,
              description: t.description,
              dueDate: t.dueDate,
              priority: t.priority,
              estimatedMinutes: t.estimatedMinutes,
              category: t.category,
              status: previous,
              goalId: t.goalId,
              milestoneId: t.milestoneId,
              goalName: t.goalName,
              milestoneTitle: t.milestoneTitle,
              subtaskCount: t.subtaskCount,
              completedSubtasks: t.completedSubtasks,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update task. Try again.')),
        );
      }
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _headerDate() {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final today = _todayTasks();
    final completedToday = today.where((t) => t.status == 'completed').length;
    final totalToday = today.length;
    final progress = totalToday == 0 ? 0.0 : completedToday / totalToday;
    final remaining = totalToday - completedToday;
    final activeGoal = _pickActiveGoal(_goals);
    final currentMilestone = activeGoal == null
        ? null
        : _milestones.firstWhere(
            (m) => m.status == 'in_progress',
            orElse: () => _milestones.firstWhere(
              (m) => m.status == 'pending',
              orElse: () => Milestone(
                id: '',
                goalId: '',
                title: '',
                position: 0,
                status: 'pending',
              ),
            ),
          );

    final firstName = (_profile != null && _profile!.name.isNotEmpty)
        ? _profile!.name.split(' ').first
        : '';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              16,
              AppSpacing.pagePadding,
              36,
            ),
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()}${firstName.isNotEmpty ? ', $firstName' : ''}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _headerDate(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.lightSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const GrivioLogo(size: 44, borderRadius: AppRadius.md),
                ],
              ),
              const SizedBox(height: 24),

              // ── Daily Progress Ring ───────────────────────────────────────
              Center(
                child: GrivioProgressRing(
                  progress: progress,
                  centerText: totalToday == 0
                      ? '—'
                      : '${(progress * 100).round()}%',
                  subtitleText: totalToday == 0
                      ? 'No tasks'
                      : '$completedToday of $totalToday done',
                  size: 148,
                  strokeWidth: 9,
                ),
              ),
              const SizedBox(height: 28),

              // ── Today's Tasks ─────────────────────────────────────────────
              SectionLabel(
                'Today',
                trailing: 'View all',
                onTrailingTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const TasksScreen())),
              ),
              if (today.isEmpty)
                Neumorphic(
                  padding: const EdgeInsets.all(20),
                  borderRadius: AppRadius.lg,
                  child: Column(
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        size: 32,
                        color:
                            (isDark
                                    ? AppColors.darkAccent
                                    : AppColors.lightAccent)
                                .withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No tasks planned for today',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final created = await Navigator.of(context)
                              .push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => const AddTaskScreen(),
                                ),
                              );
                          if (created == true) _load();
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Task'),
                      ),
                    ],
                  ),
                )
              else
                ...today
                    .take(4)
                    .map(
                      (t) => _HomeTaskRow(
                        task: t,
                        onToggle: () => _toggleTask(t),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(taskId: t.id),
                            ),
                          );
                          _load();
                        },
                      ),
                    ),
              const SizedBox(height: 24),

              // ── Active Goal ───────────────────────────────────────────────
              SectionLabel(
                'Current goal',
                trailing: activeGoal != null ? 'All goals' : null,
                onTrailingTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const GoalsScreen())),
              ),
              if (activeGoal == null)
                Neumorphic(
                  padding: const EdgeInsets.all(20),
                  borderRadius: AppRadius.lg,
                  child: Column(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 32,
                        color:
                            (isDark
                                    ? AppColors.darkAccent
                                    : AppColors.lightAccent)
                                .withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Set your first growth goal',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GoalsScreen(),
                            ),
                          );
                          _load();
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Goal'),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GoalDetailScreen(goalId: activeGoal.id),
                      ),
                    );
                    _load();
                  },
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Neumorphic(
                    padding: const EdgeInsets.all(16),
                    borderRadius: AppRadius.lg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                activeGoal.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (activeGoal.growthArea != null)
                              GrivioBadge(
                                label: activeGoal.growthArea!,
                                isAccent: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: activeGoal.progress / 100,
                            minHeight: 6,
                            backgroundColor: isDark
                                ? AppColors.darkProgressTrack
                                : AppColors.lightSecondarySurface,
                            color: isDark
                                ? AppColors.darkAccent
                                : AppColors.lightAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '${activeGoal.progress}% complete',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkAccent
                                    : AppColors.lightAccent,
                              ),
                            ),
                            const Spacer(),
                            if (activeGoal.targetDate != null)
                              Text(
                                'Target ${activeGoal.targetDate!.month}/${activeGoal.targetDate!.day}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkMutedText
                                      : AppColors.lightSecondaryText,
                                ),
                              ),
                          ],
                        ),
                        if (currentMilestone != null &&
                            currentMilestone.id.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_right_rounded,
                                size: 16,
                                color: isDark
                                    ? AppColors.darkAccent
                                    : AppColors.lightAccent,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Current milestone: ${currentMilestone.title}',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkSecondaryText
                                        : AppColors.lightSecondaryText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // ── Factual Daily Insight ─────────────────────────────────────
              if (totalToday > 0) ...[
                Neumorphic(
                  padding: const EdgeInsets.all(14),
                  borderRadius: AppRadius.md,
                  color: isDark
                      ? AppColors.darkAccentSurface
                      : AppColors.lightAccentSurface,
                  borderColor: isDark
                      ? AppColors.darkAccent.withValues(alpha: 0.3)
                      : AppColors.lightAccent.withValues(alpha: 0.2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.lightAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          remaining > 0
                              ? '$remaining task${remaining == 1 ? '' : 's'} remaining today ($completedToday done).'
                              : 'All $totalToday tasks for today are completed. Excellent work!',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkPrimaryText
                                : AppColors.lightPrimaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Quick Actions ─────────────────────────────────────────────
              FilledButton.icon(
                onPressed: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const AddTaskScreen()),
                  );
                  if (created == true) _load();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Task'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DailyPlannerScreen()),
                ),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Plan my day'),
              ),
              const SizedBox(height: 16),

              // ── Daily Reflection Banner ───────────────────────────────────
              if (_todayReflection == null)
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WeeklyReviewScreen(),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Neumorphic(
                    padding: const EdgeInsets.all(14),
                    borderRadius: AppRadius.lg,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? AppColors.darkAccent
                                        : AppColors.lightAccent)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
                            color: isDark
                                ? AppColors.darkAccent
                                : AppColors.lightAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How was your day?',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Take a quick moment to reflect →',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.darkMutedText
                                      : AppColors.lightSecondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTaskRow extends StatelessWidget {
  const _HomeTaskRow({
    required this.task,
    required this.onToggle,
    required this.onTap,
  });

  final GrivioTask task;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  bool _isDueToday(DateTime due) {
    final now = DateTime.now();
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final done = task.status == 'completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Checkbox(value: done, onChanged: (_) => onToggle()),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done
                            ? (isDark
                                  ? AppColors.darkMutedText
                                  : AppColors.lightMutedText)
                            : (isDark
                                  ? AppColors.darkPrimaryText
                                  : AppColors.lightPrimaryText),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (task.dueDate != null &&
                            _isDueToday(task.dueDate!) &&
                            !done) ...[
                          const GrivioBadge(label: 'Today', isAccent: true),
                          const SizedBox(width: 6),
                        ],
                        if (task.estimatedMinutes != null)
                          Text(
                            '${task.estimatedMinutes} min',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkMutedText
                                  : AppColors.lightSecondaryText,
                            ),
                          ),
                        if (task.goalName != null) ...[
                          Text(
                            ' · ${task.goalName}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkAccent
                                  : AppColors.lightAccent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (task.priority == 'high') ...[
                const SizedBox(width: 6),
                const GrivioBadge(label: 'High', isError: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
