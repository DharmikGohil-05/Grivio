import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/neumorphic.dart';
import '../widgets/ui_kit.dart';

/// Registration screen — same tactile language as Login: brand hero,
/// neumorphic form card, staggered entrance, friendly validation.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onRegistered});
  final VoidCallback onRegistered;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pop();
      widget.onRegistered();
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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Back affordance ──────────────────────────────────
                      StaggeredIn(
                        offset: const Offset(-0.04, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: NeumorphicButton(
                            padding: const EdgeInsets.all(10),
                            borderRadius: 14,
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Icon(Icons.arrow_back_rounded, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Brand hero ───────────────────────────────────────
                      StaggeredIn(
                        delay: const Duration(milliseconds: 100),
                        child: Column(
                          children: [
                            const NeumorphicIconCircle(
                              icon: Icons.rocket_launch_rounded,
                              size: 76,
                              iconSize: 34,
                              isAccent: true,
                            ),
                            const SizedBox(height: 18),
                            const GrivioWordmark(fontSize: 22),
                            const SizedBox(height: 12),
                            Text(
                              'Start your growth journey',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Small steps, compounded daily.',
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

                      const SizedBox(height: 28),

                      // ── Tactile form card ────────────────────────────────
                      StaggeredIn(
                        delay: const Duration(milliseconds: 200),
                        child: Neumorphic(
                          borderRadius: 24,
                          depth: 8,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _name,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
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
                                onSubmitted: (_) => _register(),
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'At least 6 characters',
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
                                onPressed: _loading ? null : _register,
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
                                          Text('Creating account...'),
                                        ],
                                      )
                                    : const Text('Create Account'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
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
