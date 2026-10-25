import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/progress_service.dart';
import '../widgets/effort_heatmap.dart';
import '../widgets/neumorphic.dart';
import '../widgets/ui_kit.dart';
import 'weekly_review_screen.dart';

/// Progress screen — personal activity and growth summary report:
/// effort heatmap + streak, animated summary stats, animated trends and
/// goal progress cards, all on the neumorphic system.
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

  // The key is the value sent to the API; the label is what the chip
  // shows. Changing it triggers a fresh fetch with the new range.
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

  /// Every number here comes from GET /progress?range=…: the backend
  /// computes the summary, trends, per-goal progress and insight strings
  /// from the logged-in user's own records — the screen only formats them.
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
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;

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
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: secondary),
            ),
            const SizedBox(height: 16),

            // Range selector — tactile chips instead of Material ChoiceChips.
            Wrap(
              spacing: 8,
              children: _ranges.entries.map((e) {
                final selected = _range == e.key;
                return NeumorphicChip(
                  label: e.value,
                  selected: selected,
                  onTap: () {
                    if (_range == e.key) return;
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
              // Effort heatmap + streak — the "how much am I actually
              // putting in" view, merged client-side from the trend data.
              StaggeredIn(
                child: Row(
                  children: [
                    StreakBadge(
                      days: computeStreak(
                        mergeEffort(_data!.taskTrend, _data!.focusTrend),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _range == 'week'
                          ? 'This week'
                          : _range == 'month'
                          ? 'This month'
                          : 'Last 3 months',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StaggeredIn(
                delay: const Duration(milliseconds: 80),
                child: EffortHeatmap(
                  effortByDay: mergeEffort(_data!.taskTrend, _data!.focusTrend),
                ),
              ),
              const SizedBox(height: 24),

              // 2x2 Summary Metric Grid
              StaggeredIn(
                delay: const Duration(milliseconds: 140),
                child: _SummaryGrid(summary: _data!.summary),
              ),
              const SizedBox(height: 24),

              // Task Completion Trend
              const SectionLabel('Task completion'),
              _TrendChart(
                points: _data!.taskTrend,
                color: accent,
                emptyText: 'Complete a task to build your trend history.',
                isLine: true,
              ),
              const SizedBox(height: 24),

              // Focus Time Trend
              const SectionLabel('Focus time'),
              _TrendChart(
                points: _data!.focusTrend,
                color: accent,
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
                      color: secondary,
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
                      color: secondary,
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
                                color: accent,
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

              // Weekly Review Banner — entry point to the Weekly Review
              // screen (weekly stats, reflection form, AI Growth Review).
              StaggeredIn(
                delay: const Duration(milliseconds: 200),
                child: InkWell(
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
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            Icons.auto_stories_outlined,
                            size: 20,
                            color: accent,
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
                                  color: accent,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final labelColor = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;

    final numberStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    );

    String focus(int minutes) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    Widget cell(
      String label,
      Widget valueWidget,
      IconData icon,
    ) {
      return Neumorphic(
        padding: const EdgeInsets.all(12),
        borderRadius: AppRadius.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: labelColor,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            valueWidget,
          ],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        cell(
          'Tasks completed',
          AnimatedCountUp(value: summary.tasksCompleted, format: (v) => '$v', style: numberStyle),
          Icons.check_circle_outline,
        ),
        cell(
          'Focus time',
          AnimatedCountUp(value: summary.focusMinutes, format: focus, style: numberStyle),
          Icons.timer_outlined,
        ),
        cell(
          'Completion rate',
          AnimatedCountUp(
            value: summary.completionRate,
            format: (v) => '$v%',
            style: numberStyle,
          ),
          Icons.trending_up_rounded,
        ),
        cell(
          'Active goals',
          AnimatedCountUp(value: summary.activeGoals, format: (v) => '$v', style: numberStyle),
          Icons.flag_outlined,
        ),
      ],
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
    final cyan = isDark ? AppColors.darkCyan : AppColors.lightCyan;

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

    // Clamp to at least 1 so an all-zero series still gets a usable
    // vertical axis instead of a degenerate 0-height chart.
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

    // fl_chart's duration/curve animate data changes (range switches,
    // refetches), so the chart morphs instead of snapping.
    const chartDuration = Duration(milliseconds: 700);
    const chartCurve = Curves.easeOutCubic;

    return Neumorphic(
      height: 190,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      borderRadius: AppRadius.lg,
      child: isLine
          ? LineChart(
              duration: chartDuration,
              curve: chartCurve,
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
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            '${points[s.x.toInt()].value}${unit == null ? '' : ' $unit'}',
                            TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkPrimaryText
                                  : AppColors.lightPrimaryText,
                            ),
                          ),
                        )
                        .toList(),
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
                    // Indigo → cyan stroke (left to right), mirroring the
                    // web trend chart's gradient line.
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [color, cyan],
                    ),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3.5,
                        color: cyan,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      // Cyan fading into the accent — same area fill the
                      // web trend chart uses.
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cyan.withValues(alpha: 0.34),
                          color.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : BarChart(
              duration: chartDuration,
              curve: chartCurve,
              BarChartData(
                maxY: maxY * 1.2,
                borderData: FlBorderData(show: false),
                // Value gridlines match the web chart frame.
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
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${rod.toY.toInt()}${unit == null ? '' : ' $unit'}',
                      TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkPrimaryText
                            : AppColors.lightPrimaryText,
                      ),
                    ),
                  ),
                ),
                barGroups: points.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value.toDouble(),
                        // Cyan at the top fading into indigo at the base —
                        // the reference bar treatment (same as the web).
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [cyan, color],
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
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Neumorphic(
        depth: 4,
        borderRadius: AppRadius.md,
        padding: const EdgeInsets.all(14),
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
                AnimatedCountUp(
                  value: goal.progress,
                  format: (v) => '$v%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedProgressBar(value: goal.progress / 100),
            if (goal.targetDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Target ${goal.targetDate!.month}/${goal.targetDate!.day}/${goal.targetDate!.year}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
