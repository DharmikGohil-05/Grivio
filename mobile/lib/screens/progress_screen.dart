import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/progress_service.dart';
import '../widgets/neumorphic.dart';
import 'weekly_review_screen.dart';

/// Progress screen — personal activity and growth summary report.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _service = ProgressService();
  String _range = 'week'; // week | month | 3months
  ProgressData? _data;
  bool _loading = true;
  String? _error;

  static const _ranges = {
    'week': 'Week',
    'month': 'Month',
    '3months': '3 Months',
  };

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
      final data = await _service.getProgress(_range);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load progress. Pull to retry.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            8,
            AppSpacing.pagePadding,
            40,
          ),
          children: [
            Text(
              'See how your work and habits are compounding.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
              ),
            ),
            const SizedBox(height: 16),

            // Range selector
            Wrap(
              spacing: 8,
              children: _ranges.entries.map((e) {
                final selected = _range == e.key;
                return ChoiceChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _range = e.key);
                    _load();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_data != null) ...[
              // 2x2 Summary Metric Grid
              _SummaryGrid(summary: _data!.summary),
              const SizedBox(height: 24),

              // Task Completion Trend
              const SectionLabel('Task completion'),
              _TrendChart(
                points: _data!.taskTrend,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                emptyText: 'Complete a task to build your trend history.',
                isLine: true,
              ),
              const SizedBox(height: 24),

              // Focus Time Trend
              const SectionLabel('Focus time'),
              _TrendChart(
                points: _data!.focusTrend,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                emptyText: 'Complete a focus session to see focus trends.',
                unit: 'min',
              ),
              const SizedBox(height: 24),

              // Goal Progress
              const SectionLabel('Goal progress'),
              if (_data!.goalProgress.isEmpty)
                Neumorphic(
                  padding: const EdgeInsets.all(16),
                  borderRadius: AppRadius.md,
                  child: Text(
                    'Create an active goal to track your progress here.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkMutedText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                )
              else
                ..._data!.goalProgress.map((g) => _GoalProgressCard(goal: g)),
              const SizedBox(height: 24),

              // Insights
              const SectionLabel('Activity insights'),
              if (_data!.insights.isEmpty)
                Neumorphic(
                  padding: const EdgeInsets.all(16),
                  borderRadius: AppRadius.md,
                  child: Text(
                    'Log more tasks and focus sessions to unlock personalized insights.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkMutedText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                )
              else
                Neumorphic(
                  padding: const EdgeInsets.all(16),
                  borderRadius: AppRadius.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _data!.insights.map((ins) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkAccent
                                    : AppColors.lightAccent,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                ins,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  height: 1.4,
                                  color: isDark
                                      ? AppColors.darkPrimaryText
                                      : AppColors.lightPrimaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 24),

              // Weekly Review Banner
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WeeklyReviewScreen()),
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Neumorphic(
                  padding: const EdgeInsets.all(16),
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
                          Icons.auto_stories_outlined,
                          size: 20,
                          color: isDark
                              ? AppColors.darkAccent
                              : AppColors.lightAccent,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weekly Review',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Reflect on your achievements and areas to improve →',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkAccent
                                    : AppColors.lightAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: isDark
                            ? AppColors.darkMutedText
                            : AppColors.lightMutedText,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final ProgressSummary summary;

  String _focus() {
    final h = summary.focusMinutes ~/ 60;
    final m = summary.focusMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = [
      (
        'Tasks completed',
        '${summary.tasksCompleted}',
        Icons.check_circle_outline,
      ),
      ('Focus time', _focus(), Icons.timer_outlined),
      (
        'Completion rate',
        '${summary.completionRate}%',
        Icons.trending_up_rounded,
      ),
      ('Active goals', '${summary.activeGoals}', Icons.flag_outlined),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: items.map((it) {
        return Neumorphic(
          padding: const EdgeInsets.all(12),
          borderRadius: AppRadius.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    it.$3,
                    size: 16,
                    color: isDark
                        ? AppColors.darkAccent
                        : AppColors.lightAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      it.$1,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                it.$2,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.points,
    required this.color,
    required this.emptyText,
    this.unit,
    this.isLine = false,
  });

  final List<TrendPoint> points;
  final Color color;
  final String emptyText;
  final String? unit;
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (points.isEmpty) {
      return Neumorphic(
        padding: const EdgeInsets.all(16),
        borderRadius: AppRadius.md,
        child: Text(
          emptyText,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: isDark
                ? AppColors.darkMutedText
                : AppColors.lightSecondaryText,
          ),
        ),
      );
    }

    final maxY = points
        .map((p) => p.value)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, 1 << 30)
        .toDouble();

    final gridColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.5)
        : AppColors.lightBorder.withValues(alpha: 0.6);

    final labelStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: isDark ? AppColors.darkMutedText : AppColors.lightMutedText,
    );

    return Neumorphic(
      height: 190,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      borderRadius: AppRadius.lg,
      child: isLine
          ? LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY * 1.2,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 3 : 1,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: gridColor, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) =>
                          Text(v.toInt().toString(), style: labelStyle),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final d = points[i].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${d.month}/${d.day}', style: labelStyle),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: points
                        .asMap()
                        .entries
                        .map(
                          (e) => FlSpot(
                            e.key.toDouble(),
                            e.value.value.toDouble(),
                          ),
                        )
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: color,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3.5,
                        color: color,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.25),
                          color.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) =>
                          Text(v.toInt().toString(), style: labelStyle),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final d = points[i].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${d.month}/${d.day}', style: labelStyle),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: points.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value.toDouble(),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color, color.withValues(alpha: 0.55)],
                        ),
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY * 1.2,
                          color: isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.3)
                              : AppColors.lightSecondarySurface,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _GoalProgressCard extends StatelessWidget {
  const _GoalProgressCard({required this.goal});
  final GoalProgressItem goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkPrimaryText
                          : AppColors.lightPrimaryText,
                    ),
                  ),
                ),
                Text(
                  '${goal.progress}%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkAccent
                        : AppColors.lightAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: goal.progress / 100,
                minHeight: 6,
                backgroundColor: isDark
                    ? AppColors.darkProgressTrack
                    : AppColors.lightSecondarySurface,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
            ),
            if (goal.targetDate != null) ...[
              const SizedBox(height: 6),
              Text(
                'Target ${goal.targetDate!.month}/${goal.targetDate!.day}/${goal.targetDate!.year}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkMutedText
                      : AppColors.lightSecondaryText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
