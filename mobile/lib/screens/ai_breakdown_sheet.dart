import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/api_client.dart';
import '../services/goal_service.dart';
import '../services/task_service.dart';
import '../widgets/neumorphic.dart';
import '../widgets/ui_kit.dart';

/// Feature B (Phase 13) — AI Goal/Task Breakdown bottom sheet.
///
/// Displays a proposed phase → task hierarchy using GRIVIO's existing
/// goal → milestone → task structure. Phases are saved as milestones and
/// tasks as tasks linked to the milestone. Everything is editable and
/// selectable before the user confirms "Create selected items"; partial
/// failures are reported honestly with per-item status, and failed items
/// stay selected for a safe retry (already-created items are marked done,
/// so retrying never duplicates them).
class AIBreakdownSheet extends StatefulWidget {
  const AIBreakdownSheet({
    super.key,
    this.goalId,
    this.saveGoalId,
    required this.title,
    this.description,

    /// Unsaved goal/task: preview-only, nothing is created.
    this.previewOnly = false,
    this.onSaved,
  });

  /// Existing goal — used as generation context AND save target.
  final String? goalId;

  /// Goal that proposed milestones/tasks will be created under. Set this
  /// when generating from a task context (goalId == null, title = task).
  /// When neither goalId nor saveGoalId exists, the sheet is preview-only.
  final String? saveGoalId;

  final String title;
  final String? description;
  final bool previewOnly;
  final VoidCallback? onSaved;

  @override
  State<AIBreakdownSheet> createState() => _AIBreakdownSheetState();
}

class _PhaseItem {
  _PhaseItem(this.title, this.description, this.tasks);
  String title;
  String? description;
  bool selected = true;
  bool created = false; // already persisted (retry safety — never re-create)
  final List<_TaskItem> tasks;
}

/// One proposed task inside a phase; same select/edit/retry rules as
/// [_PhaseItem].
class _TaskItem {
  _TaskItem(this.title, this.description, this.minutes);
  String title;
  String? description;
  int? minutes;
  bool selected = true;
  bool created = false;
}

class _AIBreakdownSheetState extends State<AIBreakdownSheet> {
  final _ai = AIService();
  final _goals = GoalService();
  final _tasks = TaskService();
  final _instructions = TextEditingController();

  List<_PhaseItem> _phases = [];
  bool _loading = false;
  bool _creating = false;
  bool _dirty = false;
  String? _error;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  // Count only not-yet-created selections: items already persisted show
  // as done and must never be included in a retry.
  int get _selectedPhases =>
      _phases.where((p) => p.selected && !p.created).length;
  int get _selectedTasks => _phases.fold(
    0,
    (n, p) => n + p.tasks.where((t) => t.selected && !t.created).length,
  );

  Future<void> _generate({bool isRegenerate = false}) async {
    if (_loading) return;
    // Never silently discard edits — ask first.
    if (isRegenerate && _dirty && _phases.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Regenerate breakdown?'),
          content: const Text(
            'Your edits to the current breakdown will be replaced.',
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

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final proposal = await _ai.generateBreakdown(
        // Existing goal: send its id so the backend can read its context;
        // otherwise send the draft title/description directly.
        goalId: widget.goalId,
        title: widget.goalId == null ? widget.title : null,
        description: widget.goalId == null ? widget.description : null,
        instructions: _instructions.text.trim().isEmpty
            ? null
            : _instructions.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _phases = proposal.phases
            .map(
              (p) => _PhaseItem(
                p.title,
                p.description,
                p.tasks
                    .map(
                      (t) =>
                          _TaskItem(t.title, t.description, t.estimatedMinutes),
                    )
                    .toList(),
              ),
            )
            .toList();
        _dirty = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
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

  /// Creates selected phases (milestones) and their tasks through the
  /// existing APIs. Items are marked `created` as they succeed, so a
  /// retry after a partial failure only creates what's missing.
  /// Goal under which selected phases/tasks are created (existing APIs).
  String? get _saveGoalId => widget.saveGoalId ?? widget.goalId;

  /// True when no goal exists to save into — generation stays preview-only.
  bool get _isPreview => widget.previewOnly || _saveGoalId == null;

  Future<void> _createSelected() async {
    if (_creating || _isPreview) return;
    if (_selectedPhases == 0 && _selectedTasks == 0) return;

    setState(() {
      _creating = true;
      _error = null;
    });
    int createdCount = 0;
    final failed = <String>[];

    for (final phase in _phases.where((p) => p.selected && !p.created)) {
      // Phase → milestone (existing goal milestone API).
      String? milestoneId;
      try {
        final m = await _goals.createMilestone(_saveGoalId!, {
          'title': phase.title,
          if (phase.description != null) 'description': phase.description,
        });
        milestoneId = m.id;
        phase.created = true;
        createdCount++;
      } catch (_) {
        failed.add(phase.title);
        if (mounted) setState(() {}); // keep UI honest mid-loop
        continue; // without a milestone, skip this phase's tasks
      }

      for (final task in phase.tasks.where((t) => t.selected && !t.created)) {
        try {
          // goalId + milestoneId link each new task to both the goal and
          // the phase milestone just created, so nothing lands unlinked.
          await _tasks.createTask({
            'title': task.title,
            if (task.description != null) 'description': task.description,
            if (task.minutes != null) 'estimatedMinutes': task.minutes,
            'goalId': _saveGoalId,
            'milestoneId': milestoneId,
          });
          task.created = true;
          createdCount++;
        } catch (_) {
          failed.add(task.title);
        }
        if (mounted) setState(() {});
      }
    }

    if (!mounted) return;
    setState(() => _creating = false);

    if (failed.isEmpty) {
      widget.onSaved?.call();
      if (mounted) Navigator.of(context).pop(true);
    } else {
      // Honest partial-failure report + safe retry (created items stay marked).
      setState(
        () => _error =
            'Created $createdCount item(s). Failed: ${failed.join(', ')}. Failed items remain selected — tap Create again to retry.',
      );
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header — tactile accent mark beside the title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Row(
                children: [
                  const NeumorphicIconCircle(
                    icon: Icons.account_tree_rounded,
                    size: 44,
                    iconSize: 20,
                    isAccent: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Break down',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _loading || _creating
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Context + preview notice, set into an engraved well
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Neumorphic(
                inset: true,
                depth: 3,
                borderRadius: AppRadius.md,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.description != null &&
                        widget.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                    if (_isPreview) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Preview only — nothing will be saved.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                children: [
                  TextField(
                    controller: _instructions,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Instructions (optional)',
                      hintText: 'e.g. Beginner-friendly, focus on an MVP first',
                      prefixIcon: Icon(Icons.tune_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  NeumorphicButton(
                    isAccent: true,
                    width: double.infinity,
                    onPressed: _loading || _creating
                        ? null
                        : () => _generate(isRegenerate: _phases.isNotEmpty),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _loading
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
                              Text('Generating...'),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_tree_rounded, size: 17),
                              const SizedBox(width: 8),
                              Text(
                                _phases.isEmpty
                                    ? 'Generate breakdown'
                                    : 'Regenerate',
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ErrorPill(message: _error!),
                    ),

                  if (_phases.isEmpty && !_loading && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          NeumorphicIconCircle(
                            icon: Icons.account_tree_outlined,
                            size: 56,
                            iconSize: 26,
                            inset: true,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Tap Generate breakdown to propose phases and tasks for this goal.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Phase → task hierarchy, editable + selectable.
                  ..._phases.asMap().entries.map((entry) {
                    final pi = entry.key;
                    final phase = entry.value;
                    return _phaseCard(theme, pi, phase);
                  }),
                ],
              ),
            ),

            // Footer with a clear creation summary.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.previewOnly || _saveGoalId == null
                          ? 'Preview only'
                          : '$_selectedPhases phase(s), $_selectedTasks task(s)',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _loading || _creating
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  // Flexible bounds the create button to the leftover row
                  // width so its count label can't overflow the footer.
                  Flexible(
                    child: NeumorphicButton(
                      isAccent: true,
                      onPressed:
                          _isPreview ||
                              _loading ||
                              _creating ||
                              (_selectedPhases == 0 && _selectedTasks == 0)
                              ? null
                              : _createSelected,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Text(
                        _creating
                            ? 'Creating...'
                            : 'Create selected (${_selectedPhases + _selectedTasks})',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One phase card: select, edit title/description, tasks, add-task row.
  Widget _phaseCard(ThemeData theme, int pi, _PhaseItem phase) {
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final success = isDark ? AppColors.darkSuccess : AppColors.lightSuccess;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Neumorphic(
        depth: 4,
        borderRadius: 16,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Once a phase is created its checkbox and add-task button
                // lock and delete is replaced by a check mark, so a retry
                // after a partial failure can never duplicate or alter it.
                Checkbox(
                  value: phase.selected,
                  onChanged: phase.created
                      ? null
                      : (v) => setState(() {
                          phase.selected = v ?? false;
                          _dirty = true;
                        }),
                ),
                Icon(Icons.flag_rounded, size: 16, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: phase.title),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onChanged: (v) {
                      phase.title = v.trim();
                      _dirty = true;
                    },
                  ),
                ),
                if (phase.created)
                  Icon(Icons.check_circle, size: 16, color: success)
                else
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: secondary.withValues(alpha: 0.75),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      _phases.removeAt(pi);
                      _dirty = true;
                    }),
                  ),
              ],
            ),
            if (phase.description != null)
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: TextField(
                  controller: TextEditingController(text: phase.description),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondary,
                  ),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    phase.description = v.trim();
                    _dirty = true;
                  },
                ),
              ),
            Divider(height: 16, color: theme.dividerColor),
            ...phase.tasks.asMap().entries.map((te) {
              final ti = te.key;
              final task = te.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Checkbox(
                        value: task.selected,
                        onChanged: task.created
                            ? null
                            : (v) => setState(() {
                                task.selected = v ?? false;
                                _dirty = true;
                              }),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: task.title),
                        style: theme.textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        onChanged: (v) {
                          task.title = v.trim();
                          _dirty = true;
                        },
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: TextField(
                        controller: TextEditingController(
                          text: task.minutes?.toString() ?? '',
                        ),
                        keyboardType: TextInputType.number,
                        style: theme.textTheme.bodySmall,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: UnderlineInputBorder(),
                          hintText: 'min',
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v.trim());
                          task.minutes = (n != null && n > 0) ? n : null;
                          _dirty = true;
                        },
                      ),
                    ),
                    if (task.created)
                      Icon(Icons.check_circle, size: 16, color: success)
                    else
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 16,
                          color: secondary.withValues(alpha: 0.75),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          phase.tasks.removeAt(ti);
                          _dirty = true;
                        }),
                      ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: phase.created
                    ? null
                    : () => setState(() {
                        phase.tasks.add(_TaskItem('New task', null, null));
                        _dirty = true;
                      }),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
