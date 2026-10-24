import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/task_service.dart';
import '../widgets/neumorphic.dart';
import 'ai_breakdown_sheet.dart';
import 'ai_improve_sheet.dart';
import 'ai_subtask_sheet.dart';
import 'focus_screen.dart';

/// Task detail screen — shows task overview, action triggers,
/// and interactive subtask checklist.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _service = TaskService();
  GrivioTask? _task;
  List<Subtask> _subtasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await _service.listTasks();
      final task = tasks.firstWhere((t) => t.id == widget.taskId);
      final subtasks = await _service.listSubtasks(widget.taskId);
      if (mounted) {
        setState(() {
          _task = task;
          _subtasks = subtasks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStatus() async {
    final t = _task;
    if (t == null) return;
    await _service.setTaskStatus(
      widget.taskId,
      t.status == 'completed' ? 'pending' : 'completed',
    );
    _load();
  }

  Future<void> _deleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteTask(widget.taskId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _toggleSubtask(Subtask s) async {
    await _service.updateSubtask(s.id, {'isCompleted': !s.isCompleted});
    _load();
  }

  Future<void> _addSubtask() async {
    final c = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Subtask'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Subtask Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await _service.createSubtask(widget.taskId, title);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final task = _task;
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Task not found')),
      );
    }

    final completed = _subtasks.where((s) => s.isCompleted).length;
    final done = task.status == 'completed';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: _deleteTask,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          // ── Task Header Card ──────────────────────────────────────────
          Neumorphic(
            padding: const EdgeInsets.all(16),
            borderRadius: AppRadius.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
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
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (task.priority == 'high')
                      const GrivioBadge(label: 'Priority: High', isError: true)
                    else if (task.priority == 'medium')
                      const GrivioBadge(label: 'Priority: Med', isWarning: true)
                    else
                      const GrivioBadge(label: 'Priority: Low'),
                    if (task.dueDate != null)
                      GrivioBadge(
                        label:
                            'Due: ${task.dueDate!.month}/${task.dueDate!.day}/${task.dueDate!.year}',
                        icon: Icons.calendar_today_outlined,
                      ),
                    if (task.estimatedMinutes != null)
                      GrivioBadge(
                        label: '${task.estimatedMinutes} min',
                        icon: Icons.schedule_outlined,
                      ),
                    if (task.category != null)
                      GrivioBadge(label: task.category!),
                    if (task.goalName != null)
                      GrivioBadge(
                        label: 'Goal: ${task.goalName}',
                        isAccent: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Primary Action Row ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _toggleStatus,
                  icon: Icon(
                    done ? Icons.refresh : Icons.check_rounded,
                    size: 18,
                  ),
                  label: Text(done ? 'Reopen task' : 'Complete task'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FocusScreen(preselectedTaskId: task.id),
                    ),
                  ),
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: const Text('Start Focus'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Subtasks Section ──────────────────────────────────────────
          SectionLabel(
            'Subtasks ($completed/${_subtasks.length})',
            trailing: '+ Add Subtask',
            onTrailingTap: _addSubtask,
          ),
          if (_subtasks.isEmpty)
            Neumorphic(
              padding: const EdgeInsets.all(16),
              borderRadius: AppRadius.md,
              child: Center(
                child: Text(
                  'No subtasks yet. Break this task into smaller steps.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkMutedText
                        : AppColors.lightSecondaryText,
                  ),
                ),
              ),
            )
          else
            ..._subtasks.map(
              (s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: s.isCompleted,
                      onChanged: (_) => _toggleSubtask(s),
                    ),
                    Expanded(
                      child: Text(
                        s.title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: s.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: s.isCompleted
                              ? (isDark
                                    ? AppColors.darkMutedText
                                    : AppColors.lightMutedText)
                              : (isDark
                                    ? AppColors.darkPrimaryText
                                    : AppColors.lightPrimaryText),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () async {
                        await _service.deleteSubtask(s.id);
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),

          // ── AI Actions Group ───────────────────────────────────────────
          const SectionLabel('AI Assistants'),
          OutlinedButton.icon(
            onPressed: () async {
              final added = await showModalBottomSheet<int>(
                context: context,
                isScrollControlled: true,
                builder: (_) => AISubtaskSheet(
                  taskId: task.id,
                  taskTitle: task.title,
                  taskDescription: task.description,
                ),
              );
              if (added != null && added > 0) _load();
            },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Generate Subtasks with AI'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final applied = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => AIImproveSheet(
                  taskId: task.id,
                  title: task.title,
                  description: task.description,
                ),
              );
              if (applied == true) _load();
            },
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Improve Task Description & Settings'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final saved = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => AIBreakdownSheet(
                  saveGoalId: task.goalId,
                  title: task.title,
                  description: task.description,
                  onSaved: _load,
                ),
              );
              if (saved == true) _load();
            },
            icon: const Icon(Icons.account_tree_outlined, size: 18),
            label: const Text('Break Down into Project Phases'),
          ),
        ],
      ),
    );
  }
}
