import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';

// =============================================================================
// GRIVIO NEUMORPHIC & UI SYSTEM
//
// Tactile, calm, and subtle surface depth system.
// Adapts automatically to Light, Dark, and System modes.
// =============================================================================

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
    final effectiveStyle =
        style ?? (inset ? NeumorphicStyle.inset : NeumorphicStyle.raised);

    final baseColor =
        color ?? (isDark ? AppColors.darkSurface : AppColors.lightSurface);

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

/// Circular Progress Ring with subtle neumorphic track.
class GrivioProgressRing extends StatelessWidget {
  const GrivioProgressRing({
    super.key,
    required this.progress,
    required this.centerText,
    this.subtitleText,
    this.size = 140,
    this.strokeWidth = 9,
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

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Recessed track background
          Container(
            width: size - 4,
            height: size - 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? AppColors.darkSecondarySurface.withValues(alpha: 0.5)
                  : AppColors.lightSecondarySurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: isDark
                  ? AppColors.darkProgressTrack
                  : AppColors.lightSecondarySurface,
              color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
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
    );
  }
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
