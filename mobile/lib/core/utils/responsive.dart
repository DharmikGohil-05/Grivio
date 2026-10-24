import 'package:flutter/material.dart';

/// Shared responsive helpers so every screen adapts to small, normal and
/// large phones without overflow. Content is centered with a max width,
/// and horizontal padding scales with screen size.
class Responsive {
  Responsive._();

  /// Max content width — keeps layouts readable on large phones.
  /// Without a cap, text and cards stretch edge-to-edge on wide screens and
  /// lines become unreadably long; 480 px keeps a comfortable measure.
  static const double maxContentWidth = 480;

  /// Horizontal padding that shrinks on small screens.
  /// Every pixel matters on a ~360 px phone, so the gutter tightens there
  /// and grows to 24 px on roomier screens for a more airy layout.
  static double screenPadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 16;
    if (w < 400) return 20;
    return 24;
  }

  /// Centers content and caps its width.
  /// Below the cap the child fills the screen; above it, the child is
  /// centered with equal gutters — one wrapper makes a screen responsive
  /// without the screen ever checking MediaQuery itself.
  static Widget center(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
