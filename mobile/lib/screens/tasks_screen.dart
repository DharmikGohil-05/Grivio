import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/task_service.dart';
import '../widgets/neumorphic.dart';
import 'add_task_screen.dart';
import 'daily_planner_screen.dart';
import 'task_detail_screen.dart';

/// Tasks list — today / upcoming / completed filters with clean tactile rows.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _service = TaskService();
  String _filter = 'today';
  List<GrivioTask> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Fetches the user's tasks and applies the active filter client-side:
  /// 'today' = open tasks due today or with no due date, 'upcoming' =
  /// open tasks with any due date that isn't today (overdue included),
  /// 'completed' = everything marked done.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _service.listTasks();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      bool isToday(GrivioTask t) =>
          t.dueDate != null &&
          !t.dueDate!.isBefore(today) &&
          t.dueDate!.isBefore(today.add(const Duration(days: 1)));
      List<GrivioTask> filtered;
      if (_filter == 'today') {
        filtered = all
            .where(
              (t) =>
                  t.status != 'completed' &&
                  t.status != 'cancelled' &&
                  (isToday(t) || t.dueDate == null),
            )
            .toList();
      } else if (_filter == 'upcoming') {
        filtered = all
            .where(
              (t) =>
                  t.status != 'completed' &&
                  t.status != 'cancelled' &&
                  t.dueDate != null &&
                  !isToday(t),
            )
            .toList();
      } else {
        filtered = all.where((t) => t.status == 'completed').toList();
      }
      if (mounted) {
        setState(() {
          _tasks = filtered;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Sends the new status to the API and reloads, so the list always
  /// reflects server truth rather than only local state.
  Future<void> _toggleComplete(GrivioTask t) async {
    await _service.setTaskStatus(
      t.id,
      t.status == 'completed' ? 'pending' : 'completed',
    );
    await _load();
  }

  void _openTask(GrivioTask t) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)));
    _load();
  }

  void _addTask() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddTaskScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          // Shortcut to the AI daily planner — the same screen Home's
          // "Plan my day" button opens.
          IconButton(
            icon: const Icon(Icons.auto_awesome, size: 20),
            tooltip: 'Plan my day',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DailyPlannerScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              8,
              AppSpacing.pagePadding,
              8,
            ),
            child: Row(
              children: ['today', 'upcoming', 'completed'].map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f[0].toUpperCase() + f.substring(1)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _filter = f);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_box_outlined,
                            size: 44,
                            color:
                                (isDark
                                        ? AppColors.darkAccent
                                        : AppColors.lightAccent)
                                    .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filter == 'today'
                                ? 'No tasks for today'
                                : 'No $_filter tasks',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Clear focus creates momentum.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.darkMutedText
                                  : AppColors.lightSecondaryText,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _addTask,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Task'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pagePadding,
                        8,
                        AppSpacing.pagePadding,
                        80,
                      ),
                      itemCount: _tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _TaskRow(
                        task: _tasks[i],
                        onToggle: () => _toggleComplete(_tasks[i]),
                        onTap: () => _openTask(_tasks[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onTap,
  });
  final GrivioTask task;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final done = task.status == 'completed';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done
                          ? (isDark
                                ? AppColors.darkMutedText
                                : AppColors.lightMutedText)
                          : (isDark
                                ? AppColors.darkPrimaryText
                                : AppColors.lightPrimaryText),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (task.dueDate != null) ...[
                        Text(
                          'Due ${task.dueDate!.month}/${task.dueDate!.day}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkMutedText
                                : AppColors.lightSecondaryText,
                          ),
                        ),
                      ],
                      if (task.estimatedMinutes != null) ...[
                        Text(
                          ' · ${task.estimatedMinutes} min',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkMutedText
                                : AppColors.lightSecondaryText,
                          ),
                        ),
                      ],
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
                      if (task.subtaskCount > 0) ...[
                        Text(
                          ' · ${task.completedSubtasks}/${task.subtaskCount}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkMutedText
                                : AppColors.lightMutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (task.priority == 'high')
              const GrivioBadge(label: 'High', isError: true)
            else if (task.priority == 'medium')
              const GrivioBadge(label: 'Med', isWarning: true),
          ],
        ),
      ),
    );
  }
}
