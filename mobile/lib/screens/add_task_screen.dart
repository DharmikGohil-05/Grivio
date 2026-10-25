import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/goal_service.dart';
import '../services/task_service.dart';
import '../widgets/neumorphic.dart';
import '../widgets/ui_kit.dart';
import 'ai_improve_sheet.dart';
import 'ai_subtask_sheet.dart';

/// Add Task screen — tactile neumorphic form with title, description, due
/// date picker, duration, chip-based priority & category pickers, and
/// optional goal/milestone context, plus the two AI-assisted create paths.
class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController();
  DateTime? _dueDate;
  String _priority = 'medium';
  String _category = 'Personal';
  String? _goalId;
  String? _milestoneId;
  List<Goal> _goals = [];
  List<Milestone> _milestones = [];
  bool _saving = false;
  String? _error;

  static const _categories = [
    'Career',
    'Learning',
    'Fitness',
    'Personal',
    'Finance',
    'Communication',
    'Other',
  ];
  static const _priorities = ['low', 'medium', 'high'];

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    try {
      _goals = await GoalService().listGoals(status: 'active');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _onGoalChanged(String? goalId) async {
    setState(() {
      _goalId = goalId;
      _milestoneId = null;
      _milestones = [];
    });
    if (goalId == null) return;
    try {
      _milestones = await GoalService().listMilestones(goalId);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _dueDate = d);
  }

  Future<GrivioTask> _createTask() async {
    final created = await TaskService().createTask({
      'title': _title.text.trim(),
      if (_description.text.trim().isNotEmpty)
        'description': _description.text.trim(),
      if (_dueDate != null)
        'dueDate': _dueDate!.toIso8601String().substring(0, 10),
      'priority': _priority,
      'category': _category,
      if (_duration.text.trim().isNotEmpty)
        'estimatedMinutes': int.tryParse(_duration.text.trim()) ?? 0,
      if (_goalId != null) 'goalId': _goalId,
      if (_milestoneId != null) 'milestoneId': _milestoneId,
    });
    return created;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Task title is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _createTask();
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveWithAI() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Task title is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final task = await _createTask();
      if (!mounted) return;
      await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        builder: (_) => AISubtaskSheet(
          taskId: task.id,
          taskTitle: task.title,
          taskDescription: task.description,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
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
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;

    String label(String s) => s[0].toUpperCase() + s.substring(1);

    return Scaffold(
      // AmbientBackground paints the whole screen; see add_goal_screen.
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('New Task'),
      ),
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                  vertical: 8,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Details card ──────────────────────────────────
                      StaggeredIn(
                        child: Neumorphic(
                          borderRadius: 24,
                          depth: 8,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const NeumorphicIconCircle(
                                    icon: Icons.add_task_rounded,
                                    size: 52,
                                    iconSize: 24,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'What needs doing?',
                                          style: theme
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.25,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Small steps keep goals moving.',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            color: secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _title,
                                autofocus: true,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Task title',
                                  prefixIcon: Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _description,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Description (optional)',
                                  prefixIcon: Icon(
                                    Icons.notes_outlined,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              NeumorphicTapRow(
                                icon: Icons.calendar_today_outlined,
                                label: 'Set due date',
                                value: _dueDate == null
                                    ? null
                                    : 'Due: ${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}',
                                onTap: _pickDate,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _duration,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Estimated duration (minutes)',
                                  prefixIcon: Icon(
                                    Icons.schedule_outlined,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Organize card ─────────────────────────────────
                      StaggeredIn(
                        delay: const Duration(milliseconds: 100),
                        child: Neumorphic(
                          borderRadius: 24,
                          depth: 8,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'PRIORITY',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                  color: secondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final p in _priorities)
                                    NeumorphicChip(
                                      label: label(p),
                                      selected: _priority == p,
                                      onTap: () =>
                                          setState(() => _priority = p),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'CATEGORY',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                  color: secondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final c in _categories)
                                    NeumorphicChip(
                                      label: c,
                                      selected: _category == c,
                                      onTap: () =>
                                          setState(() => _category = c),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              DropdownButtonFormField<String>(
                                value: _goalId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Goal (optional)',
                                  prefixIcon: Icon(
                                    Icons.flag_outlined,
                                    size: 20,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('None'),
                                  ),
                                  ..._goals.map(
                                    (g) => DropdownMenuItem(
                                      value: g.id,
                                      child: Text(
                                        g.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: _onGoalChanged,
                              ),
                              if (_goalId != null) ...[
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _milestoneId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Milestone (optional)',
                                    prefixIcon: Icon(
                                      Icons.outlined_flag_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('None'),
                                    ),
                                    ..._milestones.map(
                                      (m) => DropdownMenuItem(
                                        value: m.id,
                                        child: Text(
                                          m.title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _milestoneId = v),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: ErrorPill(message: _error!),
                        ),
                      const SizedBox(height: 24),

                      // ── Actions ───────────────────────────────────────
                      StaggeredIn(
                        delay: const Duration(milliseconds: 200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            NeumorphicButton(
                              isAccent: true,
                              width: double.infinity,
                              onPressed: _saving ? null : _save,
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                                        Text('Creating task...'),
                                      ],
                                    )
                                  : const Text('Create Task'),
                            ),
                            const SizedBox(height: 12),
                            NeumorphicButton(
                              width: double.infinity,
                              onPressed: _saving ? null : _saveWithAI,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 17),
                                  SizedBox(width: 8),
                                  Text('Create with AI Subtasks'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            NeumorphicButton(
                              width: double.infinity,
                              onPressed: _saving
                                  ? null
                                  : () => showModalBottomSheet<bool>(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (_) => AIImproveSheet(
                                          taskId: null,
                                          title: _title.text.trim(),
                                          description:
                                              _description.text.trim(),
                                          unsavedMode: true,
                                          onApplySuggestion: (s) {
                                            if ((s.title ?? '').isNotEmpty) {
                                              _title.text = s.title!;
                                            }
                                            if (s.description != null) {
                                              _description.text =
                                                  s.description!;
                                            }
                                            if (s.priority != null) {
                                              _priority = s.priority!;
                                            }
                                            if (s.category != null) {
                                              _category = s.category!;
                                            }
                                            if (s.estimatedMinutes != null) {
                                              _duration.text =
                                                  s.estimatedMinutes
                                                      .toString();
                                            }
                                            setState(() {});
                                          },
                                        ),
                                      ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_fix_high, size: 17),
                                  SizedBox(width: 8),
                                  Text('Improve Task with AI'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
