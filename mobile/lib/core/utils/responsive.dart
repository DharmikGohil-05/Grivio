import 'package:flutter/material.dart';

/// Shared responsive helpers so every screen adapts to small, normal and
/// large phones without overflow. Content is centered with a max width,
/// and horizontal padding scales with screen size.
class Responsive {
  Responsive._();

  /// Max content width — keeps layouts readable on large phones.
  static const double maxContentWidth = 480;

  /// Horizontal padding that shrinks on small screens.
  static double screenPadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 16;
    if (w < 400) return 20;
    return 24;
  }

  /// Centers content and caps its width.
  static Widget center(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
