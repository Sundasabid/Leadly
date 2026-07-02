import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/profile_state_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom + 80;

    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Blue header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            // ── White content ──────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.xl,
                      AppSpacing.lg, bottomPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Profile card ────────────────────────────────────
                      profileAsync.when(
                        loading: () => const _ProfileCardSkeleton(),
                        error: (err, _) => const SizedBox.shrink(),
                        data: (profile) {
                          if (profile == null) return const SizedBox.shrink();
                          return _ProfileCard(
                            name: profile.name,
                            agency: profile.agencyName,
                            email: profile.email,
                          );
                        },
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Account section ─────────────────────────────────
                      _SectionLabel(label: 'Account'),
                      _SettingsRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Account Info',
                        onTap: () => context.push('/settings/account'),
                      ),
                      _SettingsRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Security',
                        onTap: () => context.push('/settings/security'),
                      ),
                      _SettingsRow(
                        icon: Icons.shield_outlined,
                        label: 'Privacy & Data',
                        onTap: () => context.push('/settings/privacy'),
                        isLast: true,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Preferences section ─────────────────────────────
                      _SectionLabel(label: 'Preferences'),
                      _SettingsRow(
                        icon: Icons.notifications_outlined,
                        label: 'Notification Preferences',
                        onTap: () =>
                            context.push('/settings/notifications'),
                      ),
                      _SettingsRow(
                        icon: Icons.alarm_outlined,
                        label: 'Reminders',
                        onTap: () => context.push('/settings/reminders'),
                        isLast: true,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Support section ─────────────────────────────────
                      _SectionLabel(label: 'Support'),
                      _SettingsRow(
                        icon: Icons.help_outline_rounded,
                        label: 'Help & Support',
                        onTap: () => context.push('/settings/help'),
                        isLast: true,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Logout ──────────────────────────────────────────
                      const _LogoutRow(),
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

// ── Profile card ───────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final String name;
  final String agency;
  final String? email;

  const _ProfileCard({
    required this.name,
    required this.agency,
    this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryTintLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          // Avatar initial
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  agency,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    email!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDisabledLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCardSkeleton extends StatelessWidget {
  const _ProfileCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surfaceAltLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textDisabledLight,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Settings row ───────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md, horizontal: AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAltLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon,
                      color: AppColors.textSecondaryLight, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textDisabledLight, size: 20),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, color: AppColors.dividerLight),
      ],
    );
  }
}

// ── Logout row ─────────────────────────────────────────────────────────────────

class _LogoutRow extends ConsumerStatefulWidget {
  const _LogoutRow();

  @override
  ConsumerState<_LogoutRow> createState() => _LogoutRowState();
}

class _LogoutRowState extends ConsumerState<_LogoutRow> {
  bool _loading = false;

  Future<void> _logout() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      // Router guard (authStateProvider) redirects to /auth/login automatically.
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _loading ? null : _logout,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.dangerTextLight,
          side: const BorderSide(color: AppColors.dangerTextLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.dangerTextLight),
                ),
              )
            : const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
