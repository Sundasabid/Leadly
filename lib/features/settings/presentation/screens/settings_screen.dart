import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/profile_repository.dart';
import '../../../auth/domain/models/profile_model.dart';
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
                  Text(
                    'Settings',
                    style: GoogleFonts.poppins(
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
                      // ── Profile card ─────────────────────────────────────
                      profileAsync.when(
                        loading: () => const _ProfileCardSkeleton(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (profile) {
                          if (profile == null) return const SizedBox.shrink();
                          return _ProfileCard(profile: profile);
                        },
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Account section ──────────────────────────────────
                      _SectionLabel(label: 'Account'),
                      _SettingsRow(
                        icon: LucideIcons.user,
                        label: 'Account Info',
                        onTap: () => context.push('/settings/account'),
                      ),
                      _SettingsRow(
                        icon: LucideIcons.lock,
                        label: 'Security',
                        onTap: () => context.push('/settings/security'),
                      ),
                      _SettingsRow(
                        icon: LucideIcons.shield,
                        label: 'Privacy & Data',
                        onTap: () => context.push('/settings/privacy'),
                        isLast: true,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Preferences section ──────────────────────────────
                      _SectionLabel(label: 'Preferences'),
                      _SettingsRow(
                        icon: LucideIcons.bell,
                        label: 'Notification Preferences',
                        onTap: () =>
                            context.push('/settings/notifications'),
                      ),
                      _SettingsRow(
                        icon: LucideIcons.clock,
                        label: 'Reminders',
                        onTap: () => context.push('/settings/reminders'),
                        isLast: true,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Support section ──────────────────────────────────
                      _SectionLabel(label: 'Support'),
                      _SettingsRow(
                        icon: LucideIcons.helpCircle,
                        label: 'Help & Support',
                        onTap: () => context.push('/settings/help'),
                        isLast: true,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Logout ───────────────────────────────────────────
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

class _ProfileCard extends ConsumerStatefulWidget {
  final ProfileModel profile;
  const _ProfileCard({required this.profile});

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  bool _uploading = false;

  Future<void> _showPickerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTintLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.camera,
                    color: AppColors.primaryLight, size: 20),
              ),
              title: Text('Camera',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTintLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.image,
                    color: AppColors.primaryLight, size: 20),
              ),
              title: Text('Gallery',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      await ref.read(profileRepositoryProvider).uploadAvatar(bytes);
      if (!mounted) return;
      ref.invalidate(profileDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Upload failed: ${e.toString().replaceFirst('Exception: ', '')}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final initials =
        profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryTintLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          // Avatar with camera overlay
          GestureDetector(
            onTap: _uploading ? null : _showPickerSheet,
            child: Stack(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: _uploading
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          ),
                        )
                      : profile.avatarUrl != null
                          ? ClipOval(
                              child: Image.network(
                                profile.avatarUrl!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                ),
                // Camera overlay badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(LucideIcons.camera,
                        color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.agencyName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.email != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    profile.email!,
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
      height: 88,
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
                vertical: 12, horizontal: AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTintLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      color: AppColors.primaryLight, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                const Icon(LucideIcons.chevronRight,
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
