import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/profile_service.dart';
import '../widgets/neumorphic.dart';
import '../widgets/ui_kit.dart';

/// 4-step first-time personalization wizard.
///
/// Redesigned as a tactile onboarding experience: ambient background,
/// per-step hero icon in a neumorphic circle, pill step indicator, animated
/// page transitions and neumorphic selectable options. All validation, API
/// calls and payloads are unchanged.
class SetupFlowScreen extends StatefulWidget {
  const SetupFlowScreen({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends State<SetupFlowScreen> {
  final _page = PageController();
  int _step = 0;
  bool _saving = false;
  String? _error;

  final _name = TextEditingController();
  final Set<String> _growthAreas = {};
  final _mainGoal = TextEditingController();
  String? _dailyTime;

  static const _allAreas = [
    'Career',
    'Learning',
    'Fitness',
    'Personal',
    'Finance',
    'Communication',
    'Other',
  ];
  static const _allTimes = ['30 minutes', '1 hour', '2 hours', '3+ hours'];
  static const _timeIcons = [
    Icons.timer_outlined,
    Icons.hourglass_bottom_outlined,
    Icons.hourglass_empty,
    Icons.bolt_outlined,
  ];

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _mainGoal.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && _name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (_step == 1 && _growthAreas.isEmpty) {
      setState(() => _error = 'Select at least one growth area');
      return;
    }
    setState(() => _error = null);
    if (_step < 3) {
      setState(() => _step++);
      _page.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() {
      _step--;
      _error = null;
    });
    _page.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProfileService().updateProfile({
        'name': _name.text.trim(),
        'growthAreas': _growthAreas.toList(),
        'mainGoal': _mainGoal.text.trim(),
        if (_dailyTime != null) 'dailyAvailableTime': _dailyTime,
        'setupCompleted': true,
      });
      widget.onFinished();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;

    const heroes = [
      Icons.waving_hand_rounded,
      Icons.explore_outlined,
      Icons.flag_outlined,
      Icons.schedule_rounded,
    ];

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: Column(
              children: [
                // ── Header: wordmark + step pills ──────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                  child: Row(
                    children: [
                      if (_step > 0)
                        NeumorphicButton(
                          padding: const EdgeInsets.all(8),
                          onPressed: _back,
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                          ),
                        )
                      else
                        const GrivioWordmark(fontSize: 15, letterSpacing: 3.4),
                      const Spacer(),
                      ...List.generate(4, (i) {
                        final active = i <= _step;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          margin: const EdgeInsets.only(left: 6),
                          width: active && i == _step ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? (isDark
                                      ? AppColors.darkAccent
                                      : AppColors.lightAccent)
                                : (isDark
                                      ? AppColors.darkProgressTrack
                                      : AppColors.lightSecondarySurface),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _stepName(theme, secondary, heroes[0]),
                      _stepAreas(theme, secondary, heroes[1]),
                      _stepGoal(theme, secondary, heroes[2]),
                      _stepTime(theme, secondary, heroes[3]),
                    ],
                  ),
                ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.pagePadding,
                      right: AppSpacing.pagePadding,
                      bottom: 8,
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkError
                            : AppColors.lightError,
                      ),
                    ),
                  ),

                // ── Footer: step counter + primary action ──────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding,
                    8,
                    AppSpacing.pagePadding,
                    AppSpacing.pagePadding,
                  ),
                  child: NeumorphicButton(
                    isAccent: true,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    onPressed: _saving ? null : _next,
                    child: _saving
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Saving...'),
                            ],
                          )
                        : Text(
                            _step == 3
                                ? 'Finish Setup'
                                : 'Continue  ·  Step ${_step + 1} of 4',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepHead(
    ThemeData theme,
    Color secondary,
    IconData hero,
    String title,
    String subtitle,
  ) {
    return StaggeredIn(
      key: ValueKey(title),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeumorphicIconCircle(icon: hero, size: 60, iconSize: 26),
          const SizedBox(height: 18),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: secondary),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _stepName(ThemeData theme, Color secondary, IconData hero) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        _stepHead(
          theme,
          secondary,
          hero,
          'What should we call you?',
          'Your name personalizes your daily greeting and reflections.',
        ),
        TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Your name',
            prefixIcon: Icon(Icons.person_outline, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _stepAreas(ThemeData theme, Color secondary, IconData hero) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        _stepHead(
          theme,
          secondary,
          hero,
          'What do you want to improve?',
          'Select the areas you are focusing on right now.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _allAreas.map((area) {
            final selected = _growthAreas.contains(area);
            return _AreaChip(
              label: area,
              selected: selected,
              onTap: () => setState(() {
                if (selected) {
                  _growthAreas.remove(area);
                } else {
                  _growthAreas.add(area);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _stepGoal(ThemeData theme, Color secondary, IconData hero) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        _stepHead(
          theme,
          secondary,
          hero,
          "What is your primary goal?",
          'A single clear target. Example: "Publish our mobile app and reach 1,000 active users."',
        ),
        TextField(
          controller: _mainGoal,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Main goal statement',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.flag_outlined, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _stepTime(ThemeData theme, Color secondary, IconData hero) {
    final isDark = theme.brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        _stepHead(
          theme,
          secondary,
          hero,
          'How much time can you commit daily?',
          'Used to plan your daily workload realistically.',
        ),
        ...List.generate(_allTimes.length, (i) {
          final t = _allTimes[i];
          final selected = _dailyTime == t;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Neumorphic(
              inset: selected,
              depth: selected ? 3 : 5,
              borderRadius: AppRadius.lg,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              borderColor: selected
                  ? (isDark
                        ? AppColors.darkAccent.withValues(alpha: 0.5)
                        : AppColors.lightAccent.withValues(alpha: 0.4))
                  : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => setState(() => _dailyTime = t),
                child: Row(
                  children: [
                    Icon(
                      _timeIcons[i],
                      size: 20,
                      color: selected
                          ? (isDark
                                ? AppColors.darkAccent
                                : AppColors.lightAccent)
                          : (isDark
                                ? AppColors.darkMutedText
                                : AppColors.lightMutedText),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: isDark
                              ? AppColors.darkPrimaryText
                              : AppColors.lightPrimaryText,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.lightAccent,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Neumorphic selectable chip for growth areas (replaces FilterChip).
class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;

    return Neumorphic(
      inset: selected,
      depth: selected ? 2 : 4,
      borderRadius: AppRadius.pill,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      borderColor: selected ? accent.withValues(alpha: 0.45) : null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 15, color: accent),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? accent
                    : (isDark
                          ? AppColors.darkPrimaryText
                          : AppColors.lightPrimaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
