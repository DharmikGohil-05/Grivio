import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'neumorphic.dart';

// =============================================================================
// GRIVIO UI KIT — decorative layer on top of the neumorphic system
//
// Soft ambient depth (glowing orbs), graceful entrance animations and the
// brand wordmark. Palette-safe: only derives from AppColors tokens, adapts
// automatically to light / dark mode. Purely presentational — never blocks
// interaction, never changes layout behavior.
// =============================================================================

/// Full-bleed decorative background: a calm base wash plus a few soft,
/// blurred accent "orbs" that give screens subtle depth behind content.
///
/// Place it as the first child of a `Stack` inside a screen body:
/// ```dart
/// body: Stack(
///   children: [
///     const AmbientBackground(),
///     SafeArea(child: ...),
///   ],
/// );
/// ```
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, this.intensity = 1.0});

  /// 0 = invisible, 1 = default soft glow, >1 = stronger.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final a = intensity.clamp(0.0, 2.0);

    // IgnorePointer so the decoration never intercepts taps meant for
    // the real content stacked on top of it.
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: bg),
            // The orbs are deliberately positioned beyond the screen
            // edges; ClipRect trims the overflow so only a soft gradient
            // arc peeks in from each corner.
            Positioned(
              top: -110,
              right: -80,
              child: _GlowOrb(
                size: 300,
                color: accent.withValues(alpha: (isDark ? 0.13 : 0.10) * a),
              ),
            ),
            Positioned(
              top: 220,
              left: -120,
              child: _GlowOrb(
                size: 260,
                color: accent.withValues(alpha: (isDark ? 0.08 : 0.07) * a),
              ),
            ),
            Positioned(
              bottom: -110,
              right: -60,
              child: _GlowOrb(
                size: 240,
                color: accent.withValues(alpha: (isDark ? 0.09 : 0.07) * a),
              ),
            ),
            Positioned(
              bottom: 140,
              left: -60,
              child: _GlowOrb(
                size: 180,
                color: accent.withValues(alpha: (isDark ? 0.06 : 0.05) * a),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

/// Elegant entrance animation: fade + slight slide-up, optionally delayed.
/// Use for staggered reveals of headers, cards and buttons.
class StaggeredIn extends StatefulWidget {
  const StaggeredIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.offset = const Offset(0, 0.05),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Slide distance as a fraction of the child's size (0.05 = 5%).
  final Offset offset;

  @override
  State<StaggeredIn> createState() => _StaggeredInState();
}

class _StaggeredInState extends State<StaggeredIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      // Deferring forward() lets sibling widgets stagger in: give each
      // one a larger delay and they animate one after another.
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// GRIVIO wordmark rendered as clean, wide-spaced letters with the accent
/// gradient — used on splash and auth screens.
class GrivioWordmark extends StatelessWidget {
  const GrivioWordmark({super.key, this.fontSize = 26, this.letterSpacing});

  final double fontSize;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Brand gradient: indigo → supporting cyan, the same treatment the
    // web wordmark uses.
    final from = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final to = isDark ? AppColors.darkCyan : AppColors.lightCyan;

    // The text itself is drawn white; the ShaderMask then replaces those
    // pixels with the accent gradient, so the gradient only tints the
    // glyphs and leaves everything else untouched.
    return ShaderMask(
      shaderCallback: (bounds) =>
          LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [from, to])
              .createShader(bounds),
      child: Text(
        'GRIVIO',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: letterSpacing ?? fontSize * 0.22,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Neumorphic circular icon holder — for step heroes and brand marks.
class NeumorphicIconCircle extends StatelessWidget {
  const NeumorphicIconCircle({
    super.key,
    required this.icon,
    this.size = 64,
    this.iconSize,
    this.isAccent = false,
    this.inset = false,
  });

  final IconData icon;
  final double size;
  final double? iconSize;
  final bool isAccent;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final fg = isAccent
        ? (isDark ? AppColors.darkBackground : Colors.white)
        : accent;

    return Neumorphic(
      borderRadius: size / 2,
      inset: inset,
      depth: 6,
      padding: EdgeInsets.all(size * 0.28),
      color: isAccent
          ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
          : null,
      child: Icon(icon, size: iconSize ?? size * 0.44, color: fg),
    );
  }
}

/// Soft pulsing ring used around hero marks (splash logo, etc.).
class PulseRing extends StatefulWidget {
  const PulseRing({
    super.key,
    required this.size,
    this.delay = Duration.zero,
    this.color,
  });

  final double size;
  final Duration delay;
  final Color? color;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _start();
  }

  Future<void> _start() async {
    if (widget.delay != Duration.zero) {
      await Future<void>.delayed(widget.delay);
      if (!mounted) return;
    }
    // Repeat without reverse so consecutive rings can be offset in time.
    await _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.color ??
        (isDark ? AppColors.darkAccent : AppColors.lightAccent);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // One pulse = grow while fading out over a full cycle; the
        // repeat() above restarts it seamlessly.
        final scale = 0.85 + t * 0.4;
        final opacity = (1 - t) * (isDark ? 0.22 : 0.18);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.4),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Soft inset error message with an icon — friendlier than plain red text.
/// Fits the neumorphic system (inset well, subtle accent border).
class ErrorPill extends StatelessWidget {
  const ErrorPill({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final error = isDark ? AppColors.darkError : AppColors.lightError;

    return Neumorphic(
      inset: true,
      depth: 3,
      borderRadius: AppRadius.md,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: error.withValues(alpha: 0.35),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.4,
                color: error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact three-dot loading indicator that inherits its color from the
/// surrounding DefaultTextStyle (e.g. white inside accent buttons).
class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key, this.dotSize = 6, this.spacing = 4});

  final double dotSize;
  final double spacing;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? Colors.white;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot lags the previous one by 20% of the cycle so the
            // pulses chase each other; the triangle wave below turns the
            // 0–1 phase into a smooth fade in/out.
            final phase = (_controller.value - i * 0.2) % 1.0;
            final pulse = Curves.easeInOut.transform(
              phase < 0.5 ? phase * 2 : (1 - phase) * 2,
            );
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: Opacity(
                opacity: 0.35 + pulse * 0.65,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Animated count-up number: eases from zero (or the previous value) to
/// [value], formatting each frame through [format]. Gives summary stats
/// and progress percentages a "the numbers are alive" feel.
class AnimatedCountUp extends StatelessWidget {
  const AnimatedCountUp({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final int value;

  /// Called every animation frame with the current (rounded) value.
  final String Function(int) format;

  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text(format(v.round()), style: style),
    );
  }
}
