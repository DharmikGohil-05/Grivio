import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/progress_service.dart';
import 'neumorphic.dart';

// =============================================================================
// GRIVIO EFFORT HEATMAP + STREAK
//
// A GitHub-style activity grid: one inset neumorphic cell per day, its
// color intensity showing how much effort the user put in that day
// (focus minutes + completed tasks, merged client-side from the existing
// /progress trend data — no backend change). A StreakBadge counts the
// consecutive active days ending today.
// =============================================================================

/// One day's merged effort. [effort] is an opaque "intensity units" value:
/// each 30 focus minutes and each completed task both count as one unit.
class EffortDay {
  const EffortDay({
    required this.date,
    required this.focusMinutes,
    required this.tasksCompleted,
  });

  final DateTime date;
  final int focusMinutes;
  final int tasksCompleted;

  int get effort => focusMinutes ~/ 30 + tasksCompleted;

  /// Date key without time, for map lookups.
  DateTime get dayKey => DateTime(date.year, date.month, date.day);
}

/// Merges the two /progress trend series (per-day task counts and focus
/// minutes) into one map of day → EffortDay.
Map<DateTime, EffortDay> mergeEffort(
  List<TrendPoint> taskTrend,
  List<TrendPoint> focusTrend,
) {
  final map = <DateTime, EffortDay>{};
  for (final p in taskTrend) {
    final k = DateTime(p.date.year, p.date.month, p.date.day);
    map[k] = EffortDay(
      date: k,
      focusMinutes: map[k]?.focusMinutes ?? 0,
      tasksCompleted: p.value,
    );
  }
  for (final p in focusTrend) {
    final k = DateTime(p.date.year, p.date.month, p.date.day);
    map[k] = EffortDay(
      date: k,
      focusMinutes: p.value,
      tasksCompleted: map[k]?.tasksCompleted ?? 0,
    );
  }
  return map;
}

/// Longest run of consecutive active days ending today or yesterday
/// (yesterday so a streak isn't "broken" before today is done).
int computeStreak(Map<DateTime, EffortDay> effortByDay) {
  var streak = 0;
  final today = DateTime.now();
  var cursor = DateTime(today.year, today.month, today.day);

  // Today counts if active; if not, start from yesterday without penalty.
  if ((effortByDay[cursor]?.effort ?? 0) > 0) {
    streak++;
  }
  cursor = cursor.subtract(const Duration(days: 1));
  while ((effortByDay[cursor]?.effort ?? 0) > 0) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// The effort heatmap: weeks as columns, Mon–Sun as rows. Cells are inset
/// wells whose color scales with that day's effort (0 = empty groove,
/// 4 = full accent→cyan). Cells stagger-fade in column by column.
class EffortHeatmap extends StatelessWidget {
  const EffortHeatmap({
    super.key,
    required this.effortByDay,
    this.weeks = 13,
    this.cellSize = 14,
    this.cellGap = 3,
  });

  /// dayKey → effort (see [mergeEffort]).
  final Map<DateTime, EffortDay> effortByDay;
  final int weeks;
  final double cellSize;
  final double cellGap;

  /// 5 intensity levels (0 = none). Colors derive from the theme tokens:
  /// level 0 is the recessed track; 1–3 step up through the accent;
  /// level 4 blends accent toward the supporting cyan for the peak.
  List<Color> _levels(bool isDark) {
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final cyan = isDark ? AppColors.darkCyan : AppColors.lightCyan;
    return [
      isDark
          ? AppColors.darkSecondarySurface
          : AppColors.lightSecondarySurface,
      accent.withValues(alpha: 0.30),
      accent.withValues(alpha: 0.60),
      accent,
      Color.lerp(accent, cyan, 0.45)!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final levels = _levels(isDark);
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    final muted = isDark ? AppColors.darkMutedText : AppColors.lightMutedText;

    // End the grid on today; walk back exactly [weeks] columns so the
    // rightmost column is always the current week.
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    // Monday-start weeks (matches the app's weekly review convention).
    final daysFromMonday = (todayKey.weekday - 1) % 7;
    final currentWeekStart = todayKey.subtract(
      Duration(days: daysFromMonday),
    );

    final maxEffort = effortByDay.values
        .map((e) => e.effort)
        .fold<int>(0, (a, b) => a > b ? a : b);

    // Row labels: Monday / Wednesday / Friday only, GitHub-style.
    const rowLabels = {0: 'M', 2: 'W', 4: 'F'};
    final labelStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 9,
      color: muted,
    );

    // The last column is the current (partial) week.
    final columns = List.generate(weeks, (w) {
      final weekStart = currentWeekStart.subtract(
        Duration(days: 7 * (weeks - 1 - w)),
      );
      return List.generate(7, (d) {
        final day = weekStart.add(Duration(days: d));
        if (day.isAfter(todayKey)) return null;
        return day;
      });
    });

    return Neumorphic(
      depth: 4,
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
              const SizedBox(width: 6),
              Text(
                'Effort heatmap',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'last $weeks weeks',
                style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: secondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // 13 columns at ~17 px each fit a phone width; on very small
            // screens the grid scrolls and the most recent weeks sit at
            // the right edge.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weekday label gutter
                SizedBox(
                  width: 14,
                  child: Column(
                    children: [
                      for (var r = 0; r < 7; r++)
                        SizedBox(
                          height: cellSize,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              rowLabels[r] ?? '',
                              style: labelStyle,
                            ),
                          ),
                        ).paddingEach(bottom: cellGap),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                for (final column in columns)
                  Padding(
                    padding: EdgeInsets.only(right: cellGap),
                    child: Column(
                      children: [
                        for (final day in column)
                          _HeatCell(
                            size: cellSize,
                            level: day == null
                                ? 0
                                : _levelFor(day, maxEffort),
                            isFuture: day == null,
                            levels: levels,
                          ).paddingEach(bottom: cellGap),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Legend + peak-effort caption
          Row(
            children: [
              Text('Less', style: TextStyle(fontSize: 10, color: muted, fontFamily: 'Inter')),
              const SizedBox(width: 6),
              for (var i = 0; i < levels.length; i++) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: levels[i],
                    borderRadius: BorderRadius.circular(3),
                    border: i == 0
                        ? Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text('More', style: TextStyle(fontSize: 10, color: muted, fontFamily: 'Inter')),
              const Spacer(),
              Text(
                '1 cell = 30 min focus or 1 task',
                style: TextStyle(fontSize: 10, color: secondary, fontFamily: 'Inter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Intensity level for a day, normalized against the period's peak so
  /// the scale always spans the user's actual effort range.
  int _levelFor(DateTime day, int maxEffort) {
    final effort = effortByDay[day]?.effort ?? 0;
    if (effort <= 0 || maxEffort <= 0) return 0;
    // 1..4, scaled against the peak.
    return 1 + ((effort / maxEffort) * 3).ceil().clamp(0, 3);
  }
}

/// One heatmap cell. Future days render as invisible spacers; past days
/// are inset wells that fade in (staggered via the caller's index order).
class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.size,
    required this.level,
    required this.isFuture,
    required this.levels,
  });

  final double size;
  final int level;
  final bool isFuture;
  final List<Color> levels;

  @override
  Widget build(BuildContext context) {
    if (isFuture) {
      return SizedBox(width: size, height: size);
    }

    return Tooltip(
      message: level == 0 ? 'No activity' : 'Effort level $level / 4',
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: levels[level.clamp(0, levels.length - 1)],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkBorder.withValues(alpha: 0.6)
                : AppColors.lightBorder,
          ),
          boxShadow: level > 0
              ? [
                  BoxShadow(
                    color: levels[level.clamp(0, levels.length - 1)]
                        .withValues(alpha: 0.35),
                    offset: const Offset(1, 1),
                    blurRadius: 3,
                  ),
                ]
              : [
                  // Empty days read as a subtle engraved groove.
                  BoxShadow(
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkShadowDark
                            : AppColors.lightShadowDark)
                        .withValues(alpha: 0.35),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                    spreadRadius: -1,
                  ),
                  BoxShadow(
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkShadowLight
                            : AppColors.lightShadowLight)
                        .withValues(alpha: 0.5),
                    offset: const Offset(-1, -1),
                    blurRadius: 2,
                    spreadRadius: -1,
                  ),
                ],
        ),
      ),
    );
  }
}

/// Consecutive-active-days pill. Purely presentational: the streak value
/// comes from [computeStreak] on the caller's merged effort data.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;

    return Neumorphic(
      depth: 3,
      borderRadius: AppRadius.pill,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            days > 0
                ? Icons.local_fire_department_rounded
                : Icons.crop_square_rounded,
            size: 15,
            color: days > 0 ? accent : (isDark
                ? AppColors.darkMutedText
                : AppColors.lightMutedText),
          ),
          const SizedBox(width: 6),
          Text(
            days > 0
                ? '$days day${days == 1 ? '' : 's'} streak'
                : 'Start a streak today',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: days > 0
                  ? accent
                  : (isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

extension _PaddingEach on Widget {
  Widget paddingEach({double bottom = 0}) =>
      Padding(padding: EdgeInsets.only(bottom: bottom), child: this);
}
