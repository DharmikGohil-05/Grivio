import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/goal_service.dart';
import '../widgets/neumorphic.dart';
import 'add_goal_screen.dart';
import 'goal_detail_screen.dart';

/// Goals list screen — shows user's active, completed, and archived goals.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _service = GoalService();
  String _filter = 'active';
  List<Goal> _goals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads this user's goals for the selected status. The filter is
  /// passed to the API, which scopes results to the logged-in user —
  /// the client never picks whose goals to show.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final goals = await _service.listGoals(status: _filter);
      if (mounted) {
        setState(() {
          _goals = goals;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Reloads after returning from detail/add screens so edits made
  /// there show up without a manual pull-to-refresh.
  void _openGoal(Goal g) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: g.id)));
    _load();
  }

  void _addGoal() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddGoalScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGoal,
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              8,
              AppSpacing.pagePadding,
              8,
            ),
            child: Row(
              children: ['active', 'completed', 'archived'].map((f) {
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
                : _goals.isEmpty
                ? _EmptyGoals(filter: _filter, onAdd: _addGoal)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pagePadding,
                        8,
                        AppSpacing.pagePadding,
                        80,
                      ),
                      itemCount: _goals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _GoalCard(
                        goal: _goals[i],
                        onTap: () => _openGoal(_goals[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});
  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Neumorphic(
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                if (goal.growthArea != null) ...[
                  const SizedBox(width: 8),
                  GrivioBadge(label: goal.growthArea!, isAccent: true),
                ],
              ],
            ),
            if (goal.whyItMatters != null && goal.whyItMatters!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                goal.whyItMatters!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkSecondaryText
                      : AppColors.lightSecondaryText,
                ),
              ),
            ],
            const SizedBox(height: 14),
            // goal.progress is a server-computed 0–100 percentage; the
            // bar simply maps it onto 0.0–1.0 for the indicator.
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progress / 100,
                minHeight: 6,
                backgroundColor: isDark
                    ? AppColors.darkProgressTrack
                    : AppColors.lightSecondarySurface,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${goal.progress}%',
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
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.filter, required this.onAdd});
  final String filter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 44,
              color: (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              filter == 'active' ? 'No active goals' : 'No $filter goals',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Turn aspirations into clear, trackable milestones.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: isDark
                    ? AppColors.darkMutedText
                    : AppColors.lightSecondaryText,
              ),
            ),
            if (filter == 'active') ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Create Goal'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
