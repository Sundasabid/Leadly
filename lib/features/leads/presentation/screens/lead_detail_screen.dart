import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/leads_repository.dart';
import '../../domain/models/lead_model.dart';
import '../providers/leads_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../follow_ups/presentation/widgets/schedule_follow_up_sheet.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';

class LeadDetailScreen extends ConsumerStatefulWidget {
  final String leadId;
  const LeadDetailScreen({super.key, required this.leadId});

  @override
  ConsumerState<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends ConsumerState<LeadDetailScreen> {
  bool _statusUpdating = false;
  bool _deleting = false;
  String? _statusError;

  Future<void> _updateStatus(String newStatus) async {
    setState(() {
      _statusUpdating = true;
      _statusError = null;
    });
    try {
      await ref
          .read(leadsRepositoryProvider)
          .updateStatus(widget.leadId, newStatus);
      if (!mounted) return;
      ref.invalidate(leadDetailProvider(widget.leadId));
      ref.invalidate(leadsAsyncProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(notificationsProvider);
    } on PostgrestException catch (e) {
      setState(() => _statusError = e.message);
    } catch (_) {
      setState(() => _statusError = 'Could not update status. Please retry.');
    } finally {
      if (mounted) setState(() => _statusUpdating = false);
    }
  }

  Future<void> _onEdit(LeadModel lead) async {
    final schedule = await context.push<bool>(
        '/leads/${lead.id}/edit', extra: lead);
    if (!mounted) return;
    if (schedule == true) {
      showScheduleFollowUpSheet(context,
          leadId: lead.id,
          leadName: lead.name,
          leadStatus: lead.status);
    }
  }

  Future<void> _confirmDelete(String leadName) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Trash icon circle
              Container(
                margin: const EdgeInsets.only(top: 20),
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.trash2,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Delete Lead?',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Description
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Text(
                  'This will permanently delete $leadName and all associated follow-ups. This cannot be undone.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Delete button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Delete',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                    foregroundColor: const Color(0xFF374151),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(leadsRepositoryProvider).deleteLead(widget.leadId);
      if (!mounted) return;
      ref.invalidate(leadsAsyncProvider);
      ref.invalidate(dashboardStatsProvider);
      context.go('/leads');
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not delete lead. Please retry.')),
        );
      }
    }
  }

  Future<void> _launchCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String phone) async {
    final digits = phone.startsWith('+') ? phone.substring(1) : phone;
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadAsync = ref.watch(leadDetailProvider(widget.leadId));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        bottom: false,
        child: leadAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.primaryLight, strokeWidth: 2),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Color(0xFF9CA3AF), size: 48),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Could not load lead',
                    style: TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(leadDetailProvider(widget.leadId)),
                    child: const Text('Retry',
                        style: TextStyle(color: AppColors.primaryLight)),
                  ),
                ],
              ),
            ),
          ),
          data: (lead) {
            if (lead == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Lead not found.',
                        style: TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () => context.go('/leads'),
                      child: const Text('Back to Leads',
                          style: TextStyle(
                              color: AppColors.primaryLight)),
                    ),
                  ],
                ),
              );
            }
            return _Body(
              lead: lead,
              statusUpdating: _statusUpdating,
              deleting: _deleting,
              statusError: _statusError,
              onStatusTap: _updateStatus,
              onDelete: () => _confirmDelete(lead.name),
              onEdit: () => _onEdit(lead),
              onCall: () => _launchCall(lead.phone),
              onWhatsApp: () => _launchWhatsApp(lead.phone),
            );
          },
        ),
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final LeadModel lead;
  final bool statusUpdating;
  final bool deleting;
  final String? statusError;
  final ValueChanged<String> onStatusTap;
  final VoidCallback onDelete;
  final Future<void> Function() onEdit;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  const _Body({
    required this.lead,
    required this.statusUpdating,
    required this.deleting,
    required this.statusError,
    required this.onStatusTap,
    required this.onDelete,
    required this.onEdit,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Navigation row (on #F0F4F8 bg) ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              // Back
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Color(0xFF374151), size: 20),
                ),
              ),
              const Spacer(),
              // Edit
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Color(0xFF374151), size: 18),
                ),
              ),
              const SizedBox(width: 8),
              // Delete (or spinner while deleting)
              if (deleting)
                const SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.primaryLight, strokeWidth: 2),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.delete_rounded,
                        color: Color(0xFFEF4444), size: 20),
                  ),
                ),
            ],
          ),
        ),

        // ── Scrollable cards ─────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── TOP HERO CARD ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              lead.name,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusBg(lead.status),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              _capitalize(lead.status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _statusFg(lead.status),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(
                          height: 1,
                          thickness: 0.5,
                          color: Color(0xFFF3F4F6)),
                      const SizedBox(height: 12),

                      // Phone + action circles
                      Row(
                        children: [
                          const Icon(LucideIcons.phone,
                              size: 14, color: Color(0xFF1B3A8A)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lead.phone,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: const Color(0xFF374151),
                              ),
                            ),
                          ),
                          // Call circle
                          GestureDetector(
                            onTap: onCall,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFEEF2FF),
                              ),
                              child: const Icon(
                                LucideIcons.phone,
                                color: Color(0xFF1B3A8A),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // WhatsApp circle
                          GestureDetector(
                            onTap: onWhatsApp,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF25D366),
                              ),
                              child: const Center(
                                child: FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── INFO CARD ─────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                          label: 'Area / Society',
                          value: lead.areaSociety),
                      _InfoRow(
                          label: 'Property Type',
                          value: _capitalize(lead.propertyType)),
                      _InfoRow(
                          label: 'Intent',
                          value: _capitalize(lead.intent)),
                      _InfoRow(
                          label: 'Timeline',
                          value: _timelineDisplay(lead.timeline)),
                      if (lead.budgetPkr != null)
                        _InfoRow(
                            label: 'Budget',
                            value: _formatBudget(lead.budgetPkr!)),
                      _InfoRow(
                          label: 'Source',
                          value: _capitalize(lead.source)),
                      _InfoRow(
                        label: 'Added',
                        value: _formatDate(lead.createdAt),
                        last: lead.notes == null ||
                            lead.notes!.isEmpty,
                      ),
                      if (lead.notes != null &&
                          lead.notes!.isNotEmpty)
                        _NotesRow(notes: lead.notes!),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── STATUS CARD ───────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UPDATE STATUS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF9CA3AF),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (statusUpdating)
                        const SizedBox(
                          height: 32,
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primaryLight,
                                strokeWidth: 2),
                          ),
                        )
                      else
                        _StatusChips(
                            current: lead.status,
                            onTap: onStatusTap),
                      if (statusError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBgLight,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            statusError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.dangerTextLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── SCHEDULE FOLLOW-UP BUTTON ─────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B3A8A)
                            .withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => showScheduleFollowUpSheet(
                        context,
                        leadId: lead.id,
                        leadName: lead.name,
                        leadStatus: lead.status,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B3A8A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            LucideIcons.calendarPlus,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Schedule Follow-up',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Info row ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const _InfoRow(
      {required this.label, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!last)
          const Divider(
              height: 1, thickness: 0.5, color: Color(0xFFF3F4F6)),
      ],
    );
  }
}

// ── Notes row ──────────────────────────────────────────────────────────────────

class _NotesRow extends StatelessWidget {
  final String notes;
  const _NotesRow({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              notes,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status chips (horizontal scroll) ──────────────────────────────────────────

class _StatusChips extends StatelessWidget {
  final String current;
  final ValueChanged<String> onTap;

  static const _statuses = [
    kStatusNew, kStatusHot, kStatusWarm, kStatusCold, kStatusDone,
  ];

  const _StatusChips({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statuses.map((s) {
          final active = s == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: active ? null : () => onTap(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF1B3A8A)
                      : Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF1B3A8A)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Center(
                  child: Text(
                    _capitalize(s),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _formatBudget(double v) {
  final n = v.toInt().toString();
  final buf = StringBuffer('PKR ');
  final offset = n.length % 3;
  for (var i = 0; i < n.length; i++) {
    if (i != 0 && (i - offset) % 3 == 0) buf.write(',');
    buf.write(n[i]);
  }
  return buf.toString();
}

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.day} ${_month(local.month)} ${local.year}';
}

String _month(int m) => const [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][m];

String _timelineDisplay(String db) => const {
      'immediate': 'Immediate',
      'within_1_month': 'Within 1 Month',
      '1_3_months': '1-3 Months',
      '3_6_months': '3-6 Months',
      '6_plus_months': '6+ Months',
    }[db] ??
    db;

Color _statusBg(String s) => switch (s) {
      kStatusNew  => const Color(0xFFEEF2FF),
      kStatusHot  => const Color(0xFFFFF7ED),
      kStatusWarm => const Color(0xFFFFFBEB),
      kStatusCold => const Color(0xFFF9FAFB),
      kStatusDone => const Color(0xFFECFDF5),
      _           => AppColors.surfaceAltLight,
    };

Color _statusFg(String s) => switch (s) {
      kStatusNew  => const Color(0xFF1B3A8A),
      kStatusHot  => const Color(0xFFC2410C),
      kStatusWarm => const Color(0xFF92400E),
      kStatusCold => const Color(0xFF6B7280),
      kStatusDone => const Color(0xFF15803D),
      _           => AppColors.textSecondaryLight,
    };
