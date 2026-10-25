import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'neumorphic.dart';

// =============================================================================
// GRIVIO NEUMORPHIC BOTTOM NAVIGATION
//
// A soft raised pill floating above the safe-area inset, with an inset
// accent pill marking the active tab. Purely presentational: destinations,
// ordering, routing, and tab state all stay with the caller (MainScaffold
// keeps its IndexedStack) — this widget only reports taps, so replacing
// Material's NavigationBar is a visual upgrade, not a behavior change.
// =============================================================================

/// Bottom navigation for the 5 GRIVIO tabs:
/// Home · Goals · Focus · Progress · Profile
class GrivioBottomNav extends StatelessWidget {
  const GrivioBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  // Same icons, labels, and order as the NavigationBar this replaced, so
  // navigation behavior is byte-for-byte identical.
  static const List<_NavDestination> _destinations = [
    _NavDestination('Home', Icons.home_outlined, Icons.home_rounded),
    _NavDestination('Goals', Icons.flag_outlined, Icons.flag_rounded),
    // Focus is the app's core ritual; its active tab carries a small
    // accent dot for slightly stronger emphasis (see the dot below).
    _NavDestination(
      'Focus',
      Icons.timer_outlined,
      Icons.timer_rounded,
      emphasize: true,
    ),
    _NavDestination(
      'Progress',
      Icons.insights_outlined,
      Icons.insights_rounded,
    ),
    _NavDestination('Profile', Icons.person_outline, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // No inset needed at the top; side/bottom insets keep the floating
      // pill clear of screen edges and the home-indicator gesture area.
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Neumorphic(
        // Large radius + modest depth: a calm raised surface, not a
        // flashy floating capsule.
        borderRadius: 24,
        depth: 4,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            for (var i = 0; i < _destinations.length; i++)
              Expanded(
                child: _NavItem(
                  destination: _destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onDestinationSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(
    this.label,
    this.icon,
    this.selectedIcon, {
    this.emphasize = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool emphasize;
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  // Press feedback = the tab scales down a hair, like a real key being
  // depressed (same tactile language as NeumorphicButton).
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeColor = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    // Restrained cyan detail for the emphasized tab.
    final cyanColor = isDark ? AppColors.darkCyan : AppColors.lightCyan;
    final idleColor = isDark
        ? AppColors.darkMutedText
        : AppColors.lightMutedText;
    final pillColor = isDark
        ? AppColors.darkAccentSurface
        : AppColors.lightAccentSurface;

    final selected = widget.selected;
    final dest = widget.destination;
    // Only the emphasized destination (Focus) shows the accent dot, and
    // only while it is the active tab.
    final showDot = dest.emphasize && selected;

    // A short, single easing for every moving piece so the transition
    // reads as one calm motion rather than a cascade.
    const duration = Duration(milliseconds: 220);

    // A gentle inset on the active pill so the selection reads as pressed
    // into the raised bar — same geometry the app's other inset surfaces
    // use (dark shade bottom-right, bright highlight top-left).
    final insetShadows = selected
        ? [
            BoxShadow(
              color: (isDark
                      ? AppColors.darkShadowDark
                      : AppColors.lightShadowDark)
                  .withValues(alpha: isDark ? 0.55 : 0.5),
              offset: const Offset(1.5, 1.5),
              blurRadius: 3,
            ),
            BoxShadow(
              color: (isDark
                      ? AppColors.darkShadowLight
                      : AppColors.lightShadowLight)
                  .withValues(alpha: isDark ? 0.7 : 0.9),
              offset: const Offset(-1.5, -1.5),
              blurRadius: 2,
            ),
          ]
        : null;

    return Semantics(
      button: true,
      selected: selected,
      label: dest.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              // Inset indigo-tinted pill marks the active tab; it fades in
              // and out between tabs as the icons recolor.
              color: selected ? pillColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: insetShadows,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The icon color eases between idle and accent instead of
                // snapping; the glyph itself swaps outlined → rounded.
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: selected ? activeColor : idleColor,
                  ),
                  duration: duration,
                  curve: Curves.easeInOut,
                  builder: (context, color, child) => IconTheme(
                    data: IconThemeData(color: color ?? idleColor),
                    child: child!,
                  ),
                  child: Icon(
                    selected ? dest.selectedIcon : dest.icon,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? activeColor : idleColor,
                  ),
                  child: Text(dest.label),
                ),
                // The dot's slot is always laid out (AnimatedOpacity keeps
                // its space at opacity 0), so the bar height never jumps
                // when the emphasis appears or changes tabs.
                AnimatedOpacity(
                  opacity: showDot ? 1 : 0,
                  duration: duration,
                  curve: Curves.easeInOut,
                  child: Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cyanColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
