import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/profile_state_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/leads/presentation/screens/leads_list_screen.dart';
import '../../features/leads/presentation/screens/lead_detail_screen.dart';
import '../../features/add_lead/presentation/screens/add_lead_method_screen.dart';
import '../../features/add_lead/presentation/screens/manual_entry_screen.dart';
import '../../features/add_lead/presentation/screens/voice_recording_screen.dart';
import '../../features/add_lead/presentation/screens/review_extracted_lead_screen.dart';
import '../../features/add_lead/presentation/screens/duplicate_warning_screen.dart';
import '../../features/leads/domain/models/lead_model.dart';
import '../../features/leads/presentation/screens/edit_lead_screen.dart';
import '../../features/follow_ups/presentation/screens/follow_ups_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/insights/presentation/screens/weekly_insights_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/account_info_screen.dart';
import '../../features/settings/presentation/screens/security_screen.dart';
import '../../features/settings/presentation/screens/privacy_data_screen.dart';
import '../../features/settings/presentation/screens/notification_preferences_screen.dart';
import '../../features/settings/presentation/screens/reminders_screen.dart';
import '../../features/settings/presentation/screens/help_support_screen.dart';
import '../navigation/app_shell.dart';
import 'route_names.dart';

// ── Router notifier ────────────────────────────────────────────────────────────

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (previous, next) => notifyListeners());
    _ref.listen(profileExistsProvider, (previous, next) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;

    // Splash manages its own routing after the animation — never intercept it.
    if (location == '/') return null;

    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final isOnAuth = location.startsWith('/auth/');
    final isOnOnboarding = location == '/onboarding';

    if (!isLoggedIn && !isOnAuth) return '/auth/login';

    if (isLoggedIn) {
      final profileAsync = _ref.read(profileExistsProvider);
      if (profileAsync.isLoading) return null;

      final hasProfile = profileAsync.value ?? false;

      if (isOnAuth) return hasProfile ? '/dashboard' : '/onboarding';
      if (isOnOnboarding && hasProfile) return '/dashboard';
      if (!isOnOnboarding && !hasProfile) return '/onboarding';
    }

    return null;
  }
}

// ── Router provider ────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Outside shell (no bottom nav) ──────────────────────────────────────
      GoRoute(
        path: '/',
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        name: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Add Lead sub-screens — full screen, outside shell (nav bar hidden)
      GoRoute(
        path: '/add-lead/manual',
        name: RouteNames.addLeadManual,
        builder: (context, state) => const ManualEntryScreen(),
      ),
      GoRoute(
        path: '/add-lead/voice',
        name: RouteNames.addLeadVoice,
        builder: (context, state) => const VoiceRecordingScreen(),
      ),
      GoRoute(
        path: '/add-lead/review',
        name: RouteNames.addLeadReview,
        builder: (context, state) => const ReviewExtractedLeadScreen(),
      ),
      GoRoute(
        path: '/add-lead/duplicate-warning',
        name: RouteNames.addLeadDuplicateWarning,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          opaque: false,
          barrierColor: Colors.black54,
          barrierDismissible: false,
          child: const DuplicateWarningScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
        ),
      ),
      // Lead detail — slides up from bottom, outside shell
      GoRoute(
        path: '/leads/:id',
        name: RouteNames.leadDetail,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: LeadDetailScreen(leadId: state.pathParameters['id']!),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) =>
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
        ),
        routes: [
          GoRoute(
            path: 'edit',
            name: RouteNames.leadEdit,
            builder: (context, state) {
              final lead = state.extra as LeadModel?;
              if (lead == null) {
                return const Scaffold(
                  body: Center(child: Text('Lead not found')),
                );
              }
              return EditLeadScreen(lead: lead);
            },
          ),
        ],
      ),
      // Notifications — full screen overlay, outside shell
      GoRoute(
        path: '/notifications',
        name: RouteNames.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ── Shell (bottom nav visible) ─────────────────────────────────────────
      // 5 branches: Dashboard · Leads · Add Lead · Follow-ups · Settings
      // Branch index matches nav bar index 1:1 — no offset needed.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Branch 0 — Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: RouteNames.dashboard,
                builder: (context, state) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'insights',
                    name: RouteNames.insights,
                    builder: (context, state) => const WeeklyInsightsScreen(),
                  ),
                ],
              ),
            ],
          ),

          // Branch 1 — Leads list
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/leads',
                name: RouteNames.leads,
                builder: (context, state) => const LeadsListScreen(),
              ),
            ],
          ),

          // Branch 2 — Add Lead (method picker only; sub-screens are top-level)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/add-lead',
                name: RouteNames.addLead,
                builder: (context, state) => const AddLeadMethodScreen(),
              ),
            ],
          ),

          // Branch 3 — Follow-ups
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/follow-ups',
                name: RouteNames.followUps,
                builder: (context, state) => const FollowUpsScreen(),
              ),
            ],
          ),

          // Branch 4 — Settings + sub-pages
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: RouteNames.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'account',
                    name: RouteNames.settingsAccount,
                    builder: (context, state) => const AccountInfoScreen(),
                  ),
                  GoRoute(
                    path: 'security',
                    name: RouteNames.settingsSecurity,
                    builder: (context, state) => const SecurityScreen(),
                  ),
                  GoRoute(
                    path: 'privacy',
                    name: RouteNames.settingsPrivacy,
                    builder: (context, state) => const PrivacyDataScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    name: RouteNames.settingsNotifications,
                    builder: (context, state) =>
                        const NotificationPreferencesScreen(),
                  ),
                  GoRoute(
                    path: 'reminders',
                    name: RouteNames.settingsReminders,
                    builder: (context, state) => const RemindersScreen(),
                  ),
                  GoRoute(
                    path: 'help',
                    name: RouteNames.settingsHelp,
                    builder: (context, state) => const HelpSupportScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
