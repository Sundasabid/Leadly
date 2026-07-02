import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    _redirect();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      context.go('/auth/login');
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', session.user.id)
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

    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Logo
              const Text(
                'LEADLY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'AI-Powered Real Estate CRM\nfor Pakistani Agents',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),

              const Spacer(flex: 2),

              // City skyline illustration (placeholder)
              _CityIllustration(),

              const Spacer(flex: 2),

              // Spinner
              const SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Loading your workspace...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  letterSpacing: 0.3,
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Stylized Pakistani city skyline using shapes
    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Background glow
          Container(
            width: 320,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          // Buildings row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Building(width: 28, height: 60, opacity: 0.25),
              const SizedBox(width: 4),
              _Building(width: 22, height: 45, opacity: 0.2),
              const SizedBox(width: 4),
              // Minar-e-Pakistan style tower
              _Tower(opacity: 0.35),
              const SizedBox(width: 4),
              _Building(width: 36, height: 80, opacity: 0.3, hasDome: true),
              const SizedBox(width: 4),
              _Building(width: 24, height: 55, opacity: 0.22),
              const SizedBox(width: 4),
              _Building(width: 32, height: 70, opacity: 0.28),
              const SizedBox(width: 4),
              _Building(width: 20, height: 40, opacity: 0.18),
            ],
          ),
        ],
      ),
    );
  }
}

class _Building extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;
  final bool hasDome;

  const _Building({
    required this.width,
    required this.height,
    required this.opacity,
    this.hasDome = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasDome)
          Container(
            width: width * 0.7,
            height: width * 0.4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: BorderRadius.vertical(top: Radius.circular(width)),
            ),
          ),
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ],
    );
  }
}

class _Tower extends StatelessWidget {
  final double opacity;
  const _Tower({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Spire
        Container(
          width: 4,
          height: 30,
          color: Colors.white.withValues(alpha: opacity),
        ),
        // Top platform
        Container(
          width: 20,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Neck
        Container(
          width: 8,
          height: 20,
          color: Colors.white.withValues(alpha: opacity),
        ),
        // Base
        Container(
          width: 30,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ),
      ],
    );
  }
}
