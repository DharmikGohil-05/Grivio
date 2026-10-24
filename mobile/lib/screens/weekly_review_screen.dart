import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/api_client.dart';
import '../services/weekly_review_service.dart';
import '../widgets/neumorphic.dart';

/// Weekly review — real weekly statistics + structured reflection form.
/// Includes AI Growth Review report tied explicitly to selected week.
class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  final _service = WeeklyReviewService();
  DateTime _weekStart = _mondayOf(DateTime.now());
  WeeklyStats? _stats;
  WeeklyReview? _review;
  List<WeeklyReview> _previous = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _biggestWin = TextEditingController();
  final _needsAttention = TextEditingController();
  final _nextWeek = TextEditingController();
  final _reflection = TextEditingController();

  final _ai = AIService();
  AIWeeklyReview? _aiReview;
  String? _aiReviewWeek;
  bool _aiLoading = false;
  String? _aiError;

  /// Weeks start on Monday: subtract (weekday − 1) days from any date
  /// in that week, which also gives Monday for Monday itself.
  static DateTime _mondayOf(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  String _fmt(DateTime d) => '${d.month}/${d.day}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _biggestWin.dispose();
    _needsAttention.dispose();
    _nextWeek.dispose();
    _reflection.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getWeek(
        _weekStart.toIso8601String().substring(0, 10),
      );
      final prev = await _service.list();
      if (!mounted) return;
      setState(() {
        _stats = data['stats'] as WeeklyStats;
        _review = data['review'] as WeeklyReview?;
        _previous = prev;
        _biggestWin.text = _review?.biggestWin ?? '';
        _needsAttention.text = _review?.needsAttention ?? '';
        _nextWeek.text = _review?.nextWeekFocus ?? '';
        _reflection.text = _review?.summary ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load this week.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _service.upsert(
        weekStart: _weekStart.toIso8601String().substring(0, 10),
        biggestWin: _biggestWin.text.trim(),
        needsAttention: _needsAttention.text.trim(),
        nextWeekFocus: _nextWeek.text.trim(),
        summary: _reflection.text.trim(),
      );
      if (mounted) {
        setState(() {
          _review = saved;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Weekly review saved')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save review. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Navigating weeks also drops any AI review generated for the old
  /// week, so a stale report is never shown under new dates.
  void _shiftWeek(int days) {
    setState(() => _weekStart = _weekStart.add(Duration(days: days)));
    _aiReviewWeek = null;
    _aiReview = null;
    _aiError = null;
    _load();
  }

  /// Read-only AI call: the response is kept in this screen's state only.
  /// The week it was generated for is recorded so the card can be hidden
  /// if the user navigates to a different week.
  Future<void> _generateAI() async {
    if (_aiLoading) return;
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });
    try {
      final weekStr = _weekStart.toIso8601String().substring(0, 10);
      final review = await _ai.generateWeeklyReview(weekStr);
      if (!mounted) return;
      setState(() {
        _aiReview = review;
        _aiReviewWeek = weekStr;
        _aiLoading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _aiError = e.statusCode == 401
              ? 'Your session expired. Please sign in again.'
              : e.message,
        );
        _aiLoading = false;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiError = 'Could not reach the server. Try again.';
          _aiLoading = false;
        });
      }
    }
  }

  /// Hides the AI report without touching anything else — the saved
  /// weekly review (the reflection fields below) is separate and stays.
  void _dismissAI() {
    setState(() {
      _aiReview = null;
      _aiReviewWeek = null;
      _aiError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final weekEnd = _weekStart.add(const Duration(days: 6));

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Review')),
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
              'Take a moment to see what moved forward and where to focus next.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
              ),
            ),
            const SizedBox(height: 16),

            // Week Selector Row
            Neumorphic(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              borderRadius: AppRadius.md,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _shiftWeek(-7),
                    icon: const Icon(Icons.chevron_left),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '${_fmt(_weekStart)} – ${_fmt(weekEnd)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _shiftWeek(7),
                    icon: const Icon(Icons.chevron_right),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
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
            else ...[
              if (_stats != null) _WeekStatsGrid(stats: _stats!),
              const SizedBox(height: 20),

              // AI Growth Review Trigger
              OutlinedButton.icon(
                onPressed: _aiLoading ? null : _generateAI,
                icon: _aiLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _aiLoading
                      ? 'Generating growth review...'
                      : 'Generate AI Growth Review',
                ),
              ),
              if (_aiError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _aiError!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkError
                              : AppColors.lightError,
                        ),
                      ),
                      TextButton(
                        onPressed: _generateAI,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              // Only show the AI card if it was generated for the week
              // currently on screen — otherwise last week's AI text could
              // appear under this week's stats.
              if (_aiReview != null &&
                  _aiReviewWeek ==
                      _weekStart.toIso8601String().substring(0, 10)) ...[
                const SizedBox(height: 12),
                _AIReviewCard(
                  review: _aiReview!,
                  onRegenerate: _generateAI,
                  onDismiss: _dismissAI,
                ),
              ],
              const SizedBox(height: 24),

              // Reflection Questions
              _ReflectionField(
                label: 'Biggest Win',
                hint: 'What went well and gave you momentum this week?',
                controller: _biggestWin,
              ),
              const SizedBox(height: 16),
              _ReflectionField(
                label: 'Needs Attention',
                hint: 'What held you back or needs a course correction?',
                controller: _needsAttention,
              ),
              const SizedBox(height: 16),
              _ReflectionField(
                label: 'Next Week Focus',
                hint: 'What are your top 1–3 priorities for the upcoming week?',
                controller: _nextWeek,
              ),
              const SizedBox(height: 16),
              _ReflectionField(
                label: 'General Reflection (optional)',
                hint: 'How did this week feel overall?',
                controller: _reflection,
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving ? 'Saving review...' : 'Save Weekly Review',
                ),
              ),
              const SizedBox(height: 28),

              // Previous Reviews History
              if (_previous.isNotEmpty) ...[
                const SectionLabel('Previous Reviews'),
                ..._previous.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setState(
                          () => _weekStart = DateTime.parse(r.weekStart),
                        );
                        _load();
                      },
                      borderRadius: BorderRadius.circular(AppRadius.md),
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
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r.weekStart} – ${r.weekEnd}',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.biggestWin ??
                                        r.summary ??
                                        'Review recorded',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: isDark
                                  ? AppColors.darkMutedText
                                  : AppColors.lightMutedText,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 2×2 grid of the backend-computed weekly stats (tasks completed,
/// focus logged, goals progressed, completion rate). The client only
/// formats these numbers for the selected Monday-start week.
class _WeekStatsGrid extends StatelessWidget {
  const _WeekStatsGrid({required this.stats});
  final WeeklyStats stats;

  String _focus() {
    final h = stats.focusMinutes ~/ 60;
    final m = stats.focusMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = [
      ('Tasks completed', '${stats.tasksCompleted}'),
      ('Focus logged', _focus()),
      ('Goals progressed', '${stats.goalsProgressed}'),
      ('Completion rate', '${stats.completionRate}%'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: items.map((it) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                it.$2,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkPrimaryText
                      : AppColors.lightPrimaryText,
                ),
              ),
              Text(
                it.$1,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkSecondaryText
                      : AppColors.lightSecondaryText,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ReflectionField extends StatelessWidget {
  const _ReflectionField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 3,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: isDark
                ? AppColors.darkSecondaryText
                : AppColors.lightSecondaryText,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: const InputDecoration(hintText: 'Write your thoughts...'),
        ),
      ],
    );
  }
}

/// Structured AI Growth Review card. The summary line is real,
/// backend-computed stats; the sections below are the AI's
/// interpretation of them. Regenerate re-runs the read-only AI call,
/// and dismiss just hides the card — neither changes saved data.
class _AIReviewCard extends StatelessWidget {
  const _AIReviewCard({
    required this.review,
    required this.onRegenerate,
    required this.onDismiss,
  });

  final AIWeeklyReview review;
  final VoidCallback onRegenerate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final s = review.summary;
    final focus = s.focusMinutes ~/ 60 > 0
        ? '${s.focusMinutes ~/ 60}h ${s.focusMinutes % 60}m'
        : '${s.focusMinutes}m';

    return Neumorphic(
      padding: const EdgeInsets.all(16),
      borderRadius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI Growth Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${s.tasksCompleted} task${s.tasksCompleted == 1 ? '' : 's'} completed · $focus focus · ${s.goalsProgressed} goal${s.goalsProgressed == 1 ? '' : 's'} progressed',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
            ),
          ),
          const SizedBox(height: 12),
          _listSection('Wins worth noticing', review.wins, isDark),
          _listSection(
            'Progress highlights',
            review.progressHighlights,
            isDark,
          ),
          _listSection('Observed patterns', review.patterns, isDark),
          _listSection('What got in the way', review.challenges, isDark),
          _listSection(
            'Priorities for next week',
            review.nextWeekPriorities,
            isDark,
          ),
          _listSection('One small action', review.suggestedActions, isDark),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Regenerate'),
            ),
          ),
        ],
      ),
    );
  }

  /// Skips rendering a section entirely when the AI returned no items
  /// for it, instead of showing an empty heading.
  Widget _listSection(String title, List<String> items, bool isDark) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkAccent
                          : AppColors.lightAccent,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      it,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.4,
                        color: isDark
                            ? AppColors.darkPrimaryText
                            : AppColors.lightPrimaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
