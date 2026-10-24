import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/neumorphic.dart';
import 'goals_screen.dart';
import 'progress_screen.dart';
import 'weekly_review_screen.dart';

/// Flagship Profile & Settings Screen.
/// Provides a refined personal identity, personalization overview,
/// growth activity links, working theme selector, and account controls.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onLoggedOut});
  final VoidCallback? onLoggedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = ProfileService();
  UserProfile? _profile;
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
      final p = await _service.getProfile();
      if (mounted) {
        setState(() {
          _profile = p;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load profile';
          _loading = false;
        });
      }
    }
  }

  Future<void> _editProfile() async {
    if (_profile == null) return;
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(builder: (_) => _EditProfileScreen(profile: _profile!)),
    );
    if (updated != null && mounted) {
      setState(() => _profile = updated);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out of Grivio?'),
        content: const Text(
          'You will need to sign in again to access your goals, tasks, and progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().logout();
      widget.onLoggedOut?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Could not load profile'),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final p = _profile!;
    final initials = p.name.trim().isNotEmpty
        ? p.name
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
              .take(2)
              .join()
        : 'G';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit Profile',
            onPressed: _editProfile,
          ),
        ],
      ),
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
            // ── 1. Profile Header ───────────────────────────────────────────
            Center(
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            (isDark
                                    ? AppColors.darkAccent
                                    : AppColors.lightAccent)
                                .withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: isDark
                          ? AppColors.darkAccentSurface
                          : AppColors.lightAccentSurface,
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkAccent
                              : AppColors.lightAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                p.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (p.mainGoal != null && p.mainGoal!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    p.mainGoal!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ── 2. Personalization Section ──────────────────────────────────
            const SectionLabel('Personalization'),
            Neumorphic(
              padding: const EdgeInsets.all(16),
              borderRadius: AppRadius.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.track_changes_outlined,
                        size: 18,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.lightAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Growth areas',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (p.growthAreas.isEmpty)
                    Text(
                      'No growth areas selected yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkMutedText
                            : AppColors.lightMutedText,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: p.growthAreas.map((area) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSecondarySurface
                                : AppColors.lightSecondarySurface,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Text(
                            area,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkPrimaryText
                                  : AppColors.lightPrimaryText,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 14),
                  Divider(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    height: 1,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 18,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.lightAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Daily available time',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        p.dailyAvailableTime ?? 'Not set',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkAccent
                              : AppColors.lightAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 3. Growth & Activity Shortcuts ─────────────────────────────
            const SectionLabel('Growth & Activity'),
            Neumorphic(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: AppRadius.lg,
              child: Column(
                children: [
                  _ActivityTile(
                    icon: Icons.flag_outlined,
                    title: 'Goals & Milestones',
                    subtitle: 'Manage and review your active goals',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GoalsScreen()),
                    ),
                  ),
                  Divider(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    height: 1,
                  ),
                  _ActivityTile(
                    icon: Icons.insights_outlined,
                    title: 'Progress & Trends',
                    subtitle: 'View your tasks and focus time analytics',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProgressScreen()),
                    ),
                  ),
                  Divider(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    height: 1,
                  ),
                  _ActivityTile(
                    icon: Icons.auto_stories_outlined,
                    title: 'Weekly Reviews',
                    subtitle: 'Weekly reflections and growth summaries',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WeeklyReviewScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 4. Appearance & Preferences ─────────────────────────────────
            const SectionLabel('Appearance'),
            Neumorphic(
              padding: const EdgeInsets.all(16),
              borderRadius: AppRadius.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 18,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.lightAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'App theme',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const ThemeSelector(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 5. Account Section ──────────────────────────────────────────
            const SectionLabel('Account'),
            Neumorphic(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: AppRadius.lg,
              child: Column(
                children: [
                  _ActivityTile(
                    icon: Icons.person_outline,
                    title: 'Edit profile',
                    subtitle: 'Update your name, goal, and preferences',
                    onTap: _editProfile,
                  ),
                  Divider(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    height: 1,
                  ),
                  _ActivityTile(
                    icon: Icons.logout_rounded,
                    title: 'Log out',
                    subtitle: 'Sign out from this device',
                    isDestructive: true,
                    onTap: _confirmLogout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // App version branding
            Center(
              child: Text(
                'Grivio v1.0.0 · Personal Growth & Productivity',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkMutedText
                      : AppColors.lightMutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final iconColor = isDestructive
        ? (isDark ? AppColors.darkError : AppColors.lightError)
        : (isDark ? AppColors.darkAccent : AppColors.lightAccent);

    final titleColor = isDestructive
        ? (isDark ? AppColors.darkError : AppColors.lightError)
        : (isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
    );
  }
}

/// Edit profile modal sheet.
class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen({required this.profile});
  final UserProfile profile;

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.name,
  );
  late final TextEditingController _goal = TextEditingController(
    text: widget.profile.mainGoal ?? '',
  );
  late String? _time = widget.profile.dailyAvailableTime;
  late final Set<String> _areas = widget.profile.growthAreas.toSet();
  bool _saving = false;
  String? _error;

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

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ProfileService().updateProfile({
        'name': _name.text.trim(),
        'growthAreas': _areas.toList(),
        'mainGoal': _goal.text.trim(),
        if (_time != null) 'dailyAvailableTime': _time,
      });
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Growth areas',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allAreas.map((a) {
              final selected = _areas.contains(a);
              return FilterChip(
                label: Text(a),
                selected: selected,
                onSelected: (v) =>
                    setState(() => v ? _areas.add(a) : _areas.remove(a)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _goal,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Main goal',
              prefixIcon: Icon(Icons.flag_outlined, size: 20),
              hintText: 'e.g. Master Flutter and build a startup',
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _allTimes.contains(_time) ? _time : null,
            decoration: const InputDecoration(
              labelText: 'Daily available time',
              prefixIcon: Icon(Icons.schedule_outlined, size: 20),
            ),
            items: _allTimes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _time = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving changes...' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
