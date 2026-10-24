import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/goal_service.dart';

/// Add Goal screen with name, why it matters, target date, and growth area.
class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _name = TextEditingController();
  final _why = TextEditingController();
  DateTime? _targetDate;
  String? _growthArea;
  bool _saving = false;
  String? _error;

  static const _areas = [
    'Career',
    'Learning',
    'Fitness',
    'Personal',
    'Finance',
    'Communication',
    'Other',
  ];

  @override
  void dispose() {
    _name.dispose();
    _why.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _targetDate = d);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Goal name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await GoalService().createGoal({
        'name': _name.text.trim(),
        if (_why.text.trim().isNotEmpty) 'whyItMatters': _why.text.trim(),
        if (_targetDate != null)
          'targetDate': _targetDate!.toIso8601String().substring(0, 10),
        if (_growthArea != null) 'growthArea': _growthArea,
      });
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
      appBar: AppBar(title: const Text('New Goal')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Goal title'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _why,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Why is this goal important? (optional)',
              hintText:
                  'e.g. This will allow me to transition into engineering leadership.',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(
              _targetDate == null
                  ? 'Set a target completion date'
                  : 'Target: ${_targetDate!.month}/${_targetDate!.day}/${_targetDate!.year}',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _growthArea,
            decoration: const InputDecoration(
              labelText: 'Growth area',
              prefixIcon: Icon(Icons.track_changes_outlined, size: 20),
            ),
            items: _areas
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => _growthArea = v),
          ),
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
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Creating goal...' : 'Create Goal'),
          ),
        ],
      ),
    );
  }
}
