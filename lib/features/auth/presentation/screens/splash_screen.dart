import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A8A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-screen city image ─────────────────────────────────────
            Image.asset(
              'assets/images/splash_city.png',
              fit: BoxFit.cover,
            ),

            // ── Navy overlay so white text stays readable ──────────────────
            Container(
              color: const Color(0xFF1B3A8A).withValues(alpha: 0.55),
            ),

            // ── Branding + spinner centred on screen ───────────────────────
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'PROPEX',
                  style: GoogleFonts.poppins(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'AI-Powered Real Estate CRM',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: 60,
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.20),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
