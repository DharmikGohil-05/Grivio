import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/goal_service.dart';
import '../widgets/neumorphic.dart';
import '../widgets/ui_kit.dart';

/// Add Goal screen — a tactile neumorphic form: inset title/motivation
/// fields, an engraved date-picker row, a growth-area chip selector and a
/// raised accent action, all over the ambient background.
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
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;

    return Scaffold(
      // The body's AmbientBackground paints the whole screen (it must
      // extend behind the transparent AppBar, or the status-bar area
      // would be left as a transparent hole).
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('New Goal'),
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
                  child: StaggeredIn(
                    child: Neumorphic(
                      borderRadius: 24,
                      depth: 8,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Hero ──────────────────────────────────────────
                          Row(
                            children: [
                              const NeumorphicIconCircle(
                                icon: Icons.flag_rounded,
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
                                      'Set a direction',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.25,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Name it, anchor it to why it matters.',
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

                          // ── Fields ────────────────────────────────────────
                          TextField(
                            controller: _name,
                            autofocus: true,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Goal title',
                              prefixIcon: Icon(Icons.flag_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _why,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Why is this goal important?',
                              hintText:
                                  'e.g. This will allow me to transition into engineering leadership.',
                              prefixIcon: Icon(
                                Icons.favorite_outline,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          NeumorphicTapRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Set a target completion date',
                            value: _targetDate == null
                                ? null
                                : 'Target: ${_targetDate!.month}/${_targetDate!.day}/${_targetDate!.year}',
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 20),

                          // ── Growth area chips ─────────────────────────────
                          Text(
                            'GROWTH AREA',
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
                              for (final area in _areas)
                                NeumorphicChip(
                                  label: area,
                                  selected: _growthArea == area,
                                  onTap: () => setState(() =>
                                      _growthArea =
                                          _growthArea == area ? null : area),
                                ),
                            ],
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 18),
                            ErrorPill(message: _error!),
                          ],
                          const SizedBox(height: 24),
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
                                      Text('Creating goal...'),
                                    ],
                                  )
                                : const Text('Create Goal'),
                          ),
                        ],
                      ),
                    ),
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
