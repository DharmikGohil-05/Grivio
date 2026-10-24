import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../widgets/neumorphic.dart';
import '../widgets/ui_kit.dart';

/// GRIVIO splash — a calm brand moment while the app resolves auth state.
///
/// Purely presentational: it never navigates. `main.dart` shows this screen
/// while the login token + profile are being resolved, and holds it for a
/// minimum brand duration so it always feels intentional.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    // Small delay lets the first frame paint before the entrance animates.
    Future<void>.delayed(const Duration(milliseconds: 60), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(intensity: 1.3),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // ── Hero mark with pulsing rings ───────────────────────
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_showContent) ...[
                            const PulseRing(size: 200),
                            const PulseRing(
                              size: 200,
                              delay: Duration(milliseconds: 800),
                            ),
                          ],
                          AnimatedScale(
                            scale: _showContent ? 1.0 : 0.86,
                            curve: Curves.easeOutBack,
                            duration: const Duration(milliseconds: 700),
                            child: AnimatedOpacity(
                              opacity: _showContent ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 500),
                              child: Neumorphic(
                                borderRadius: 56,
                                depth: 10,
                                padding: const EdgeInsets.all(24),
                                child: const GrivioLogo(
                                  size: 96,
                                  borderRadius: 34,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Wordmark + tagline ─────────────────────────────────
                    StaggeredIn(
                      delay: const Duration(milliseconds: 240),
                      child: Column(
                        children: [
                          const GrivioWordmark(fontSize: 30),
                          const SizedBox(height: 12),
                          Text(
                            'Grow with intention',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppColors.darkSecondaryText
                                  : AppColors.lightSecondaryText,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 3),

                    // ── Loading dots ───────────────────────────────────────
                    StaggeredIn(
                      delay: const Duration(milliseconds: 500),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkMutedText
                              : AppColors.lightMutedText,
                        ),
                        child: const LoadingDots(),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
