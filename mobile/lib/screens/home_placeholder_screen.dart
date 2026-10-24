import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'profile_screen.dart';
import 'goals_screen.dart';
import 'tasks_screen.dart';

/// Temporary authenticated home — confirms login works and provides
/// logout. The real Home dashboard arrives in Phase 7.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key, required this.onLoggedOut});
  final VoidCallback onLoggedOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grivio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          TextButton(
            onPressed: () async {
              await AuthService().logout();
              onLoggedOut();
            },
            child: const Text('Log out'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'You are logged in',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Authentication foundation is ready.\n'
                'Home, focus and more arrive in later phases.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const GoalsScreen())),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Open Goals'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const TasksScreen())),
                icon: const Icon(Icons.check_box_outline_blank),
                label: const Text('Open Tasks'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
