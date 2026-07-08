import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
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
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.sm, 0),
              child: Text(
                'Settings',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ),

            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, bottomPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Profile card ────────────────────────────────────────
                    profileAsync.when(
                      loading: () => const _ProfileCardSkeleton(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (profile) {
                        if (profile == null) return const SizedBox.shrink();
                        return _ProfileCard(profile: profile);
                      },
                    ),

                    // ── ACCOUNT section ─────────────────────────────────────
                    const _SectionLabel(label: 'ACCOUNT'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _SettingsRow(
                            icon: LucideIcons.user,
                            iconBg: const Color(0xFFEEF2FF),
                            iconFg: const Color(0xFF1B3A8A),
                            label: 'Account Info',
                            subtitle: 'Name, agency, contact',
                            onTap: () => context.push('/settings/account'),
                          ),
                          const SizedBox(height: 4),
                          _SettingsRow(
                            icon: LucideIcons.lock,
                            iconBg: const Color(0xFFFEF3C7),
                            iconFg: const Color(0xFFD97706),
                            label: 'Security',
                            subtitle: 'Password & authentication',
                            onTap: () => context.push('/settings/security'),
                          ),
                          const SizedBox(height: 4),
                          _SettingsRow(
                            icon: LucideIcons.shield,
                            iconBg: const Color(0xFFF0FDF4),
                            iconFg: const Color(0xFF16A34A),
                            label: 'Privacy & Data',
                            subtitle: 'Data usage & deletion',
                            onTap: () => context.push('/settings/privacy'),
                          ),
                        ],
                      ),
                    ),

                    // ── PREFERENCES section ─────────────────────────────────
                    const _SectionLabel(label: 'PREFERENCES'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _SettingsRow(
                            icon: LucideIcons.bell,
                            iconBg: const Color(0xFFFDF4FF),
                            iconFg: const Color(0xFF9333EA),
                            label: 'Notification Preferences',
                            subtitle: 'Alerts & notifications',
                            onTap: () =>
                                context.push('/settings/notifications'),
                          ),
                          const SizedBox(height: 4),
                          _SettingsRow(
                            icon: LucideIcons.clock,
                            iconBg: const Color(0xFFEFF6FF),
                            iconFg: const Color(0xFF2563EB),
                            label: 'Reminders',
                            subtitle: 'Follow-up reminder timing',
                            onTap: () => context.push('/settings/reminders'),
                          ),
                        ],
                      ),
                    ),

                    // ── SUPPORT section ─────────────────────────────────────
                    const _SectionLabel(label: 'SUPPORT'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SettingsRow(
                        icon: LucideIcons.helpCircle,
                        iconBg: const Color(0xFFF0FDF4),
                        iconFg: const Color(0xFF0D9488),
                        label: 'Help & Support',
                        subtitle: 'Contact us & FAQs',
                        onTap: () => context.push('/settings/help'),
                      ),
                    ),

                    // ── Log out ─────────────────────────────────────────────
                    const SizedBox(height: AppSpacing.xl),
                    const _LogoutRow(),

                    // ── Version ─────────────────────────────────────────────
                    const SizedBox(height: AppSpacing.xl),
                    Center(
                      child: Text(
                        'Propex v1.0.0',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: const Color(0xFF1B3A8A),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF1B3A8A),
          cropStyle: CropStyle.circle,
          aspectRatioPresets: [CropAspectRatioPreset.square],
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          cropStyle: CropStyle.circle,
          aspectRatioPresets: [CropAspectRatioPreset.square],
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    final oldUrl = widget.profile.avatarUrl;

    setState(() => _uploading = true);
    try {
      final bytes = await File(cropped.path).readAsBytes();
      await ref.read(profileRepositoryProvider).uploadAvatar(bytes);
      if (!mounted) return;
      if (oldUrl != null) imageCache.evict(NetworkImage(oldUrl));
      ref.invalidate(profileDataProvider);
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error - check your connection'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

    final avatarChild = _uploading
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
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 26,
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
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gradient banner + overlapping avatar
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Navy gradient banner
              Container(
                height: 60,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B3A8A), Color(0xFF2D5BE3)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              // Avatar centered, overlapping banner by 36px
              Positioned(
                bottom: -36,
                child: GestureDetector(
                  onTap: _uploading ? null : _showPickerSheet,
                  child: Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B3A8A),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipOval(child: avatarChild),
                      ),
                      // Camera badge
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.camera,
                            color: Color(0xFF1B3A8A),
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Space for the overlapping avatar (36px) + gap (12px)
          const SizedBox(height: 48),

          // Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              profile.name,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 4),

          // Agency
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              profile.agencyName,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 16),
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.surfaceAltLight,
        borderRadius: BorderRadius.circular(20),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 0, 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF9CA3AF),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Settings row ───────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconFg, size: 20),
            ),
            const SizedBox(width: 14),
            // Label + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _loading ? null : _logout,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
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
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.logOut,
                        color: AppColors.dangerTextLight,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dangerTextLight,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
