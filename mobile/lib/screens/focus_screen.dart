import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_storage.dart';
import '../services/focus_service.dart';
import '../services/task_service.dart';

/// Focus screen — calm, distraction-free timer with neumorphic depth.
/// Timer accuracy comes from server timestamps; the UI ticks once a
/// second but computes elapsed time from timestamps so background/resume stays accurate.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, this.preselectedTaskId});
  final String? preselectedTaskId;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  final _service = FocusService();
  final _taskService = TaskService();

  List<GrivioTask> _tasks = [];
  String? _selectedTaskId;
  int _durationMinutes = 25;
  FocusSession? _session;
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedTaskId = widget.preselectedTaskId;
    _loadTasks();
    _recoverActiveSession();
  }

  Future<void> _recoverActiveSession() async {
    final id = await AuthStorage().getActiveSessionId();
    if (id == null) return;
    try {
      final session = await _service.get(id);
      if (session.status == 'active') {
        final duration = await AuthStorage().getActiveSessionDuration();
        if (mounted) {
          setState(() {
            _session = session;
            if (duration != null && duration > 0) {
              _durationMinutes = duration ~/ 60;
            }
            _now = DateTime.now();
          });
          _ticker?.cancel();
          _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
            setState(() => _now = DateTime.now());
            _maybeAutoComplete();
          });
        }
        return;
      }
      await AuthStorage().clearActiveSession();
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        await AuthStorage().clearActiveSession();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _now = DateTime.now());
      _maybeAutoComplete();
    }
  }

  Future<void> _loadTasks() async {
    try {
      final all = await _taskService.listTasks(status: 'pending');
      if (mounted) setState(() => _tasks = all);
    } catch (_) {}
  }

  void _maybeAutoComplete() {
    final s = _session;
    if (s == null || s.status != 'active' || s.pausedAt != null) return;
    final remaining = _durationMinutes * 60 - s.focusedSeconds(_now);
    if (remaining <= 0) _finish();
  }

  Future<void> _start() async {
    if (_session != null || _starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final session = await _service.start(taskId: _selectedTaskId);
      setState(() => _session = session);
      await AuthStorage().saveActiveSession(session.id, _durationMinutes * 60);
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _now = DateTime.now());
        _maybeAutoComplete();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error = 'Could not start session. Check your connection.',
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _pause() async {
    if (_session == null) return;
    try {
      final s = await _service.pause(_session!.id);
      if (mounted) setState(() => _session = s);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _resume() async {
    if (_session == null) return;
    try {
      final s = await _service.resume(_session!.id);
      if (mounted) setState(() => _session = s);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _finish() async {
    if (_session == null) return;
    final session = _session!;
    _ticker?.cancel();
    try {
      final done = await _service.complete(session.id);
      await AuthStorage().clearActiveSession();
      if (!mounted) return;
      final completedDuration =
          done.durationSeconds ?? session.focusedSeconds(DateTime.now());
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FocusCompletedScreen(
            durationSeconds: completedDuration,
            taskTitle: session.taskId == null
                ? null
                : _tasks
                      .where((t) => t.id == session.taskId)
                      .map((t) => t.title)
                      .firstOrNull,
            sessionId: session.id,
          ),
        ),
      );
      setState(() => _session = null);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not complete session. Try again.');
    }
  }

  Future<void> _stop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End focus session?'),
        content: const Text('Your current focus progress will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continue Session'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    if (confirmed != true || _session == null) return;
    _ticker?.cancel();
    try {
      await _service.cancel(_session!.id);
      await AuthStorage().clearActiveSession();
      if (mounted) setState(() => _session = null);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final running = _session != null;
    final paused = _session?.pausedAt != null;
    final elapsed = _session == null ? 0 : _session!.focusedSeconds(_now);
    final total = _durationMinutes * 60;
    final remaining = (total - elapsed).clamp(0, total);
    final progress = _session == null ? 0.0 : (elapsed / total).clamp(0.0, 1.0);

    String fmt(int s) =>
        '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                // ── Tactile Circular Timer Focal Point ───────────────────────
                Center(
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.6)
                              : AppColors.lightShadowDark.withValues(
                                  alpha: 0.5,
                                ),
                          offset: const Offset(4, 4),
                          blurRadius: 12,
                        ),
                        BoxShadow(
                          color: isDark
                              ? AppColors.darkShadowLight.withValues(alpha: 0.2)
                              : AppColors.lightShadowLight.withValues(
                                  alpha: 0.9,
                                ),
                          offset: const Offset(-4, -4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: _session == null ? 0.0 : progress,
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                            backgroundColor: isDark
                                ? AppColors.darkProgressTrack
                                : AppColors.lightSecondarySurface,
                            color: isDark
                                ? AppColors.darkAccent
                                : AppColors.lightAccent,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fmt(remaining),
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (paused
                                            ? (isDark
                                                  ? AppColors.darkWarning
                                                  : AppColors.lightWarning)
                                            : (isDark
                                                  ? AppColors.darkAccent
                                                  : AppColors.lightAccent))
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                paused
                                    ? 'PAUSED'
                                    : (running ? 'FOCUSING' : 'READY'),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: paused
                                      ? (isDark
                                            ? AppColors.darkWarning
                                            : AppColors.lightWarning)
                                      : (isDark
                                            ? AppColors.darkAccent
                                            : AppColors.lightAccent),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Controls & Options ───────────────────────────────────────
                if (!running) ...[
                  // Duration selector chips
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [15, 25, 45, 60].map((m) {
                      final selected = _durationMinutes == m;
                      return ChoiceChip(
                        label: Text('$m min'),
                        selected: selected,
                        onSelected: (_) => setState(() => _durationMinutes = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Optional task dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedTaskId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Task (optional)',
                      prefixIcon: Icon(Icons.check_circle_outline, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No task (free focus)'),
                      ),
                      ..._tasks.map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.title, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedTaskId = v),
                  ),
                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed: _starting ? null : _start,
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(_starting ? 'Starting...' : 'Start Focus'),
                  ),
                ] else ...[
                  if (_session!.taskId != null) ...[
                    Text(
                      _tasks
                              .where((t) => t.id == _session!.taskId)
                              .map((t) => t.title)
                              .firstOrNull ??
                          'Task',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: paused
                            ? FilledButton.icon(
                                onPressed: _resume,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Resume'),
                              )
                            : OutlinedButton.icon(
                                onPressed: _pause,
                                icon: const Icon(Icons.pause_rounded),
                                label: const Text('Pause'),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _finish,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Finish'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _stop,
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.darkError
                          : AppColors.lightError,
                    ),
                    child: const Text('Cancel session'),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkError
                          : AppColors.lightError,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal focus completed screen with rating and reflection.
class FocusCompletedScreen extends StatefulWidget {
  const FocusCompletedScreen({
    super.key,
    required this.durationSeconds,
    this.taskTitle,
    required this.sessionId,
  });

  final int durationSeconds;
  final String? taskTitle;
  final String sessionId;

  @override
  State<FocusCompletedScreen> createState() => _FocusCompletedScreenState();
}

class _FocusCompletedScreenState extends State<FocusCompletedScreen> {
  String? _rating;
  final _reflection = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    setState(() => _saving = true);
    try {
      final token = await AuthStorage().getToken();
      await ApiClient().patch(
        '/focus/sessions/${widget.sessionId}',
        body: {
          if (_rating != null) 'productivity_rating': _rating!.toLowerCase(),
          if (_reflection.text.trim().isNotEmpty)
            'reflection': _reflection.text.trim(),
        },
        token: token,
      );
    } catch (_) {}
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final minutes = (widget.durationSeconds / 60).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Focus Complete')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
                          .withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 56,
                  color: isDark
                      ? AppColors.darkSuccess
                      : AppColors.lightSuccess,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '$minutes min focus logged',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.25,
                ),
              ),
            ),
            if (widget.taskTitle != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  widget.taskTitle!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Text(
              'How was your session?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ['Low', 'Okay', 'Good', 'Excellent'].map((r) {
                final selected = _rating == r;
                return ChoiceChip(
                  label: Text(r),
                  selected: selected,
                  onSelected: (_) => setState(() => _rating = r),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _reflection,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Session reflection (optional)',
                hintText: 'What did you accomplish or learn?',
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _done,
              child: Text(_saving ? 'Saving...' : 'Done'),
            ),
          ],
        ),
      ),
    );
  }
}
