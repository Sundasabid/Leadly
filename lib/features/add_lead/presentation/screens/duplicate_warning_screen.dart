import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../leads/data/leads_repository.dart';
import '../../../leads/domain/models/lead_model.dart';
import '../../../leads/presentation/providers/leads_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/pending_lead_provider.dart';

class DuplicateWarningScreen extends ConsumerStatefulWidget {
  const DuplicateWarningScreen({super.key});

  @override
  ConsumerState<DuplicateWarningScreen> createState() =>
      _DuplicateWarningScreenState();
}

class _DuplicateWarningScreenState
    extends ConsumerState<DuplicateWarningScreen> {
  // Read once on open — not watched, so clearing the providers later
  // never triggers a rebuild and the card stays visible throughout
  // the exit animation.
  LeadModel? _existing;

  bool _saving = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _existing ??= ref.read(pendingDuplicateProvider);
  }

  @override
  void dispose() {
    // Clear after the widget is fully removed from the tree (post-animation),
    // so stale data never leaks into the next Add Lead attempt.
    ref.read(pendingLeadInputProvider.notifier).state = null;
    ref.read(pendingDuplicateProvider.notifier).state = null;
    super.dispose();
  }

  Future<void> _continueAnyway() async {
    final input = ref.read(pendingLeadInputProvider);
    if (input == null || _existing == null) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(leadsRepositoryProvider)
          .createLeadAsDuplicate(input, _existing!.id);

      if (!mounted) return;
      ref.invalidate(leadsAsyncProvider);
      ref.invalidate(dashboardStatsProvider);
      context.go('/leads');
    } on PostgrestException catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _goToExisting() => context.go('/leads/${_existing!.id}');

  void _cancel() => context.pop();

  @override
  Widget build(BuildContext context) {
    final existing = _existing;

    if (existing == null) {
      return const Scaffold(backgroundColor: Colors.transparent);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Material(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: Colors.white,
            elevation: 24,
            shadowColor: Colors.black26,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Warning icon + heading ───────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFF97316),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Possible Duplicate Lead',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'A lead with this phone number already exists in your CRM.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondaryLight,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Existing lead summary card ───────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAltLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryRow(label: 'Name', value: existing.name, bold: true),
                        _SummaryRow(label: 'Phone', value: existing.phone),
                        _SummaryRow(
                          label: 'Area / Society',
                          value: existing.areaSociety,
                        ),
                        _SummaryRow(
                          label: 'Property',
                          value: _capitalize(existing.propertyType),
                        ),
                        if (existing.budgetPkr != null)
                          _SummaryRow(
                            label: 'Budget',
                            value: _formatBudget(existing.budgetPkr!),
                          ),
                        _SummaryRow(
                          label: 'Intent',
                          value: _capitalize(existing.intent),
                          last: true,
                        ),
                      ],
                    ),
                  ),

                  // ── Error banner ─────────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBgLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.dangerTextLight,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  // ── Go to Existing Lead ──────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _goToExisting,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primaryLight.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text(
                        'Go to Existing Lead',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── Continue Anyway ──────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : _continueAnyway,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        disabledForegroundColor:
                            AppColors.primaryLight.withValues(alpha: 0.4),
                        side: const BorderSide(
                          color: AppColors.primaryLight,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryLight,
                                ),
                              ),
                            )
                          : const Text(
                              'Continue Anyway',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ── Cancel ───────────────────────────────────────────
                  Center(
                    child: TextButton(
                      onPressed: _saving ? null : _cancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondaryLight,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private helpers ────────────────────────────────────────────────────────────

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _formatBudget(double v) {
  final n = v.toInt().toString();
  final buffer = StringBuffer('PKR ');
  final offset = n.length % 3;
  for (var i = 0; i < n.length; i++) {
    if (i != 0 && (i - offset) % 3 == 0) buffer.write(',');
    buffer.write(n[i]);
  }
  return buffer.toString();
}

// ── Summary row ────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool last;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
