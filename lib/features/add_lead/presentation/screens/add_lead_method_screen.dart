import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_flutter/lucide_flutter.dart';


class AddLeadMethodScreen extends StatelessWidget {
  const AddLeadMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      // Scaffold bg matches the gradient end so there's no flash during transitions
      backgroundColor: const Color(0xFF162d6e),
      body: Column(
        children: [
          // ── Navy gradient top (40%) ──────────────────────────────────────
          Expanded(
            flex: 40,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B3A8A), Color(0xFF162d6e)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Back button — top-left
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
                          child: GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Centered hero content
                    const Icon(
                      LucideIcons.building2,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add New Lead',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'How would you like to capture this lead?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),

          // ── White bottom section (60%), overlapping navy by 20px ─────────
          Expanded(
            flex: 60,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -20,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                          0, 32, 0, 40 + bottomInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Manual Entry card ────────────────────────────
                          _MethodCard(
                            icon: LucideIcons.fileText,
                            isVoice: false,
                            title: 'Enter Manually',
                            subtitle: 'Type in lead details yourself',
                            pills: const ['Fast', 'Accurate', 'Full control'],
                            onTap: () => context.push('/add-lead/manual'),
                          ),

                          const SizedBox(height: 12),

                          // ── Voice Record card ────────────────────────────
                          _MethodCard(
                            icon: LucideIcons.mic,
                            isVoice: true,
                            title: 'Record Voice',
                            subtitle: 'Speak naturally, AI fills the form',
                            pills: const [
                              'Hands-free',
                              'Smart AI',
                              'Roman Urdu',
                            ],
                            onTap: () => context.go('/add-lead/voice'),
                          ),

                          const SizedBox(height: 20),

                          // ── Tip box ──────────────────────────────────────
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.lightbulb,
                                  color: Color(0xFF1B3A8A),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Voice works best in quiet environments',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF1B3A8A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Method card ────────────────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final bool isVoice;
  final String title;
  final String subtitle;
  final List<String> pills;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.isVoice,
    required this.title,
    required this.subtitle,
    required this.pills,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: 52,
      height: 52,
      decoration: isVoice
          ? BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B3A8A), Color(0xFF2D5BE3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            )
          : BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
      child: Icon(
        icon,
        color: isVoice ? Colors.white : const Color(0xFF1B3A8A),
        size: 24,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 7),
                  // Feature pills — Wrap handles narrow screens
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: pills
                        .map(
                          (p) => Container(
                            height: 18,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 7),
                            decoration: BoxDecoration(
                              color: isVoice
                                  ? const Color(0xFFEEF2FF)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text(
                                p,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isVoice
                                      ? const Color(0xFF1B3A8A)
                                      : const Color(0xFF374151),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}
