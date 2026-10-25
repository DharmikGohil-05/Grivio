import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';

// =============================================================================
// GRIVIO NEUMORPHIC & UI SYSTEM
//
// Tactile, calm, and subtle surface depth system.
// Adapts automatically to Light, Dark, and System modes.
// =============================================================================

// raised = surface floats above the background (the default look);
// inset = pressed/engraved well with shadows flipped inward;
// flat = color + border only, no shadows at all.
enum NeumorphicStyle { raised, inset, flat }

/// Tactile container with controlled soft light and shadow.
class Neumorphic extends StatelessWidget {
  const Neumorphic({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.depth = 5,
    this.color,
    this.inset = false,
    this.style,
    this.borderColor,
    this.borderWidth = 1,
    this.width,
    this.height,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double depth;
  final Color? color;
  final bool inset;
  final NeumorphicStyle? style;
  final Color? borderColor;
  final double borderWidth;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // `inset: true` is shorthand for NeumorphicStyle.inset; an explicit
    // `style` always wins over the convenience flag.
    final effectiveStyle =
        style ?? (inset ? NeumorphicStyle.inset : NeumorphicStyle.raised);

    final baseColor =
        color ?? (isDark ? AppColors.darkSurface : AppColors.lightSurface);

    // Both shadow colors come from theme tokens (light vs dark sets), so
    // the same depth reads correctly on either background: a dark shadow
    // on one side, a light highlight on the other, which creates the
    // illusion of a single soft light source.
    final shadowDark = isDark
        ? AppColors.darkShadowDark.withValues(alpha: 0.65)
        : AppColors.lightShadowDark.withValues(alpha: 0.6);

    final shadowLight = isDark
        ? AppColors.darkShadowLight.withValues(alpha: 0.25)
        : AppColors.lightShadowLight.withValues(alpha: 0.95);

    final defaultBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    List<BoxShadow> shadows;
    if (effectiveStyle == NeumorphicStyle.flat) {
      shadows = const [];
    } else if (effectiveStyle == NeumorphicStyle.inset) {
      // Inset flips the geometry: smaller offsets, negative spread and
      // reduced alpha make the surface look pressed *into* the page
      // rather than raised above it.
      shadows = [
        BoxShadow(
          color: shadowDark.withValues(alpha: isDark ? 0.35 : 0.25),
          offset: Offset(depth / 2, depth / 2),
          blurRadius: depth,
          spreadRadius: -1,
        ),
        BoxShadow(
          color: shadowLight.withValues(alpha: isDark ? 0.15 : 0.6),
          offset: Offset(-depth / 2, -depth / 2),
          blurRadius: depth,
          spreadRadius: -1,
        ),
      ];
    } else {
      // Raised style
      shadows = [
        BoxShadow(
          color: shadowDark,
          offset: Offset(depth, depth),
          blurRadius: depth * 2.2,
          spreadRadius: -1,
        ),
        BoxShadow(
          color: shadowLight,
          offset: Offset(-depth, -depth),
          blurRadius: depth * 2.0,
          spreadRadius: -1,
        ),
      ];
    }

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? defaultBorder,
          width: borderWidth,
        ),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}

/// Interactive tactile button with smooth pressed feedback.
class NeumorphicButton extends StatefulWidget {
  const NeumorphicButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.isAccent = false,
    this.depth = 4,
    this.width,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isAccent;
  final double depth;
  final double? width;

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  // Press feedback = the surface "sinks": it scales to 0.98 and its
  // depth collapses toward 0, imitating a real button being depressed.
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final enabled = widget.onPressed != null;

    final bgColor = widget.isAccent
        ? (_isPressed
              ? (isDark
                    ? AppColors.darkAccentPressed
                    : AppColors.lightAccentPressed)
              : (isDark ? AppColors.darkAccent : AppColors.lightAccent))
        : (isDark ? AppColors.darkSecondarySurface : AppColors.lightSurface);

    final textColor = widget.isAccent
        ? (isDark ? AppColors.darkBackground : Colors.white)
        : (isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText);

    final currentDepth = _isPressed ? 1.0 : widget.depth;

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _isPressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
        child: SizedBox(
          width: widget.width,
          child: Neumorphic(
            // Disabled state keeps the color but fades it and flattens
            // the depth, so an unusable button visibly loses its relief.
            color: enabled ? bgColor : bgColor.withValues(alpha: 0.5),
            depth: enabled ? currentDepth : 0,
            borderRadius: widget.borderRadius,
            padding: widget.padding,
            borderColor: widget.isAccent ? Colors.transparent : null,
            child: Center(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  fontSize: 15,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo mark for GRIVIO with asset support and elegant fallback.
class GrivioLogo extends StatelessWidget {
  const GrivioLogo({super.key, this.size = 54, this.borderRadius = 16});

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : AppColors.lightShadowDark.withValues(alpha: 0.6),
            offset: const Offset(3, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/grivio_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          // If the bundled asset is missing (or fails to load), show a
          // tinted placeholder tile with the accent icon instead of a
          // broken-image box.
          errorBuilder: (_, __, ___) {
            return Container(
              color: isDark
                  ? AppColors.darkSecondarySurface
                  : AppColors.lightAccentSurface,
              child: Icon(
                Icons.trending_up_rounded,
                size: size * 0.55,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 3-way Segmented Control for Theme Selection (System / Light / Dark).
/// Instantly updates the app and persists to storage.
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final currentMode = ThemeController.instance.themeMode;

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSecondarySurface
                : AppColors.lightSecondarySurface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _SegmentOption(
                label: 'System',
                icon: Icons.brightness_auto_outlined,
                selected: currentMode == ThemeMode.system,
                onTap: () =>
                    ThemeController.instance.setThemeMode(ThemeMode.system),
              ),
              _SegmentOption(
                label: 'Light',
                icon: Icons.light_mode_outlined,
                selected: currentMode == ThemeMode.light,
                onTap: () =>
                    ThemeController.instance.setThemeMode(ThemeMode.light),
              ),
              _SegmentOption(
                label: 'Dark',
                icon: Icons.dark_mode_outlined,
                selected: currentMode == ThemeMode.dark,
                onTap: () =>
                    ThemeController.instance.setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentOption extends StatelessWidget {
  const _SegmentOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeBg = isDark ? AppColors.darkElevatedSurface : Colors.white;
    final activeColor = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final inactiveColor = isDark
        ? AppColors.darkMutedText
        : AppColors.lightSecondaryText;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? activeColor : inactiveColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? (isDark
                            ? AppColors.darkPrimaryText
                            : AppColors.lightPrimaryText)
                      : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress arc painted with the brand's indigo → cyan sweep gradient —
/// the same treatment the web client's ring uses. Drop-in replacement for
/// an explicit-value `CircularProgressIndicator` (0.0–1.0), with the track
/// rendered as a soft engraved groove.
class GradientProgressArc extends StatelessWidget {
  const GradientProgressArc({
    super.key,
    required this.value,
    this.size = 140,
    this.strokeWidth = 9,
    this.trackColor,
  });

  /// Completion in 0.0–1.0; clamped so a caller can never overflow.
  final double value;
  final double size;
  final double strokeWidth;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final from = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final to = isDark ? AppColors.darkCyan : AppColors.lightCyan;
    final track =
        trackColor ??
        (isDark ? AppColors.darkProgressTrack : AppColors.lightSecondarySurface);

    // Tween between the previous and next value so progress changes
    // (focus ring ticking, range switches) ease instead of jumping.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _GradientArcPainter(
            value: animatedValue,
            strokeWidth: strokeWidth,
            from: from,
            to: to,
            track: track,
          ),
        ),
      ),
    );
  }
}

class _GradientArcPainter extends CustomPainter {
  const _GradientArcPainter({
    required this.value,
    required this.strokeWidth,
    required this.from,
    required this.to,
    required this.track,
  });

  final double value;
  final double strokeWidth;
  final Color from;
  final Color to;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track first — a soft groove the arc sits inside.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = track,
    );

    if (value <= 0) return;

    // The sweep starts at the top (12 o'clock) and eases indigo → cyan
    // clockwise, matching the web ring's gradient direction.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader =
            SweepGradient(
              startAngle: -math.pi / 2,
              endAngle: math.pi * 1.5,
              colors: [from, to],
              transform: const GradientRotation(-math.pi / 2),
            ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GradientArcPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.track != track;
}

/// Depth progress ring — the reference-style dashboard centrepiece.
///
/// Layered exactly like the web client's `.depth-ring`:
///  1. a raised disc (upper-left highlight, lower-right shade),
///  2. an ENGRAVED groove (inset shadows clipped to the well),
///  3. a track with an indigo→cyan gradient arc wrapped in a soft glow,
///  4. a glowing cyan head dot at the leading edge of the arc,
///  5. bold centred text.
/// The arc eases to its value via [TweenAnimationBuilder].
class GrivioProgressRing extends StatelessWidget {
  const GrivioProgressRing({
    super.key,
    required this.progress,
    required this.centerText,
    this.subtitleText,
    this.size = 148,
    this.strokeWidth = 13,
  });

  final double progress;
  final String centerText;
  final String? subtitleText;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final wellColor = isDark
        ? AppColors.darkSecondarySurface
        : AppColors.lightSecondarySurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final shadowDark = isDark
        ? AppColors.darkShadowDark.withValues(alpha: 0.72)
        : AppColors.lightShadowDark.withValues(alpha: 0.6);
    final shadowLight = isDark
        ? AppColors.darkShadowLight.withValues(alpha: 0.4)
        : AppColors.lightShadowLight.withValues(alpha: 0.95);
    final from = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final to = isDark ? AppColors.darkCyan : AppColors.lightCyan;
    final track = isDark ? AppColors.darkProgressTrack : AppColors.lightSecondarySurface;
    final glow = isDark ? AppColors.darkGlowAccent : AppColors.lightGlowAccent;
    final glowCyan = isDark ? AppColors.darkGlowCyan : AppColors.lightGlowCyan;

    return Semantics(
      label: 'Progress, $centerText',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, _) => Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _DepthRingPainter(
                  value: animatedValue,
                  strokeWidth: strokeWidth,
                  surface: surface,
                  wellColor: wellColor,
                  border: border,
                  shadowDark: shadowDark,
                  shadowLight: shadowLight,
                  from: from,
                  to: to,
                  track: track,
                  glow: glow,
                  glowCyan: glowCyan,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerText,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (subtitleText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitleText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkMutedText
                            : AppColors.lightSecondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepthRingPainter extends CustomPainter {
  const _DepthRingPainter({
    required this.value,
    required this.strokeWidth,
    required this.surface,
    required this.wellColor,
    required this.border,
    required this.shadowDark,
    required this.shadowLight,
    required this.from,
    required this.to,
    required this.track,
    required this.glow,
    required this.glowCyan,
  });

  final double value;
  final double strokeWidth;
  final Color surface;
  final Color wellColor;
  final Color border;
  final Color shadowDark;
  final Color shadowLight;
  final Color from;
  final Color to;
  final Color track;
  final Color glow;
  final Color glowCyan;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    // The groove sits a stroke's width inside the disc edge.
    final wellRadius = outer - strokeWidth - 3;
    final arcRadius = wellRadius - strokeWidth / 2 - 2;

    // ── 1. Raised disc: cast shade bottom-right, highlight top-left ─────────
    canvas.drawCircle(
      center + const Offset(4, 5),
      outer - 2,
      Paint()
        ..color = shadowDark
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawCircle(
      center + const Offset(-4, -4),
      outer - 2,
      Paint()
        ..color = shadowLight
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      center,
      outer - 1,
      Paint()
        ..color = surface
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      outer - 1,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── 2. Engraved groove: inset shadows clipped to the well ───────────────
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: wellRadius)));
    canvas.drawCircle(
      center,
      wellRadius,
      Paint()..color = wellColor..style = PaintingStyle.fill,
    );
    // Dark creeps in from the upper-left rim, light bounces onto the
    // lower-right rim — the flipped light source that reads as "pressed in".
    canvas.drawCircle(
      center + const Offset(-3, -3),
      wellRadius,
      Paint()
        ..color = shadowDark.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      center + const Offset(3, 3),
      wellRadius,
      Paint()
        ..color = shadowLight.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();

    final rect = Rect.fromCircle(center: center, radius: arcRadius);

    // ── 3. Track + glowing gradient arc ─────────────────────────────────────
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = track,
    );

    if (value > 0) {
      final sweep = math.pi * 2 * value;
      final arcPath = Path()..addArc(rect, -math.pi / 2, sweep);

      // Soft halo under the crisp arc (the reference's glow).
      canvas.drawPath(
        arcPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = glow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawPath(
        arcPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader =
              SweepGradient(
                startAngle: -math.pi / 2,
                endAngle: math.pi * 1.5,
                colors: [from, to],
                transform: const GradientRotation(-math.pi / 2),
              ).createShader(rect),
      );

      // ── 4. Glowing head dot at the leading edge ───────────────────────────
      final angle = -math.pi / 2 + sweep;
      final head = center + Offset(math.cos(angle), math.sin(angle)) * arcRadius;
      final headRadius = strokeWidth * 0.34;
      canvas.drawCircle(
        head,
        headRadius * 2.2,
        Paint()
          ..color = glowCyan
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(head, headRadius, Paint()..color = to);
    }
  }

  @override
  bool shouldRepaint(_DepthRingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.surface != surface ||
      oldDelegate.from != from ||
      oldDelegate.to != to;
}

/// Reusable section title component.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.onTrailingTap});

  final String text;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (trailing == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
          const Spacer(),
          if (onTrailingTap != null)
            InkWell(
              onTap: onTrailingTap,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  trailing!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkAccent
                        : AppColors.lightAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Selectable tactile chip — a small raised key that settles into an
/// inset, accent-tinted well when selected (the same geometry the active
/// nav pill uses). The picker primitive for category, priority and
/// growth-area choices across the app's forms.
class NeumorphicChip extends StatelessWidget {
  const NeumorphicChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final idleFg = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    final idleBg = isDark
        ? AppColors.darkSecondarySurface
        : AppColors.lightSurface;
    final selectedBg = isDark
        ? AppColors.darkAccentSurface
        : AppColors.lightAccentSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            // Selected = pressed *into* the form: inset shadows and the
            // accent-tinted well; idle = a small raised key.
            color: selected ? selectedBg : idleBg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.35)
                  : border,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: (isDark
                              ? AppColors.darkShadowDark
                              : AppColors.lightShadowDark)
                          .withValues(alpha: isDark ? 0.5 : 0.45),
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: (isDark
                              ? AppColors.darkShadowLight
                              : AppColors.lightShadowLight)
                          .withValues(alpha: isDark ? 0.6 : 0.9),
                      offset: const Offset(-2, -2),
                      blurRadius: 3,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: (isDark
                              ? AppColors.darkShadowDark
                              : AppColors.lightShadowDark)
                          .withValues(alpha: isDark ? 0.45 : 0.4),
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: (isDark
                              ? AppColors.darkShadowLight
                              : AppColors.lightShadowLight)
                          .withValues(alpha: isDark ? 0.2 : 0.85),
                      offset: const Offset(-2, -2),
                      blurRadius: 4,
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? accent : idleFg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? accent : idleFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable inset row — an engraved well holding an icon, a label (or the
/// chosen value) and a trailing chevron. The neumorphic stand-in for
/// "field-shaped" actions such as date pickers.
class NeumorphicTapRow extends StatelessWidget {
  const NeumorphicTapRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;

  /// When set, shown instead of [label] — the chosen value.
  final String? value;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;
    final hasValue = value != null;

    return Semantics(
      button: true,
      label: label,
      value: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Neumorphic(
          inset: true,
          depth: 3,
          borderRadius: AppRadius.md,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: hasValue ? accent : secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value ?? label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    fontWeight:
                        hasValue ? FontWeight.w600 : FontWeight.w500,
                    color: hasValue
                        ? (isDark
                              ? AppColors.darkPrimaryText
                              : AppColors.lightPrimaryText)
                        : secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: secondary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linear progress bar whose fill eases to its new value instead of
/// snapping — the animated counterpart of [LinearProgressIndicator] with
/// the brand's indigo→cyan gradient fill on a recessed track.
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.trackColor,
    this.color,
  });

  /// 0.0–1.0; clamped so a caller can never overflow.
  final double value;

  final double height;
  final Color? trackColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final from = color ?? (isDark ? AppColors.darkAccent : AppColors.lightAccent);
    final to = isDark ? AppColors.darkCyan : AppColors.lightCyan;
    final track = trackColor ??
        (isDark
            ? AppColors.darkProgressTrack
            : AppColors.lightSecondarySurface);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              ColoredBox(color: track, child: const SizedBox.expand()),
              FractionallySizedBox(
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [from, to]),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge component for Priority, Due date, Growth area, or Status.
class GrivioBadge extends StatelessWidget {
  const GrivioBadge({
    super.key,
    required this.label,
    this.icon,
    this.isAccent = false,
    this.isError = false,
    this.isWarning = false,
    this.isSuccess = false,
  });

  final String label;
  final IconData? icon;
  final bool isAccent;
  final bool isError;
  final bool isWarning;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;

    if (isError) {
      bg = (isDark ? AppColors.darkError : AppColors.lightError).withValues(
        alpha: 0.12,
      );
      fg = isDark ? AppColors.darkError : AppColors.lightError;
    } else if (isWarning) {
      bg = (isDark ? AppColors.darkWarning : AppColors.lightWarning).withValues(
        alpha: 0.12,
      );
      fg = isDark ? AppColors.darkWarning : AppColors.lightWarning;
    } else if (isSuccess) {
      bg = (isDark ? AppColors.darkSuccess : AppColors.lightSuccess).withValues(
        alpha: 0.12,
      );
      fg = isDark ? AppColors.darkSuccess : AppColors.lightSuccess;
    } else if (isAccent) {
      bg = (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(
        alpha: 0.12,
      );
      fg = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    } else {
      bg = isDark
          ? AppColors.darkSecondarySurface
          : AppColors.lightSecondarySurface;
      fg = isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
