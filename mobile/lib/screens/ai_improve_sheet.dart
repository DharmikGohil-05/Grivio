import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/api_client.dart';
import '../services/task_service.dart';
import '../widgets/neumorphic.dart';
import '../widgets/ui_kit.dart';

/// Feature A (Phase 13) — AI Task Improvement bottom sheet.
///
/// Compares the original task with AI-proposed values. Each suggested field
/// can be edited and individually accepted; only explicitly confirmed fields
/// are sent to the existing task update API. Canceling leaves the DB
/// unchanged. Regenerating asks for confirmation when edits were made.
class AIImproveSheet extends StatefulWidget {
  const AIImproveSheet({
    super.key,
    this.taskId,
    required this.title,
    this.description,

    /// Unsaved (Add Task) mode: suggestions are copied back, never applied.
    this.unsavedMode = false,
    this.onApplySuggestion,
  });

  final String? taskId;
  final String title;
  final String? description;
  final bool unsavedMode;

  /// In unsaved mode, called with an edited suggestion so the caller can
  /// copy values into the Add Task form (no API call, no DB change).
  final void Function(TaskImprovement edited)? onApplySuggestion;

  @override
  State<AIImproveSheet> createState() => _AIImproveSheetState();
}

class _AIImproveSheetState extends State<AIImproveSheet> {
  final _ai = AIService();
  final _tasks = TaskService();
  final _instructions = TextEditingController();

  TaskImprovement? _proposal;
  // Per-field editable values (null = field not suggested / not selected).
  bool _loading = false;
  bool _applying = false;
  bool _dirty = false;
  String? _error;

  // Editable copies of suggested fields + their selection state.
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  String? _category;
  String? _priority;
  // Per-field opt-in flags: a field is applied only when its box is
  // checked, so the AI proposal can never overwrite anything implicitly.
  bool _selTitle = false,
      _selDesc = false,
      _selCat = false,
      _selPri = false,
      _selMin = false;
  List<_SubRow> _subs = [];

  // Original values kept for side-by-side comparison.
  @override
  void dispose() {
    _instructions.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  /// Count of checked scalar fields only — the suggested subtasks are
  /// never applied, so they are not counted here.
  int get _selectedFieldCount =>
      (_selTitle ? 1 : 0) +
      (_selDesc ? 1 : 0) +
      (_selCat ? 1 : 0) +
      (_selPri ? 1 : 0) +
      (_selMin ? 1 : 0);

  Future<void> _generate({bool isRegenerate = false}) async {
    if (_loading) return;
    if (isRegenerate && _dirty && _proposal != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Regenerate proposal?'),
          content: const Text(
            'Your edits to the current proposal will be replaced.',
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
      final p = await _ai.improveTask(
        taskId: widget.taskId,
        title: widget.unsavedMode ? widget.title : null,
        description: widget.unsavedMode ? widget.description : null,
        instructions: _instructions.text.trim().isEmpty
            ? null
            : _instructions.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _proposal = p;
        _dirty = false;
        // Load editable copies; fields start unselected so the user decides.
        _titleCtrl.text = p.title ?? '';
        _descCtrl.text = p.description ?? '';
        _minCtrl.text = p.estimatedMinutes?.toString() ?? '';
        _category = p.category;
        _priority = p.priority;
        _selTitle = _selDesc = _selCat = _selPri = _selMin = false;
        _subs = p.subtasks.map((t) => _SubRow(t)).toList();
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

  /// Applies only the confirmed fields via the existing task update API.
  Future<void> _applySelected() async {
    if (_applying || _selectedFieldCount == 0) return;
    if (widget.unsavedMode) {
      // Preview-only for unsaved tasks: hand values back to the form.
      widget.onApplySuggestion?.call(_editedProposal());
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _applying = true;
      _error = null;
    });
    // Partial payload: only checked, valid fields are included, so the
    // request carries exactly what the user confirmed and nothing else.
    final fields = <String, dynamic>{};
    if (_selTitle && _titleCtrl.text.trim().isNotEmpty) {
      fields['title'] = _titleCtrl.text.trim();
    }
    if (_selDesc) {
      fields['description'] = _descCtrl.text.trim();
    }
    if (_selCat && _category != null) {
      fields['category'] = _category;
    }
    if (_selPri && _priority != null) {
      fields['priority'] = _priority;
    }
    if (_selMin && int.tryParse(_minCtrl.text.trim()) != null) {
      fields['estimatedMinutes'] = int.parse(_minCtrl.text.trim());
    }

    try {
      await _tasks.updateTask(widget.taskId!, fields);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _applying = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not reach the server.';
          _applying = false;
        });
      }
    }
  }

  /// Snapshots the current edits into a TaskImprovement — used in
  /// unsaved mode to hand values back to the Add Task form (no API call).
  TaskImprovement _editedProposal() => TaskImprovement(
    title: _titleCtrl.text.trim(),
    description: _descCtrl.text,
    category: _category,
    priority: _priority,
    estimatedMinutes: int.tryParse(_minCtrl.text.trim()),
    subtasks: _subs
        .map((s) => s.ctrl.text.trim())
        .where((t) => t.isNotEmpty)
        .toList(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final originalTitle = widget.title;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (context, scrollController) => Column(
          children: [
            // Grab handle
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
                    icon: Icons.auto_fix_high_rounded,
                    size: 44,
                    iconSize: 20,
                    isAccent: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Improve task',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _loading || _applying
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Original task for comparison, set into an engraved well
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
                      'ORIGINAL',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      originalTitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.description != null &&
                        widget.description!.isNotEmpty)
                      Text(
                        widget.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
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
                      hintText: 'e.g. Make this practical for a beginner',
                      prefixIcon: Icon(Icons.tune_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  NeumorphicButton(
                    isAccent: true,
                    width: double.infinity,
                    onPressed: _loading || _applying
                        ? null
                        : () => _generate(isRegenerate: _proposal != null),
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
                              const Icon(Icons.auto_fix_high_rounded, size: 17),
                              const SizedBox(width: 8),
                              Text(
                                _proposal == null
                                    ? 'Generate improvement'
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

                  if (_proposal == null && !_loading && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          NeumorphicIconCircle(
                            icon: Icons.auto_fix_high_outlined,
                            size: 56,
                            iconSize: 26,
                            inset: true,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Tap Generate improvement to rewrite this task into something more actionable.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_proposal != null) ...[
                    Text(
                      'Proposed changes — select which to apply',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_proposal!.title != null)
                      _fieldRow(
                        label: 'Title',
                        original: originalTitle,
                        control: TextField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: 'Improved title',
                          ),
                          onChanged: (_) => setState(() => _dirty = true),
                        ),
                        selected: _selTitle,
                        onChanged: (v) => setState(() {
                          _selTitle = v;
                          _dirty = true;
                        }),
                      ),
                    if (_proposal!.description != null)
                      _fieldRow(
                        label: 'Description',
                        original: widget.description ?? '(none)',
                        control: TextField(
                          controller: _descCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: 'Description',
                          ),
                          onChanged: (_) => setState(() => _dirty = true),
                        ),
                        selected: _selDesc,
                        onChanged: (v) => setState(() {
                          _selDesc = v;
                          _dirty = true;
                        }),
                      ),
                    if (_proposal!.category != null)
                      _fieldRow(
                        label: 'Category',
                        original: '—',
                        control: DropdownButtonFormField<String>(
                          value: _category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          // The app's fixed category list; the AI proposal
                          // only seeds the initial selection value.
                          items:
                              const [
                                    'Career',
                                    'Learning',
                                    'Fitness',
                                    'Personal',
                                    'Finance',
                                    'Communication',
                                    'Other',
                                  ]
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() {
                            _category = v;
                            _dirty = true;
                          }),
                        ),
                        selected: _selCat,
                        onChanged: (v) => setState(() {
                          _selCat = v;
                          _dirty = true;
                        }),
                      ),
                    if (_proposal!.priority != null)
                      _fieldRow(
                        label: 'Priority',
                        original: '—',
                        control: DropdownButtonFormField<String>(
                          value: _priority,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: ['low', 'medium', 'high']
                              .map(
                                (p) =>
                                    DropdownMenuItem(value: p, child: Text(p)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _priority = v;
                            _dirty = true;
                          }),
                        ),
                        selected: _selPri,
                        onChanged: (v) => setState(() {
                          _selPri = v;
                          _dirty = true;
                        }),
                      ),
                    if (_proposal!.estimatedMinutes != null)
                      _fieldRow(
                        label: 'Estimated minutes',
                        original: '—',
                        control: TextField(
                          controller: _minCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: 'minutes',
                          ),
                          onChanged: (_) => setState(() => _dirty = true),
                        ),
                        selected: _selMin,
                        onChanged: (v) => setState(() {
                          _selMin = v;
                          _dirty = true;
                        }),
                      ),

                    if (_subs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Suggested subtasks (optional)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Open AI Assist after applying to add subtasks — improvement only updates the task fields.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Display-only suggestions: applying this proposal
                      // updates task fields only — real subtasks are added
                      // afterwards via AI Assist or the subtask list.
                      ..._subs.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.subdirectory_arrow_right,
                                size: 16,
                                color: secondary.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: s.ctrl,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _dirty = true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Text(
                    widget.unsavedMode
                        ? 'Preview only'
                        : '$_selectedFieldCount selected',
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _loading || _applying
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  // Flexible keeps the action button within the leftover
                  // row width so its label can't push the footer out.
                  Flexible(
                    child: NeumorphicButton(
                      isAccent: true,
                      onPressed:
                          (_proposal == null ||
                              _loading ||
                              _applying ||
                              (!widget.unsavedMode &&
                                  _selectedFieldCount == 0))
                              ? null
                              : _applySelected,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Text(
                        _applying
                            ? 'Applying...'
                            : (widget.unsavedMode
                                  ? 'Copy selected values'
                                  : 'Apply selected changes'),
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

  /// One proposed field row: selection checkbox, original vs editable value.
  Widget _fieldRow({
    required String label,
    required String original,
    required Widget control,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Neumorphic(
        depth: 3,
        borderRadius: 14,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: selected, onChanged: (v) => onChanged(v ?? false)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Original: $original',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  control,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Editable suggested-subtask row (title only).
class _SubRow {
  _SubRow(String initial) : ctrl = TextEditingController(text: initial);
  final TextEditingController ctrl;
}
