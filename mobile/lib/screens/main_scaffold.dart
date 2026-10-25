import 'package:flutter/material.dart';

import '../widgets/neumorphic_nav_bar.dart';
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
      // Neumorphic raised pill with an inset active tab — same 5
      // destinations, same routing; SafeArea is handled inside the widget.
      bottomNavigationBar: GrivioBottomNav(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
