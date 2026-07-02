import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../leads/data/leads_repository.dart';
import '../../../leads/domain/models/lead_model.dart';
import '../../../leads/presentation/providers/leads_providers.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';
import '../providers/follow_ups_providers.dart';
import 'schedule_follow_up_sheet.dart';

/// Centered dialog shown after markComplete() succeeds.
/// Asks "How did it go?" — agent picks an outcome or dismisses.
/// Both steps (outcome + schedule prompt) live inside the same dialog
/// so no second surface stacks on top of the bottom nav.
class _CompleteOutcomeDialog extends ConsumerStatefulWidget {
  final String leadId;
  final String leadName;
  final String currentLeadStatus;

  const _CompleteOutcomeDialog({
    required this.leadId,
    required this.leadName,
    required this.currentLeadStatus,
  });

  @override
  ConsumerState<_CompleteOutcomeDialog> createState() =>
      _CompleteOutcomeDialogState();
}

enum _DialogStep { outcome, schedulePrompt }

class _CompleteOutcomeDialogState
    extends ConsumerState<_CompleteOutcomeDialog> {
  _DialogStep _step = _DialogStep.outcome;
  String? _chosenStatus;
  bool _updating = false;
  String? _error;

  void _invalidateAll() {
    ref.invalidate(followUpsProvider);
    ref.invalidate(leadsAsyncProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(leadDetailProvider(widget.leadId));
    ref.invalidate(notificationsProvider);
  }

  Future<void> _pickOutcome(String newStatus) async {
    setState(() {
      _updating = true;
      _error = null;
    });

    try {
      await ref
          .read(leadsRepositoryProvider)
          .updateStatus(widget.leadId, newStatus);

      _invalidateAll();

      if (newStatus == kStatusDone) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      setState(() {
        _chosenStatus = newStatus;
        _updating = false;
        _step = _DialogStep.schedulePrompt;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _updating = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _updating = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _openScheduleSheet() {
    Navigator.of(context).pop();
    showScheduleFollowUpSheet(
      context,
      leadId: widget.leadId,
      leadName: widget.leadName,
      leadStatus: _chosenStatus ?? widget.currentLeadStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _step == _DialogStep.outcome
              ? _OutcomeStep(
                  leadName: widget.leadName,
                  updating: _updating,
                  error: _error,
                  onPick: _pickOutcome,
                )
              : _SchedulePromptStep(
                  onYes: _openScheduleSheet,
                  onSkip: () {
                    _invalidateAll();
                    Navigator.of(context).pop();
                  },
                ),
        ),
      ),
    );
  }
}

// ── Outcome step ───────────────────────────────────────────────────────────────

class _OutcomeStep extends StatelessWidget {
  final String leadName;
  final bool updating;
  final String? error;
  final ValueChanged<String> onPick;

  const _OutcomeStep({
    required this.leadName,
    required this.updating,
    required this.error,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How did it go?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          leadName,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryLight,
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        if (updating)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child:
                  CircularProgressIndicator(color: AppColors.primaryLight),
            ),
          )
        else ...[
          _OutcomeRow(
            label: 'Hot',
            subtitle: 'Very interested',
            dotColor: const Color(0xFFC2410C),
            bg: const Color(0xFFFFEDD5),
            fg: const Color(0xFFC2410C),
            onTap: () => onPick(kStatusHot),
          ),
          const SizedBox(height: AppSpacing.sm),
          _OutcomeRow(
            label: 'Warm',
            subtitle: 'Still interested',
            dotColor: const Color(0xFFD97706),
            bg: const Color(0xFFFEF9C3),
            fg: const Color(0xFF92400E),
            onTap: () => onPick(kStatusWarm),
          ),
          const SizedBox(height: AppSpacing.sm),
          _OutcomeRow(
            label: 'Cold',
            subtitle: 'Not interested right now',
            dotColor: const Color(0xFF0369A1),
            bg: const Color(0xFFE0F2FE),
            fg: const Color(0xFF0369A1),
            onTap: () => onPick(kStatusCold),
          ),
          const SizedBox(height: AppSpacing.sm),
          _OutcomeRow(
            label: 'Deal Done',
            subtitle: 'Lead closed',
            dotColor: const Color(0xFF15803D),
            bg: const Color(0xFFDCFCE7),
            fg: const Color(0xFF15803D),
            onTap: () => onPick(kStatusDone),
          ),
        ],

        if (error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.dangerBgLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              error!,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.dangerTextLight),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.md),

        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Skip',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color dotColor;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _OutcomeRow({
    required this.label,
    required this.subtitle,
    required this.dotColor,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: fg.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Schedule-next prompt ───────────────────────────────────────────────────────

class _SchedulePromptStep extends StatelessWidget {
  final VoidCallback onYes;
  final VoidCallback onSkip;

  const _SchedulePromptStep({required this.onYes, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Schedule next follow-up?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Set a reminder to follow up again.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: onYes,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Yes, schedule next'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondaryLight,
              textStyle: const TextStyle(fontSize: 14),
            ),
            child: const Text('Skip'),
          ),
        ),
      ],
    );
  }
}

// ── Convenience launcher (name kept for existing call sites) ──────────────────

Future<void> showCompleteOutcomeSheet(
  BuildContext context, {
  required String leadId,
  required String leadName,
  required String currentLeadStatus,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CompleteOutcomeDialog(
      leadId: leadId,
      leadName: leadName,
      currentLeadStatus: currentLeadStatus,
    ),
  );
}
