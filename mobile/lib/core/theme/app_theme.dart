import 'package:flutter/material.dart';

// =============================================================================
// GRIVIO DESIGN SYSTEM — CENTRALIZED THEME
//
// Color balance: 85–90% neutral surfaces, 10–15% accent.
// Tactile, restrained, modern neumorphism with cohesive light & dark modes.
// =============================================================================

// -----------------------------------------------------------------------------
// DESIGN TOKENS — Brand palette
// -----------------------------------------------------------------------------

/// All brand colors, defined as paired Light/Dark tokens (lightXxx ↔ darkXxx).
///
/// The palette enforces the 85–90% neutral / 10–15% accent split: the
/// background/surface/text tokens fill nearly every pixel with calm
/// neutrals, while the accent is spent only on interactive focal points
/// (buttons, selected tabs, progress) so it always reads as "act here".
class AppColors {
  AppColors._();

  // ── Light Theme ────────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF4F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSecondarySurface = Color(0xFFEDF1F4);
  static const Color lightElevatedSurface = Color(0xFFF8FAFB);
  static const Color lightBorder = Color(0xFFE0E6EA);
  static const Color lightHighlight = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE0E6EA);

  static const Color lightPrimaryText = Color(0xFF18232D);
  static const Color lightSecondaryText = Color(0xFF596875);
  static const Color lightMutedText = Color(0xFF87939D);

  static const Color lightAccent = Color(0xFF287D76);
  static const Color lightAccentPressed = Color(0xFF20665F);
  static const Color lightAccentSurface = Color(0xFFE3F1EF);

  static const Color lightSuccess = Color(0xFF3F806A);
  static const Color lightWarning = Color(0xFFA87535);
  static const Color lightError = Color(0xFFB8545D);

  // Subtle Neumorphic shadows for light mode.
  // The dark+light pair fakes a single light source: a bright edge on the
  // lit side and a dark edge on the shaded side — together they create
  // neumorphism's soft "raised from the surface" illusion.
  static const Color lightShadowDark = Color(0xFFCDD5DC);
  static const Color lightShadowLight = Color(0xFFFFFFFF);

  // ── Dark Theme ─────────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF10151B);
  static const Color darkSurface = Color(0xFF171E26);
  static const Color darkSecondarySurface = Color(0xFF1C252F);
  static const Color darkElevatedSurface = Color(0xFF222D38);
  static const Color darkBorder = Color(0xFF2B3743);
  static const Color darkDivider = Color(0xFF232D37);

  static const Color darkPrimaryText = Color(0xFFF2F5F7);
  static const Color darkSecondaryText = Color(0xFFB1BCC6);
  static const Color darkMutedText = Color(0xFF7F8D99);

  static const Color darkAccent = Color(0xFF59B5A9);
  static const Color darkAccentPressed = Color(0xFF41978C);
  static const Color darkAccentSurface = Color(0xFF203A38);

  static const Color darkSuccess = Color(0xFF68AE91);
  static const Color darkWarning = Color(0xFFD0A367);
  static const Color darkError = Color(0xFFDE7C84);
  static const Color darkProgressTrack = Color(0xFF2B3741);

  // Subtle Neumorphic shadows for dark mode
  static const Color darkShadowDark = Color(0xFF080C10);
  static const Color darkShadowLight = Color(0xFF1E2A36);
}

// -----------------------------------------------------------------------------
// SPACING TOKENS — 4 pt grid
// -----------------------------------------------------------------------------

/// Named spacing steps, all multiples of 4. Using these instead of magic
/// numbers keeps the vertical rhythm identical across every screen.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const double pagePadding = 20;
}

// -----------------------------------------------------------------------------
// RADIUS TOKENS
// -----------------------------------------------------------------------------

/// Corner-radius steps shared by cards, inputs and buttons.
/// `pill` (100) is far wider than any chip or badge, so it always renders
/// as a fully rounded capsule.
class AppRadius {
  AppRadius._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 100;
}

// -----------------------------------------------------------------------------
// TEXT THEME — Inter type scale
// -----------------------------------------------------------------------------

/// Derives the Inter type scale by *copying* the platform's default text
/// theme, so every standard Material size and line-height is preserved and
/// only font family, weight, letter-spacing and color change. Headings and
/// body use `primary`; the small caption style (bodySmall) steps down to
/// `secondary`.
TextTheme _buildTextTheme(TextTheme base, Color primary, Color secondary) {
  return base.copyWith(
    displayMedium: base.displayMedium?.copyWith(
      fontFamily: 'Inter',
      color: primary,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
    ),
    displaySmall: base.displaySmall?.copyWith(
      fontFamily: 'Inter',
      color: primary,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontFamily: 'Inter',
      color: primary,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontFamily: 'Inter',
      color: primary,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontFamily: 'Inter',
      color: primary,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontFamily: 'Inter',
      color: primary,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontFamily: 'Inter',
      color: primary,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontFamily: 'Inter',
      color: primary,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontFamily: 'Inter',
      color: primary,
      height: 1.5,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontFamily: 'Inter',
      color: primary,
      height: 1.5,
    ),
    bodySmall: base.bodySmall?.copyWith(
      fontFamily: 'Inter',
      color: secondary,
      height: 1.4,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
    ),
  );
}

// -----------------------------------------------------------------------------
// SHARED — subtle Material page transitions (fade + gentle slide up)
// -----------------------------------------------------------------------------
// iOS keeps CupertinoPageTransitionsBuilder so navigation matches the
// platform's native swipe/slide feel; every other platform uses the same
// FadeUpwards builder for one consistent fade-and-rise across the app.
const PageTransitionsTheme _grivioPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
  },
);

// -----------------------------------------------------------------------------
// LIGHT THEME
// -----------------------------------------------------------------------------

/// Light variant of the design system, consumed by MaterialApp.theme in
/// main.dart. Its tokens pair 1:1 with buildDarkTheme, so switching modes
/// only swaps colors — layouts never shift.
ThemeData buildLightTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.lightAccent,
    onPrimary: Colors.white,
    primaryContainer: AppColors.lightAccentSurface,
    onPrimaryContainer: AppColors.lightAccentPressed,
    secondary: AppColors.lightAccent,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.lightAccentSurface,
    onSecondaryContainer: AppColors.lightPrimaryText,
    tertiary: AppColors.lightWarning,
    onTertiary: Colors.white,
    error: AppColors.lightError,
    onError: Colors.white,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightPrimaryText,
    surfaceContainerHighest: AppColors.lightSecondarySurface,
    outline: AppColors.lightBorder,
    outlineVariant: AppColors.lightBorder,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.lightBackground,
    dividerColor: AppColors.lightDivider,
    pageTransitionsTheme: _grivioPageTransitions,

    // Cursor and selection handles use the accent color instead of
    // Material's default blue, so text editing matches the rest of the UI.
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.lightAccent,
      selectionColor: AppColors.lightAccent.withValues(alpha: 0.18),
      selectionHandleColor: AppColors.lightAccent,
    ),

    textTheme: _buildTextTheme(
      ThemeData.light().textTheme,
      AppColors.lightPrimaryText,
      AppColors.lightSecondaryText,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.lightPrimaryText,
      // Material 3 tints elevated surfaces with the primary color; making it
      // transparent keeps GRIVIO's flat neumorphic surfaces unpolluted.
      // (The same is applied to the nav bar and bottom sheets below.)
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.lightPrimaryText,
        letterSpacing: -0.1,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.lightAccentSurface,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.lightAccent, size: 22);
        }
        return const IconThemeData(color: AppColors.lightMutedText, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.lightAccent,
          );
        }
        return const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.lightMutedText,
        );
      }),
      elevation: 0,
      height: 64,
    ),

    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.lightAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.lightError),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.lightError, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        color: AppColors.lightSecondaryText,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Inter',
        color: AppColors.lightMutedText,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lightAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.lightAccent,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        side: const BorderSide(color: AppColors.lightBorder, width: 1.2),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.lightAccent,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightSecondarySurface,
      selectedColor: AppColors.lightAccentSurface,
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.lightPrimaryText,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.lightAccent,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: const BorderSide(color: AppColors.lightBorder, width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.lightAccent,
      foregroundColor: Colors.white,
      elevation: 2,
      extendedTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.lightDivider,
      thickness: 1,
      space: 1,
    ),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      fillColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return AppColors.lightAccent;
        return Colors.transparent;
      }),
      side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.lightPrimaryText,
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        color: Colors.white,
        fontSize: 14,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lightSurface,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.lightPrimaryText,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: AppColors.lightSecondaryText,
        height: 1.5,
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: 2,
      ),
      minLeadingWidth: 24,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lightAccent,
      linearTrackColor: AppColors.lightSecondarySurface,
      circularTrackColor: AppColors.lightSecondarySurface,
    ),
  );
}

// -----------------------------------------------------------------------------
// DARK THEME
// -----------------------------------------------------------------------------

/// Dark variant, consumed by MaterialApp.darkTheme. The dark tokens are not
/// simple inversions of the light ones: the accent is lightened for
/// contrast on dark surfaces, the neumorphic shadow pair switches to deep
/// blues, and the text-selection overlay is slightly stronger (0.22 vs
/// 0.18) to stay visible on dark backgrounds.
ThemeData buildDarkTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.darkAccent,
    onPrimary: AppColors.darkBackground,
    primaryContainer: AppColors.darkAccentSurface,
    onPrimaryContainer: AppColors.darkAccent,
    secondary: AppColors.darkAccent,
    onSecondary: AppColors.darkBackground,
    secondaryContainer: AppColors.darkAccentSurface,
    onSecondaryContainer: AppColors.darkPrimaryText,
    tertiary: AppColors.darkWarning,
    onTertiary: AppColors.darkBackground,
    error: AppColors.darkError,
    onError: Colors.white,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkPrimaryText,
    surfaceContainerHighest: AppColors.darkSecondarySurface,
    outline: AppColors.darkBorder,
    outlineVariant: AppColors.darkBorder,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.darkBackground,
    dividerColor: AppColors.darkDivider,
    pageTransitionsTheme: _grivioPageTransitions,

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.darkAccent,
      selectionColor: AppColors.darkAccent.withValues(alpha: 0.22),
      selectionHandleColor: AppColors.darkAccent,
    ),

    textTheme: _buildTextTheme(
      ThemeData.dark().textTheme,
      AppColors.darkPrimaryText,
      AppColors.darkSecondaryText,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkPrimaryText,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkPrimaryText,
        letterSpacing: -0.1,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.darkAccentSurface,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.darkAccent, size: 22);
        }
        return const IconThemeData(color: AppColors.darkMutedText, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.darkAccent,
          );
        }
        return const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.darkMutedText,
        );
      }),
      elevation: 0,
      height: 64,
    ),

    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSecondarySurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.darkAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.darkError),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.darkError, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        color: AppColors.darkSecondaryText,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Inter',
        color: AppColors.darkMutedText,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.darkAccent,
        foregroundColor: AppColors.darkBackground,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkAccent,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        side: const BorderSide(color: AppColors.darkBorder, width: 1.2),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.darkAccent,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSecondarySurface,
      selectedColor: AppColors.darkAccentSurface,
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.darkPrimaryText,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.darkAccent,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: const BorderSide(color: AppColors.darkBorder, width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkAccent,
      foregroundColor: AppColors.darkBackground,
      elevation: 2,
      extendedTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 1,
      space: 1,
    ),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      fillColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return AppColors.darkAccent;
        return Colors.transparent;
      }),
      side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkElevatedSurface,
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        color: AppColors.darkPrimaryText,
        fontSize: 14,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSecondarySurface,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkPrimaryText,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: AppColors.darkSecondaryText,
        height: 1.5,
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: 2,
      ),
      minLeadingWidth: 24,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.darkAccent,
      linearTrackColor: AppColors.darkProgressTrack,
      circularTrackColor: AppColors.darkProgressTrack,
    ),
  );
}
