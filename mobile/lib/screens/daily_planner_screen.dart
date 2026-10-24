import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/api_client.dart';
import '../services/task_service.dart';
import '../widgets/neumorphic.dart';

/// In-memory session store for an accepted daily plan.
class SessionPlanStore {
  // Client memory only: there is no schedule table on the backend, and
  // `static` means it survives navigation but dies with the app run.
  static DailyPlan? accepted;
  static int get acceptedCount => accepted?.scheduled.length ?? 0;
}

/// AI Daily Planner screen with scheduling parameters, free-text context,
/// reorderable schedule list, slot adjustments, and plan acceptance.
class DailyPlannerScreen extends StatefulWidget {
  const DailyPlannerScreen({super.key});

  @override
  State<DailyPlannerScreen> createState() => _DailyPlannerScreenState();
}

class _DailyPlannerScreenState extends State<DailyPlannerScreen> {
  final _ai = AIService();
  final _contextCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  final _availableCtrl = TextEditingController(text: '180');
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  final _breakCtrl = TextEditingController(text: '10');

  DailyPlan? _plan;
  bool _loading = false;
  bool _accepting = false;
  bool _dirty = false;
  int _eligibleCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contextCtrl.addListener(() => setState(() {}));
    _countEligibleTasks();
  }

  @override
  void dispose() {
    _contextCtrl.dispose();
    _availableCtrl.dispose();
    _breakCtrl.dispose();
    super.dispose();
  }

  /// Counts incomplete tasks for the "available to schedule" hint.
  /// Informational only, so failures are silently ignored.
  Future<void> _countEligibleTasks() async {
    try {
      final tasks = await TaskService().listTasks();
      final eligible = tasks
          .where((t) => t.status != 'completed' && t.status != 'cancelled')
          .length;
      if (mounted) setState(() => _eligibleCount = eligible);
    } catch (_) {}
  }

  String get _dateString =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  int get _selectedCount => _plan?.scheduled.length ?? 0;

  Future<void> _generate({bool isRegenerate = false}) async {
    if (_loading || _accepting) return;
    if (isRegenerate && _dirty && _plan != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Regenerate plan?'),
          content: const Text(
            'Your edits to the current draft schedule will be replaced.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep edits'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Regenerate'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    final available = int.tryParse(_availableCtrl.text.trim());
    if (available == null || available < 5 || available > 1440) {
      setState(
        () => _error = 'Available time must be between 5 and 1440 minutes.',
      );
      return;
    }
    final brk = int.tryParse(_breakCtrl.text.trim()) ?? 10;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await _ai.generateDailyPlan(
        date: _dateString,
        availableMinutes: available,
        startTime:
            '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}',
        endTime:
            '${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}',
        breakMinutes: brk,
        dailyContext: _contextCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _dirty = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.statusCode == 401
              ? 'Your session expired. Please sign in again.'
              : e.message,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not reach the server. Check your connection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Recomputes slot start times from [index] onward after an edit:
  /// each slot follows the previous one plus the current break length,
  /// and a slot that would run past the window is pulled back inside it.
  void _reflowFrom(int index) {
    final plan = _plan;
    if (plan == null) return;
    final brk = int.tryParse(_breakCtrl.text.trim()) ?? 0;
    final windowStart = _start.hour * 60 + _start.minute;
    final windowEnd = _end.hour * 60 + _end.minute;

    var cursor = index == 0
        ? windowStart
        : plan.scheduled[index - 1].startMinutes +
              plan.scheduled[index - 1].minutes +
              brk;
    for (var i = index; i < plan.scheduled.length; i++) {
      final slot = plan.scheduled[i];
      if (cursor + slot.minutes > windowEnd) {
        cursor = windowEnd - slot.minutes;
        if (cursor < windowStart) cursor = windowStart;
      }
      slot.start =
          '${(cursor ~/ 60).toString().padLeft(2, '0')}:${(cursor % 60).toString().padLeft(2, '0')}';
      cursor = slot.startMinutes + slot.minutes + brk;
    }
    setState(() => _dirty = true);
  }

  Future<void> _editDuration(int index) async {
    final plan = _plan;
    if (plan == null) return;
    final ctrl = TextEditingController(
      text: plan.scheduled[index].minutes.toString(),
    );
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duration (minutes)'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: '5–480'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Accept 5–480 minutes only; anything else leaves the slot as-is.
    if (v != null && v >= 5 && v <= 480) {
      plan.scheduled[index].minutes = v;
      _reflowFrom(index);
    }
  }

  Future<void> _editStart(int index) async {
    final plan = _plan;
    if (plan == null) return;
    final slot = plan.scheduled[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: slot.startMinutes ~/ 60,
        minute: slot.startMinutes % 60,
      ),
    );
    if (picked == null) return;
    slot.start =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _reflowFrom(index + 1);
  }

  void _removeSlot(int index) {
    _plan?.scheduled.removeAt(index);
    _reflowFrom(index);
  }

  /// Total minutes already spoken for: slot minutes plus break minutes,
  /// compared against the plan's capacity in [_remainingTotal].
  int get _plannedTotal {
    final plan = _plan;
    if (plan == null) return 0;
    return plan.scheduled.fold(0, (n, s) => n + s.minutes) +
        plan.breaks.fold(0, (n, b) => n + b.minutes);
  }

  int get _remainingTotal {
    final plan = _plan;
    if (plan == null) return 0;
    return plan.capacityMinutes - _plannedTotal;
  }

  /// Accepting stores the plan in [SessionPlanStore] (client memory
  /// only) and closes the screen — no endpoint is called, so nothing is
  /// written to the backend and no task is rescheduled.
  Future<void> _acceptPlan() async {
    if (_accepting || _plan == null) return;
    setState(() => _accepting = true);
    SessionPlanStore.accepted = _plan;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Plan accepted for this session — $_selectedCount task(s) scheduled.',
        ),
      ),
    );
    setState(() => _accepting = false);
    Navigator.of(context).pop(true);
  }

  /// Throws away the draft and any previously accepted plan — both live
  /// only in memory, so there is nothing on the server to clean up.
  void _discardPlan() {
    setState(() {
      _plan = null;
      _dirty = false;
      SessionPlanStore.accepted = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Planner'),
        actions: [
          if (plan != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              tooltip: 'Discard plan',
              onPressed: _loading || _accepting ? null : _discardPlan,
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          12,
          AppSpacing.pagePadding,
          24 + insets,
        ),
        children: [
          // ── Planning Parameters ─────────────────────────────────────────
          const SectionLabel('Schedule Parameters'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text('${_date.month}/${_date.day}/${_date.year}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _pickTime(true),
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(_start.format(context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _pickTime(false),
                  icon: const Icon(Icons.access_time_filled, size: 16),
                  label: Text(_end.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _availableCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Available (minutes)',
                    prefixIcon: Icon(Icons.timer_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _breakCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Break (minutes)',
                    prefixIcon: Icon(Icons.coffee_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
          if (_eligibleCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '$_eligibleCount incomplete task${_eligibleCount == 1 ? '' : 's'} available to schedule',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: isDark
                    ? AppColors.darkMutedText
                    : AppColors.lightSecondaryText,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // ── Context Input ───────────────────────────────────────────────
          const SectionLabel('Context & Priorities'),
          // Free-text context is the user's own guidance for this one
          // generation: it is sent as `dailyContext` and is never stored
          // as task data or able to create/modify anything by itself.
          TextField(
            controller: _contextCtrl,
            maxLines: 4,
            maxLength: 1000,
            decoration: InputDecoration(
              counterText: '${_contextCtrl.text.length}/1000',
              hintText:
                  'e.g. Focus on coding in the morning, review meeting at 2 PM, keep breaks short.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),

          FilledButton.icon(
            onPressed: _loading || _accepting
                ? null
                : () => _generate(isRegenerate: plan != null),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              _loading
                  ? 'Generating schedule...'
                  : (plan == null ? 'Generate Plan' : 'Regenerate Plan'),
            ),
          ),
          const SizedBox(height: 20),

          if (plan != null) ..._buildPlan(theme, plan, isDark),
        ],
      ),
    );
  }

  List<Widget> _buildPlan(ThemeData theme, DailyPlan plan, bool isDark) {
    return [
      // Summary Totals
      Neumorphic(
        padding: const EdgeInsets.all(12),
        borderRadius: AppRadius.md,
        child: Row(
          children: [
            _totalItem('Planned', '$_plannedTotal min', isDark),
            _totalItem(
              'Remaining',
              '${_remainingTotal < 0 ? 0 : _remainingTotal} min',
              isDark,
            ),
            _totalItem('Scheduled', '${plan.scheduled.length}', isDark),
            _totalItem('Unscheduled', '${plan.unscheduled.length}', isDark),
          ],
        ),
      ),
      const SizedBox(height: 16),

      const SectionLabel('Timeline Schedule'),
      if (plan.scheduled.isEmpty)
        Text(
          'No tasks could be scheduled with this availability window.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: isDark
                ? AppColors.darkMutedText
                : AppColors.lightSecondaryText,
          ),
        ),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: plan.scheduled.length,
        onReorder: (oldIndex, newIndex) {
          // The reported index assumes the item is still in the list, so
          // a downward move lands one past its real slot; reflow then
          // re-times everything from the move onward.
          if (newIndex > oldIndex) newIndex -= 1;
          final item = plan.scheduled.removeAt(oldIndex);
          plan.scheduled.insert(newIndex, item);
          _reflowFrom(newIndex > 0 ? newIndex - 1 : 0);
        },
        itemBuilder: (context, i) {
          final slot = plan.scheduled[i];
          return Container(
            key: ValueKey('slot_${slot.taskId}_$i'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: _loading ? null : () => _editStart(i),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Column(
                      children: [
                        Text(
                          slot.start,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          slot.end,
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
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 32,
                  decoration: BoxDecoration(
                    color: slot.priority == 'high'
                        ? (isDark ? AppColors.darkError : AppColors.lightError)
                        : (isDark
                              ? AppColors.darkAccent
                              : AppColors.lightAccent),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${slot.minutes} min · ${slot.priority}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkMutedText
                              : AppColors.lightSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: Icon(
                    Icons.drag_handle,
                    size: 18,
                    color: isDark
                        ? AppColors.darkMutedText
                        : AppColors.lightMutedText,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (v) {
                    if (v == 'duration') _editDuration(i);
                    if (v == 'remove') _removeSlot(i);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'duration',
                      child: Text('Edit duration'),
                    ),
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 20),

      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _loading || _accepting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: plan.scheduled.isEmpty || _loading || _accepting
                  ? null
                  : _acceptPlan,
              icon: _accepting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_accepting ? 'Accepting...' : 'Accept plan'),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _totalItem(String label, String value, bool isDark) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: isDark
                ? AppColors.darkMutedText
                : AppColors.lightSecondaryText,
          ),
        ),
      ],
    ),
  );

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        // Keep the window valid: if the new start would meet or pass the
        // end, push the end forward (same minute, one hour later).
        if (_end.hour * 60 + _end.minute <= _start.hour * 60 + _start.minute) {
          _end = TimeOfDay(
            hour: (_start.hour + 1).clamp(0, 23),
            minute: _start.minute,
          );
        }
      } else {
        _end = picked;
      }
    });
  }
}
