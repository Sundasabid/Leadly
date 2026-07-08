import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

class PrivacyDataScreen extends StatelessWidget {
  const PrivacyDataScreen({super.key});

  static const _email = 'appdev2614@gmail.com';

  Future<void> _launchEmail(String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {'subject': subject},
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showDeletionDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
          'Request Data Deletion?',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
        content: const Text(
          'This will open your email app with a pre-filled request. We will process your request within 30 days.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondaryLight,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondaryLight)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchEmail('Data Deletion Request - Propex');
            },
            child: const Text(
              'Send Request',
              style: TextStyle(
                  color: AppColors.dangerTextLight,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Blue header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Privacy & Data',
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

            // ── White body ───────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.xl,
                      AppSpacing.lg, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── What We Store ──────────────────────────────────
                      _PrivacySection(
                        icon: LucideIcons.database,
                        title: 'What We Store',
                        items: const [
                          'Your name, phone number, and agency details',
                          'Lead information you add (names, contacts, notes)',
                          'Your follow-up schedules and reminders',
                          'Your notification and app preferences',
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── How We Use Your Data ───────────────────────────
                      _PrivacySection(
                        icon: LucideIcons.shield,
                        title: 'How We Use Your Data',
                        items: const [
                          'To show you your leads and follow-ups',
                          'To send you smart reminders about your work',
                          'To generate weekly insights about your activity',
                          'We never sell or share your data with anyone',
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── Your Data is Safe ──────────────────────────────
                      _PrivacySection(
                        icon: LucideIcons.lock,
                        title: 'Your Data is Safe',
                        items: const [
                          'Your data is stored securely in the cloud',
                          'Only you can access your own information',
                          'You can delete your account and all data anytime',
                          'Voice recordings are processed instantly and never stored',
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Delete Your Data ───────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                              color: const Color(0xFFFECACA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.trash2,
                                    color: AppColors.dangerTextLight,
                                    size: 18),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Delete Your Data',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.dangerTextLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'You can request deletion of all your data. We will process your request within 30 days and confirm by email.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondaryLight,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () =>
                                    _showDeletionDialog(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      AppColors.dangerTextLight,
                                  side: const BorderSide(
                                      color: AppColors.dangerTextLight),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.sm),
                                  ),
                                ),
                                child: const Text(
                                  'Request Data Deletion',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
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

// ── Privacy section card ───────────────────────────────────────────────────────

class _PrivacySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;

  const _PrivacySection({
    required this.icon,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTintLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: AppColors.primaryLight, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: CircleAvatar(
                      radius: 3,
                      backgroundColor: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
