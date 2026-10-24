import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/goal_service.dart';
import '../services/task_service.dart';
import 'ai_improve_sheet.dart';
import 'ai_subtask_sheet.dart';

/// Add Task screen with title, description, due date picker, priority,
/// duration, category, and optional goal context.
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('New Task')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Task title'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(
              _dueDate == null
                  ? 'Set due date'
                  : 'Due: ${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: _priorities
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p[0].toUpperCase() + p.substring(1)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _priority = v!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Estimated duration (minutes)',
              prefixIcon: Icon(Icons.schedule_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _goalId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Goal (optional)'),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('None')),
              ..._goals.map(
                (g) => DropdownMenuItem(
                  value: g.id,
                  child: Text(g.name, overflow: TextOverflow.ellipsis),
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
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('None'),
                ),
                ..._milestones.map(
                  (m) => DropdownMenuItem(
                    value: m.id,
                    child: Text(m.title, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _milestoneId = v),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: isDark ? AppColors.darkError : AppColors.lightError,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Creating task...' : 'Create Task'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : _saveWithAI,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Create with AI Subtasks'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () => showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AIImproveSheet(
                      taskId: null,
                      title: _title.text.trim(),
                      description: _description.text.trim(),
                      unsavedMode: true,
                      onApplySuggestion: (s) {
                        if ((s.title ?? '').isNotEmpty) {
                          _title.text = s.title!;
                        }
                        if (s.description != null) {
                          _description.text = s.description!;
                        }
                        if (s.priority != null) {
                          _priority = s.priority!;
                        }
                        if (s.category != null) {
                          _category = s.category!;
                        }
                        if (s.estimatedMinutes != null) {
                          _duration.text = s.estimatedMinutes.toString();
                        }
                        setState(() {});
                      },
                    ),
                  ),
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Improve Task with AI'),
          ),
        ],
      ),
    );
  }
}
