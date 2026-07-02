import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

enum _AuthMode { login, signup }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _AuthMode _mode = _AuthMode.login;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _emailConfirmationSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final redirectTo = kIsWeb
          ? '${Uri.base.origin}/'
          : 'com.leadly.leadly://login-callback';

      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      // Redirect happens — session is picked up on return via deep link
      if (mounted) setState(() => _loading = false);
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _friendlyAuthError(e);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyNetworkError(e);
        _loading = false;
      });
    }
  }

  Future<void> _submitEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      if (_mode == _AuthMode.login) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        if (!mounted) return;
        await _navigateAfterLogin();
      } else {
        final res = await Supabase.instance.client.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        if (!mounted) return;
        if (res.session != null) {
          await _navigateAfterLogin();
        } else {
          // Email confirmation required
          setState(() {
            _emailConfirmationSent = true;
            _loading = false;
          });
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _friendlyAuthError(e);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyNetworkError(e);
        _loading = false;
      });
    }
  }

  Future<void> _navigateAfterLogin() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted) return;
      context.go(profile == null ? '/onboarding' : '/dashboard');
    } on PostgrestException {
      if (!mounted) return;
      context.go('/onboarding');
    } catch (_) {
      if (!mounted) return;
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLogin = _mode == _AuthMode.login;

    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: _emailConfirmationSent
            ? _EmailConfirmationView(
                email: _emailCtrl.text.trim(),
                onBack: () => setState(() {
                  _emailConfirmationSent = false;
                  _mode = _AuthMode.login;
                }),
              )
            : Stack(
                children: [
                  // — Blue top header —
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: size.height * 0.30,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A56DB), Color(0xFF1E40AF)],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'LEADLY',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'AI-Powered Real Estate CRM',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // — White form card —
                  Positioned(
                    top: size.height * 0.25,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Welcome heading
                            Text(
                              isLogin ? 'Welcome back' : 'Create account',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLogin
                                  ? 'Log in to manage your leads'
                                  : 'Start closing more deals today',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 24),

                            // Mode toggle
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  _ModeTab(
                                    label: 'Log In',
                                    selected: isLogin,
                                    onTap: () => setState(() {
                                      _mode = _AuthMode.login;
                                      _errorMessage = null;
                                    }),
                                  ),
                                  _ModeTab(
                                    label: 'Sign Up',
                                    selected: !isLogin,
                                    onTap: () => setState(() {
                                      _mode = _AuthMode.signup;
                                      _errorMessage = null;
                                    }),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Google button
                            OutlinedButton(
                              onPressed: _loading ? null : _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 52),
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                foregroundColor: const Color(0xFF111827),
                                backgroundColor: Colors.white,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Coloured G
                                  const Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'G',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF4285F4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // OR divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.shade200,
                                    thickness: 1.5,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'or',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.shade200,
                                    thickness: 1.5,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Error banner
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 18,
                                      color: Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Form
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Email'),
                                  const SizedBox(height: 6),
                                  _StyledField(
                                    controller: _emailCtrl,
                                    hint: 'agent@example.com',
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty)
                                        return 'Email is required';
                                      if (!RegExp(
                                        r'^[^@]+@[^@]+\.[^@]+',
                                      ).hasMatch(v.trim())) {
                                        return 'Enter a valid email address';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  _FieldLabel('Password'),
                                  const SizedBox(height: 6),
                                  _StyledField(
                                    controller: _passwordCtrl,
                                    hint: '••••••••',
                                    obscure: _obscurePassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: const Color(0xFF9CA3AF),
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty)
                                        return 'Password is required';
                                      if (v.length < 8)
                                        return 'Minimum 8 characters';
                                      return null;
                                    },
                                  ),

                                  if (!isLogin) ...[
                                    const SizedBox(height: 16),
                                    _FieldLabel('Confirm Password'),
                                    const SizedBox(height: 6),
                                    _StyledField(
                                      controller: _confirmCtrl,
                                      hint: '••••••••',
                                      obscure: _obscureConfirm,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirm
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 20,
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                        onPressed: () => setState(
                                          () => _obscureConfirm =
                                              !_obscureConfirm,
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty)
                                          return 'Please confirm your password';
                                        if (v != _passwordCtrl.text)
                                          return 'Passwords do not match';
                                        return null;
                                      },
                                    ),
                                  ],

                                  if (isLogin) ...[
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => context.pushNamed(
                                          'forgot-password',
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          foregroundColor:
                                              AppColors.primaryLight,
                                        ),
                                        child: const Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Submit button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading
                                    ? null
                                    : _submitEmailPassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        isLogin ? 'Log In' : 'Create Account',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            Text.rich(
                              TextSpan(
                                text: 'By continuing, you agree to our ',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: const TextStyle(
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {},
                                  ),
                                  const TextSpan(text: ' & '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {},
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
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

// ── Auth error helpers ────────────────────────────────────────────────────────

String _friendlyAuthError(AuthException e) {
  final msg = e.message.toLowerCase();

  if (msg.contains('already registered') || msg.contains('already exists')) {
    return 'An account with this email already exists. Try logging in instead.';
  }
  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid email or password') ||
      msg.contains('wrong password')) {
    return 'Incorrect email or password. Please check and try again.';
  }
  if (msg.contains('email not confirmed')) {
    return 'Your email is not verified yet. Check your inbox for the confirmation link.';
  }
  if (msg.contains('rate limit') ||
      msg.contains('too many requests') ||
      e.statusCode == '429') {
    return 'Too many attempts. Please wait a few minutes and try again.';
  }
  if (msg.contains('weak password') ||
      (msg.contains('password') && msg.contains('characters'))) {
    return 'Password must be at least 8 characters long.';
  }
  if (msg.contains('valid email') || msg.contains('email format')) {
    return 'Please enter a valid email address.';
  }
  if (msg.contains('signup disabled') || msg.contains('signups not allowed')) {
    return 'New sign-ups are currently unavailable. Please try again later.';
  }
  if (msg.contains('expired') || msg.contains('otp') || msg.contains('token')) {
    return 'This link has expired. Please request a new one.';
  }
  if (msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('connection')) {
    return 'No internet connection. Please check your network and try again.';
  }

  // Fallback: show the raw message but ensure it ends with a period
  final clean = e.message.trim();
  return clean.endsWith('.') ? clean : '$clean.';
}

String _friendlyNetworkError(Object e) {
  final str = e.toString().toLowerCase();
  if (str.contains('socket') ||
      str.contains('network') ||
      str.contains('failed host lookup') ||
      str.contains('connection refused') ||
      str.contains('no address associated')) {
    return 'No internet connection. Please check your network and try again.';
  }
  return 'Something went wrong. Please try again.';
}

// ── Email Confirmation Screen ─────────────────────────────────────────────────

class _EmailConfirmationView extends StatelessWidget {
  final String email;
  final VoidCallback onBack;
  const _EmailConfirmationView({required this.email, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 40,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Check your email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a confirmation link to\n$email\n\nClick the link to activate your account.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onBack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Back to Log In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryLight.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 15),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
      ),
    );
  }
}
