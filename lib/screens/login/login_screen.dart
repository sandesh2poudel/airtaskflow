// lib/screens/login/login_screen.dart
// UI: Modern glassmorphism — matches HRMS design language (glass cards,
//     gradient accents, backdrop blur, decorative blobs, slide-in animation)
// ZERO functional changes — only UI/UX upgraded.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _C {
  // Re-uses AppColors so dark/light mode still works; these are light-mode
  // overrides for elements drawn directly (blobs, glass tint, etc.)
  static const Color accent  = AppColors.accent;
  static const Color accent2 = AppColors.accent2;
  static const Color border  = Color(0x33000000); // overridden per theme below
}

// ── Screen ────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ── Controllers (unchanged) ───────────────────────────────────────────────
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // ── NEW: slide-in (matches HRMS) ──────────────────────────────────────────
  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    // Shake (unchanged)
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

    // Fade (unchanged)
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Slide-in (new – mirrors HRMS)
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.09),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _shakeCtrl.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Login logic (unchanged) ───────────────────────────────────────────────
  Future<void> _doLogin() async {
    final auth = context.read<AuthProvider>();
    final success =
    await auth.login(_usernameCtrl.text, _passwordCtrl.text);
    if (!success && mounted) {
      _shakeCtrl.forward(from: 0);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
            colors: [
              Color(0xFF0D0F14),
              Color(0xFF0F1219),
              Color(0xFF111520),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : const LinearGradient(
            colors: [
              Color(0xFFEEF2FF),
              Color(0xFFF0F9FF),
              Color(0xFFFAFAFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // ── Decorative blobs (mirrors HRMS) ───────────────
            Positioned(
              top: -90,
              right: -70,
              child: _Blob(
                size: 300,
                color: AppColors.accent.withOpacity(isDark ? 0.10 : 0.08),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -90,
              child: _Blob(
                size: 260,
                color: AppColors.accent2.withOpacity(isDark ? 0.08 : 0.07),
              ),
            ),
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.40,
              left: -50,
              child: _Blob(
                size: 180,
                color: AppColors.accent.withOpacity(isDark ? 0.06 : 0.05),
              ),
            ),
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.15,
              right: 60,
              child: _Blob(
                size: 90,
                color: AppColors.accent2.withOpacity(isDark ? 0.07 : 0.06),
              ),
            ),

            // ── Main content ───────────────────────────────────
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (context, child) {
                          final dx = _shakeCtrl.isAnimating
                              ? (8 *
                              (0.5 - _shakeAnim.value).abs() *
                              2 -
                              4) *
                              2
                              : 0.0;
                          return Transform.translate(
                              offset: Offset(dx, 0), child: child);
                        },
                        child: ConstrainedBox(
                          constraints:
                          const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                            children: [
                              // ── Brand header ─────────────
                              _BrandHeader(isDark: isDark),

                              const SizedBox(height: 32),

                              // ── Glass card ────────────────
                              _GlassCard(
                                isDark: isDark,
                                child: Column(
                                  children: [
                                    // Gradient header strip
                                    _CardHeader(),

                                    // Form body
                                    Padding(
                                      padding:
                                      const EdgeInsets.fromLTRB(
                                          24, 24, 24, 28),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                        children: [
                                          // Username
                                          _FieldLabel(
                                              'Username',
                                              isDark: isDark),
                                          const SizedBox(height: 6),
                                          _GlassTextField(
                                            controller: _usernameCtrl,
                                            hint: 'Enter username',
                                            icon: Icons.person_outline,
                                            isDark: isDark,
                                            onSubmitted: (_) =>
                                                _doLogin(),
                                          ),

                                          const SizedBox(height: 16),

                                          // Password
                                          _FieldLabel(
                                              'Password',
                                              isDark: isDark),
                                          const SizedBox(height: 6),
                                          _GlassTextField(
                                            controller: _passwordCtrl,
                                            hint: '••••••••',
                                            icon:
                                            Icons.lock_outline_rounded,
                                            isDark: isDark,
                                            obscure: _obscurePassword,
                                            onToggleObscure: () =>
                                                setState(() =>
                                                _obscurePassword =
                                                !_obscurePassword),
                                            onSubmitted: (_) =>
                                                _doLogin(),
                                          ),

                                          const SizedBox(height: 20),

                                          // Error banner
                                          Consumer<AuthProvider>(
                                            builder:
                                                (context, auth, _) {
                                              if (auth.state !=
                                                  AuthState.error ||
                                                  auth.errorMessage
                                                      .isEmpty) {
                                                return const SizedBox
                                                    .shrink();
                                              }
                                              return Padding(
                                                padding:
                                                const EdgeInsets
                                                    .only(
                                                    bottom: 16),
                                                child: _ErrorBanner(
                                                    message: auth
                                                        .errorMessage),
                                              );
                                            },
                                          ),

                                          // Sign In button
                                          Consumer<AuthProvider>(
                                            builder:
                                                (context, auth, _) {
                                              final isLoading =
                                                  auth.state ==
                                                      AuthState.loading;
                                              return _SignInButton(
                                                loading: isLoading,
                                                onTap: isLoading
                                                    ? null
                                                    : _doLogin,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Footer note ──────────────
                              _FooterNote(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Sub-widgets ───────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

// ── Decorative blob ───────────────────────────────────────────────────────────
class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ── Brand header ──────────────────────────────────────────────────────────────
class _BrandHeader extends StatelessWidget {
  final bool isDark;
  const _BrandHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo image instead of ATF box
        Image.asset(
          'assets/images/logo.png',
          width:300,
          height: 80,
          fit: BoxFit.contain,
        ),
        Text(
          'Sign in to your workspace',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: isDark ? AppColors.darkText2 : AppColors.lightText2,
          ),
        ),
      ],
    );
  }
}

// ── Glass card wrapper ────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _GlassCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF151820).withOpacity(0.82)
                : Colors.white.withOpacity(0.80),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.white.withOpacity(0.85),
              width: 1.2,
            ),
            boxShadow: isDark
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.accent.withOpacity(0.04),
                blurRadius: 40,
              ),
            ]
                : [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.08),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Card gradient header strip ────────────────────────────────────────────────
class _CardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.accent2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.login_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Sign in to continue',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _FieldLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkText2 : AppColors.lightText2,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Glass text field ──────────────────────────────────────────────────────────
class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isDark;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final ValueChanged<String>? onSubmitted;

  const _GlassTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.obscure = false,
    this.onToggleObscure,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final fieldBg = isDark
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFF8FAFF);
    final fieldBorder = isDark
        ? Colors.white.withOpacity(0.10)
        : const Color(0xFFE2E8F0);

    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: isDark ? AppColors.darkText : AppColors.lightText,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? AppColors.darkText3 : AppColors.lightText3,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon,
            color: AppColors.accent, size: 18),
        suffixIcon: onToggleObscure != null
            ? GestureDetector(
          onTap: onToggleObscure,
          child: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: isDark
                ? AppColors.darkText3
                : AppColors.lightText3,
            size: 18,
          ),
        )
            : null,
        filled: true,
        fillColor: fieldBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sign-in button (hover glow — mirrors HRMS) ────────────────────────────────
class _SignInButton extends StatefulWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _SignInButton({required this.loading, required this.onTap});

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          opacity: widget.loading ? 0.75 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accent2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent
                      .withOpacity(_hovered ? 0.45 : 0.28),
                  blurRadius: _hovered ? 24 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.login_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ── Footer note ───────────────────────────────────────────────────────────────
class _FooterNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.info_outline_rounded,
              size: 13, color: AppColors.accent),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Copyright © 2026– 2030 Air Task FLow',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkText2 : AppColors.lightText2,
            ),
          ),
        ),
      ],
    );
  }
}