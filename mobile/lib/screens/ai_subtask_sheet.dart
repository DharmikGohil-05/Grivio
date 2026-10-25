import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/api_client.dart';
import '../services/task_service.dart';
import '../widgets/neumorphic.dart';
import '../widgets/ui_kit.dart';

/// AI Subtask Generator — a polished bottom sheet that turns a parent task
/// into user-reviewable AI suggestions. Nothing is saved until the user
/// explicitly taps "Add selected".
///
/// Regeneration behavior: if the user has edited/removed/reordered the
/// current list, regenerating asks for confirmation first so edits are
/// never silently discarded.
class AISubtaskSheet extends StatefulWidget {
  const AISubtaskSheet({
    super.key,
    required this.taskId,
    required this.taskTitle,
    this.taskDescription,
  });

  final String taskId;
  final String taskTitle;
  final String? taskDescription;

  @override
  State<AISubtaskSheet> createState() => _AISubtaskSheetState();
}

class _AISubtaskSheetState extends State<AISubtaskSheet> {
  final _ai = AIService();
  final _tasks = TaskService();
  final _instructions = TextEditingController();

  List<SubtaskSuggestion> _suggestions = [];
  bool _loading = false;
  bool _saving = false;
  bool _dirty = false; // user has edited the current list
  String? _error;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  int get _selectedCount => _suggestions.where((s) => s.selected).length;

  Future<void> _generate({bool isRegenerate = false}) async {
    if (_loading) return;
    // Protect unsaved edits: confirm before replacing the list.
    if (isRegenerate && _dirty && _suggestions.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Regenerate suggestions?'),
          content: const Text(
            'Your edits to the current list will be replaced.',
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
      final result = await _ai.generateSubtasks(
        taskId: widget.taskId,
        instructions: _instructions.text.trim().isEmpty
            ? null
            : _instructions.text.trim(),
      );
      if (!mounted) return;
      if (result.isEmpty) {
        setState(
          () => _error =
              'No suggestions were returned. Try different instructions.',
        );
      } else {
        setState(() {
          _suggestions = result;
          _dirty = false;
        });
      }
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

  /// Persists only the checked suggestions, one create call each, reusing
  /// the normal subtask endpoint. Closing the sheet any other way
  /// (Cancel, close icon, system back) sends nothing to the server.
  Future<void> _addSelected() async {
    final selected = _suggestions.where((s) => s.selected).toList();
    if (selected.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    int added = 0;
    final failures = <String>[];
    for (final s in selected) {
      try {
        // Reuses the existing subtask creation endpoint (Phase 6).
        await _tasks.createSubtask(widget.taskId, s.title);
        added++;
      } catch (_) {
        failures.add(s.title);
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (failures.isEmpty) {
      Navigator.of(context).pop(added); // success — report count to caller
    } else {
      // Honest partial-failure report; do not claim full success.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $added of ${selected.length}. Failed: ${failures.join(', ')}',
          ),
        ),
      );
    }
  }

  void _removeAt(int index) {
    setState(() {
      _suggestions.removeAt(index);
      _dirty = true;
    });
  }

  /// ReorderableListView reports [newIndex] as if the dragged item were
  /// still in the list, so a downward move lands one past its real slot.
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _suggestions.removeAt(oldIndex);
      _suggestions.insert(newIndex, item);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
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
                    icon: Icons.auto_awesome_rounded,
                    size: 44,
                    iconSize: 20,
                    isAccent: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Assist',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _loading || _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Parent task context, set into an engraved well
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
                      widget.taskTitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.taskDescription != null &&
                        widget.taskDescription!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.taskDescription!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                children: [
                  // Optional instructions
                  TextField(
                    controller: _instructions,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Instructions (optional)',
                      hintText: 'e.g. Keep each step under 30 minutes',
                      prefixIcon: Icon(Icons.tune_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  NeumorphicButton(
                    isAccent: true,
                    width: double.infinity,
                    onPressed: _loading || _saving
                        ? null
                        : () => _generate(
                            isRegenerate: _suggestions.isNotEmpty,
                          ),
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
                              const Icon(Icons.auto_awesome_rounded, size: 17),
                              const SizedBox(width: 8),
                              Text(
                                _suggestions.isEmpty
                                    ? 'Generate'
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

                  if (_suggestions.isEmpty && !_loading && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          NeumorphicIconCircle(
                            icon: Icons.bolt_outlined,
                            size: 56,
                            iconSize: 26,
                            inset: true,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Tap Generate to break this task into steps.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Suggestions list with drag reorder
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _suggestions.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, i) => _SuggestionRow(
                      key: ValueKey('sug_$i'),
                      index: i,
                      suggestion: _suggestions[i],
                      onChanged: () => setState(() => _dirty = true),
                      onRemove: () => _removeAt(i),
                    ),
                  ),
                ],
              ),
            ),

            // Footer: count + actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Text('$_selectedCount selected'),
                  const Spacer(),
                  TextButton(
                    onPressed: _loading || _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  // Flexible bounds the button to the row's leftover
                  // width, so a long label shrinks instead of overflowing
                  // the footer on narrow screens.
                  Flexible(
                    child: NeumorphicButton(
                      isAccent: true,
                      onPressed: (_selectedCount == 0 || _saving || _loading)
                          ? null
                          : _addSelected,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Text(_saving ? 'Adding...' : 'Add selected'),
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
}

/// One editable suggestion row: select, edit title/description, duration, delete.
class _SuggestionRow extends StatefulWidget {
  const _SuggestionRow({
    super.key,
    required this.index,
    required this.suggestion,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final SubtaskSuggestion suggestion;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_SuggestionRow> createState() => _SuggestionRowState();
}

class _SuggestionRowState extends State<_SuggestionRow> {
  late final TextEditingController _title = TextEditingController(
    text: widget.suggestion.title,
  );
  late final TextEditingController _duration = TextEditingController(
    text: widget.suggestion.estimatedMinutes?.toString() ?? '',
  );

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    final s = widget.suggestion;
    return Padding(
      key: widget.key,
      padding: const EdgeInsets.only(bottom: 10),
      child: Neumorphic(
        depth: 3,
        borderRadius: 14,
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: s.selected,
              onChanged: (v) {
                setState(() => s.selected = v ?? false);
                widget.onChanged();
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Subtask title',
                    ),
                    onChanged: (v) {
                      s.title = v.trim();
                      widget.onChanged();
                    },
                  ),
                  if (s.description != null && s.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        s.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _duration,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: UnderlineInputBorder(),
                            hintText: 'min',
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                          ),
                          onChanged: (v) {
                            // Unparseable or non-positive input clears the
                            // estimate (null) instead of storing garbage.
                            final n = int.tryParse(v.trim());
                            s.estimatedMinutes = (n != null && n > 0)
                                ? n
                                : null;
                            widget.onChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Drag starts only from the handle (the list was built with
            // buildDefaultDragHandles: false), leaving the text fields
            // and scrolling to their normal gestures.
            ReorderableDragStartListener(
              index: widget.index,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.drag_handle,
                  color: secondary.withValues(alpha: 0.55),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: secondary.withValues(alpha: 0.75),
              ),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
