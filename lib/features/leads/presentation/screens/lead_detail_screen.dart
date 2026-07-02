import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  // ── Status update ───────────────────────────────────────────────────────────

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

  // ── Edit ────────────────────────────────────────────────────────────────────

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

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        contentPadding:
            const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
        actionsPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.dangerBgLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_rounded,
                color: AppColors.dangerTextLight,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Delete Lead?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'This lead and all its data will be permanently deleted. This cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerTextLight,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Yes, Delete Lead',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondaryLight,
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

  // ── Quick actions ───────────────────────────────────────────────────────────

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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final leadAsync = ref.watch(leadDetailProvider(widget.leadId));

    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: SafeArea(
        child: leadAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white54, size: 48),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Could not load lead',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(leadDetailProvider(widget.leadId)),
                    child: const Text('Retry',
                        style: TextStyle(color: Colors.white70)),
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
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () => context.go('/leads'),
                      child: const Text('Back to Leads',
                          style: TextStyle(color: Colors.white)),
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
              onDelete: _confirmDelete,
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
        // ── Blue header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          child: Row(
            children: [
              // Back
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
              // Lead name
              Expanded(
                child: Text(
                  lead.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Edit
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Delete
              if (deleting)
                const SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
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
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.delete_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
        ),

        // ── White card ───────────────────────────────────────────────────
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
                  // ── Phone + quick actions ──────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Phone',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lead.phone,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Call button
                      GestureDetector(
                        onTap: onCall,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                                color: const Color(0xFF86EFAC)),
                          ),
                          child: const Icon(
                            Icons.phone_rounded,
                            color: Color(0xFF16A34A),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // WhatsApp button
                      GestureDetector(
                        onTap: onWhatsApp,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                                color: const Color(0xFF86EFAC)),
                          ),
                          child: Center(
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/image.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  const _Divider(),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Info fields ──────────────────────────────────────
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
                    last: lead.notes == null || lead.notes!.isEmpty,
                  ),
                  if (lead.notes != null && lead.notes!.isNotEmpty)
                    _InfoRow(
                        label: 'Notes',
                        value: lead.notes!,
                        last: true),

                  const SizedBox(height: AppSpacing.xl),
                  const _Divider(),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Status ───────────────────────────────────────────
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (statusUpdating)
                    const SizedBox(
                      height: 44,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryLight,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else
                    _StatusRow(
                      current: lead.status,
                      onTap: onStatusTap,
                    ),

                  if (statusError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBgLight,
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        statusError!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.dangerTextLight,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                  const _Divider(),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Schedule Follow-up ────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => showScheduleFollowUpSheet(
                        context,
                        leadId: lead.id,
                        leadName: lead.name,
                        leadStatus: lead.status,
                      ),
                      icon: const Icon(
                          Icons.calendar_month_outlined, size: 18),
                      label: const Text('Schedule Follow-up'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: const BorderSide(
                            color: AppColors.primaryLight),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Status row ─────────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final String current;
  final ValueChanged<String> onTap;

  static const _statuses = [
    kStatusNew, kStatusHot, kStatusWarm, kStatusCold, kStatusDone,
  ];

  const _StatusRow({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _statuses.map((s) {
        final active = s == current;
        return GestureDetector(
          onTap: active ? null : () => onTap(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 10),
            decoration: BoxDecoration(
              color: active ? _statusBg(s) : AppColors.surfaceAltLight,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: active ? _statusBg(s) : AppColors.borderLight,
              ),
            ),
            child: Text(
              _capitalize(s),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active
                    ? _statusFg(s)
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Small widgets ──────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const _InfoRow(
      {required this.label, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryLight)),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(
      height: 1, thickness: 1, color: AppColors.surfaceAltLight);
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
      '1_3_months': '1–3 Months',
      '3_6_months': '3–6 Months',
      '6_plus_months': '6+ Months',
    }[db] ??
    db;

Color _statusBg(String s) => switch (s) {
      kStatusNew  => const Color(0xFFDBEAFE),
      kStatusHot  => const Color(0xFFFFEDD5),
      kStatusWarm => const Color(0xFFFEF9C3),
      kStatusCold => const Color(0xFFE0F2FE),
      kStatusDone => const Color(0xFFDCFCE7),
      _           => AppColors.surfaceAltLight,
    };

Color _statusFg(String s) => switch (s) {
      kStatusNew  => const Color(0xFF1D4ED8),
      kStatusHot  => const Color(0xFFC2410C),
      kStatusWarm => const Color(0xFF92400E),
      kStatusCold => const Color(0xFF0369A1),
      kStatusDone => const Color(0xFF15803D),
      _           => AppColors.textSecondaryLight,
    };
