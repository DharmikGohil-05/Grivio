import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/neumorphic.dart';
import '../widgets/ui_kit.dart';
import 'register_screen.dart';

/// Login screen — soft ambient brand hero over a tactile neumorphic form
/// card. Every element eases in with a staggered entrance.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});
  final VoidCallback onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.login(email: _email.text.trim(), password: _password.text);
      widget.onLoggedIn();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error = 'Could not reach the server. Check your connection.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // ── Brand hero ───────────────────────────────────────
                      StaggeredIn(
                        child: Column(
                          children: [
                            const NeumorphicIconCircle(
                              icon: Icons.trending_up_rounded,
                              size: 84,
                              iconSize: 38,
                              isAccent: true,
                            ),
                            const SizedBox(height: 20),
                            const GrivioWordmark(fontSize: 26),
                            const SizedBox(height: 12),
                            Text(
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pick up right where you left off.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Tactile form card ────────────────────────────────
                      StaggeredIn(
                        delay: const Duration(milliseconds: 120),
                        child: Neumorphic(
                          borderRadius: 24,
                          depth: 8,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(
                                    Icons.mail_outline,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _password,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _login(),
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    size: 20,
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                ErrorPill(message: _error!),
                              ],
                              const SizedBox(height: 24),
                              NeumorphicButton(
                                isAccent: true,
                                width: double.infinity,
                                onPressed: _loading ? null : _login,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                child: _loading
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text('Signing in...'),
                                        ],
                                      )
                                    : const Text('Sign in'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Create account link ──────────────────────────────
                      StaggeredIn(
                        delay: const Duration(milliseconds: 240),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  RegisterScreen(onRegistered: widget.onLoggedIn),
                            ),
                          ),
                          child: const Text("Don't have an account? Create one"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
