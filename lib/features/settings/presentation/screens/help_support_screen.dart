import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  // One tile open at a time - stores the controller for each FAQ.
  late final List<ExpansibleController> _controllers;

  static const _phone    = '03436696689';
  static const _waNumber = '923436696689'; // 03436696689 → strip 0, prepend 92
  static const _email    = 'appdev2614@gmail.com';

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_faqs.length, (_) => ExpansibleController());
  }

  void _onExpansionChanged(int tappedIndex, bool expanded) {
    if (!expanded) return; // collapsing - nothing to do
    // Collapse all other open tiles.
    for (var i = 0; i < _controllers.length; i++) {
      if (i != tappedIndex && _controllers[i].isExpanded) {
        _controllers[i].collapse();
      }
    }
  }

  Future<void> _launchCall() async {
    final uri = Uri(scheme: 'tel', path: _phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse('https://wa.me/$_waNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri(scheme: 'mailto', path: _email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: SafeArea(
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
                    'Help & Support',
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

            // ── White card ───────────────────────────────────────────────
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
                      AppSpacing.xl, AppSpacing.xl,
                      AppSpacing.xl, AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Contact ────────────────────────────────────────
                      const Text(
                        'Contact Support',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Reach us directly - we typically respond within a few hours.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      _ContactRow(
                        icon: Icons.phone_rounded,
                        label: 'Call Us',
                        detail: _phone,
                        onTap: _launchCall,
                      ),
                      const Divider(height: 1, color: AppColors.dividerLight),
                      _ContactRow(
                        icon: Icons.chat_rounded,
                        label: 'WhatsApp',
                        detail: _phone,
                        onTap: _launchWhatsApp,
                      ),
                      const Divider(height: 1, color: AppColors.dividerLight),
                      _ContactRow(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        detail: _email,
                        onTap: _launchEmail,
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      // ── FAQ ────────────────────────────────────────────
                      const Text(
                        'Frequently Asked Questions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      ...List.generate(_faqs.length, (i) {
                        final faq = _faqs[i];
                        return Column(
                          children: [
                            ExpansionTile(
                              controller: _controllers[i],
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(
                                  bottom: AppSpacing.lg),
                              iconColor: AppColors.primaryLight,
                              collapsedIconColor:
                                  AppColors.textSecondaryLight,
                              onExpansionChanged: (expanded) =>
                                  _onExpansionChanged(i, expanded),
                              title: Text(
                                faq.question,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    faq.answer,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondaryLight,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(
                                height: 1, color: AppColors.dividerLight),
                          ],
                        );
                      }),
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

// ── Contact row ────────────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryTintLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 20, color: AppColors.primaryLight),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondaryLight, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── FAQ data ───────────────────────────────────────────────────────────────────

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}

const List<_Faq> _faqs = [
  _Faq(
    'How do I add a new lead?',
    'Tap the + button in the centre of the bottom navigation bar. Choose "Enter Manually" to fill in the lead details yourself - name, phone number, budget, property type, location, status, intent, and timeline. Voice recording is coming soon and will let you speak the details instead.',
  ),
  _Faq(
    'What do the status labels mean, and how do I change them?',
    'Each lead has one of five statuses:\n\n'
        '- New: just added, not yet evaluated.\n'
        '- Hot: high priority - needs urgent attention.\n'
        '- Warm: interested but no immediate urgency.\n'
        '- Cold: low priority or unresponsive.\n'
        '- Done: deal closed or lead is no longer active.\n\n'
        'To change a status, open the lead\'s detail page and tap the status chip at the top. A sheet will appear with all five options - tap the one you want to apply it immediately.',
  ),
  _Faq(
    'How do follow-ups and reminders work?',
    'From a lead\'s detail page, tap "Schedule Follow-up" to set a date and time for your next check-in. When the follow-up is due, you\'ll receive a notification.\n\n'
        'Open the notification or the Follow-ups tab to find it. Tap "Mark as Complete" to log how the call or meeting went - you\'ll be asked for an outcome and given the option to schedule the next follow-up right away.\n\n'
        'You can control how frequently overdue follow-up reminders repeat in Settings → Reminders, and toggle them on or off entirely in Settings → Notification Preferences.',
  ),
  _Faq(
    'Why did I see a duplicate warning when adding a lead?',
    'If the phone number you enter already belongs to an existing lead, the app shows a warning before saving. This prevents accidental duplicates in your pipeline.\n\n'
        'You can tap "Continue Anyway" to save the new lead regardless, or go back and open the existing lead to update it instead.',
  ),
  _Faq(
    'How do I edit a lead?',
    'Open the lead\'s detail page and tap the edit icon in the top-right corner. You can update any field - name, phone, budget, location, status, intent, and timeline.\n\n'
        'If you change the timeline or intent, the app will prompt you to schedule a new follow-up to match the updated information.',
  ),
  _Faq(
    'How do I delete a lead?',
    'Open the lead\'s detail page and scroll to the bottom. Tap "Delete Lead" and confirm when prompted. Deleting a lead also removes all its associated follow-ups. This action cannot be undone.',
  ),
];
