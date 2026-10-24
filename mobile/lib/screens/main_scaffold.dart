import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'focus_screen.dart';
import 'goals_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';

/// Main navigation scaffold — exactly 5 destinations:
/// Home · Goals · Focus · Progress · Profile
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, required this.onLoggedOut});
  final VoidCallback onLoggedOut;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pages = [
      const HomeScreen(),
      const GoalsScreen(),
      const FocusScreen(),
      const ProgressScreen(),
      ProfileScreen(onLoggedOut: widget.onLoggedOut),
    ];

    return Scaffold(
      // Soft ambient depth behind every tab; tab screens paint transparent
      // scaffolds (via the wrapped Theme) so the glow shows through.
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          Theme(
            data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : AppColors.lightShadowDark.withValues(alpha: 0.45),
              offset: const Offset(0, -4),
              blurRadius: 14,
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: isDark
                ? AppColors.darkAccentSurface
                : AppColors.lightAccentSurface,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.flag_outlined),
                selectedIcon: Icon(Icons.flag_rounded),
                label: 'Goals',
              ),
              NavigationDestination(
                icon: Icon(Icons.timer_outlined),
                selectedIcon: Icon(Icons.timer_rounded),
                label: 'Focus',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Progress',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
