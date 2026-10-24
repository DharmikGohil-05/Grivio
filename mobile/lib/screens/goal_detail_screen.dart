import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/goal_service.dart';
import '../services/task_service.dart';
import '../widgets/neumorphic.dart';
import 'ai_breakdown_sheet.dart';

/// Goal Detail screen — displays goal details, linear progress,
/// AI breakdown launcher, vertical milestone timeline with status nodes,
/// and linked tasks.
class GoalDetailScreen extends StatefulWidget {
  const GoalDetailScreen({super.key, required this.goalId});
  final String goalId;

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final _service = GoalService();
  Goal? _goal;
  List<Milestone> _milestones = [];
  List<GrivioTask> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final goal = await _service.getGoal(widget.goalId);
      final milestones = await _service.listMilestones(widget.goalId);
      final tasks = await TaskService().listTasks(goalId: widget.goalId);
      if (mounted) {
        setState(() {
          _goal = goal;
          _milestones = milestones;
          _tasks = tasks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _cycleStatus(Milestone m) async {
    final next = m.status == 'pending'
        ? 'in_progress'
        : m.status == 'in_progress'
        ? 'completed'
        : 'pending';
    try {
      await _service.updateMilestone(m.id, {'status': next});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteMilestone(Milestone m) async {
    await _service.deleteMilestone(m.id);
    await _load();
  }

  Future<void> _addMilestone() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Milestone'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Milestone Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await _service.createMilestone(widget.goalId, {'title': title});
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final goal = _goal;
    if (goal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Goal not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined, size: 20),
            tooltip: 'Archive goal',
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _service.updateGoal(goal.id, {'status': 'archived'});
              if (!mounted) return;
              navigator.pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          // ── Goal Header ───────────────────────────────────────────────
          Neumorphic(
            padding: const EdgeInsets.all(16),
            borderRadius: AppRadius.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        goal.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (goal.growthArea != null)
                      GrivioBadge(label: goal.growthArea!, isAccent: true),
                  ],
                ),
                if (goal.whyItMatters != null &&
                    goal.whyItMatters!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    goal.whyItMatters!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: goal.progress / 100,
                    minHeight: 8,
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
                      '${goal.progress}% complete',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.lightAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${goal.completedMilestones}/${goal.milestoneCount} milestones',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkMutedText
                            : AppColors.lightSecondaryText,
                      ),
                    ),
                    const Spacer(),
                    if (goal.targetDate != null)
                      Text(
                        'Target: ${goal.targetDate!.month}/${goal.targetDate!.day}/${goal.targetDate!.year}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkMutedText
                              : AppColors.lightMutedText,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── AI Breakdown Action ─────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () async {
              final saved = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => AIBreakdownSheet(
                  goalId: goal.id,
                  title: goal.name,
                  description: goal.whyItMatters,
                  onSaved: _load,
                ),
              );
              if (saved == true) _load();
            },
            icon: const Icon(Icons.account_tree_outlined, size: 18),
            label: const Text('Break down with AI'),
          ),
          const SizedBox(height: 24),

          // ── Milestones Timeline ────────────────────────────────────────
          SectionLabel(
            'Milestones',
            trailing: '+ Add Milestone',
            onTrailingTap: _addMilestone,
          ),
          if (_milestones.isEmpty)
            Neumorphic(
              padding: const EdgeInsets.all(16),
              borderRadius: AppRadius.md,
              child: Center(
                child: Text(
                  'No milestones yet. Break your goal into actionable steps.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkMutedText
                        : AppColors.lightSecondaryText,
                  ),
                ),
              ),
            ),
          ..._milestones.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            final icon = m.status == 'completed'
                ? Icons.check_circle_rounded
                : m.status == 'in_progress'
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked;
            final color = m.status == 'completed'
                ? (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                : m.status == 'in_progress'
                ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                : (isDark ? AppColors.darkMutedText : AppColors.lightMutedText);

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        Icon(icon, color: color, size: 20),
                        if (i < _milestones.length - 1)
                          Expanded(
                            child: VerticalDivider(
                              width: 2,
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _cycleStatus(m),
                                    child: Text(
                                      m.title,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        decoration: m.status == 'completed'
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: m.status == 'completed'
                                            ? (isDark
                                                  ? AppColors.darkMutedText
                                                  : AppColors.lightMutedText)
                                            : (isDark
                                                  ? AppColors.darkPrimaryText
                                                  : AppColors.lightPrimaryText),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deleteMilestone(m),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              m.status.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: color,
                              ),
                            ),
                            // Linked tasks
                            ..._tasks
                                .where((t) => t.milestoneId == m.id)
                                .map(
                                  (t) => Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      children: [
                                        Icon(
                                          t.status == 'completed'
                                              ? Icons.check_rounded
                                              : Icons.circle_outlined,
                                          size: 14,
                                          color: t.status == 'completed'
                                              ? (isDark
                                                    ? AppColors.darkSuccess
                                                    : AppColors.lightSuccess)
                                              : (isDark
                                                    ? AppColors.darkMutedText
                                                    : AppColors
                                                          .lightSecondaryText),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            t.title,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              decoration:
                                                  t.status == 'completed'
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: t.status == 'completed'
                                                  ? (isDark
                                                        ? AppColors
                                                              .darkMutedText
                                                        : AppColors
                                                              .lightMutedText)
                                                  : (isDark
                                                        ? AppColors
                                                              .darkPrimaryText
                                                        : AppColors
                                                              .lightPrimaryText),
                                            ),
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
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
