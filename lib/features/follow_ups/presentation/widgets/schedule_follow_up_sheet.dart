import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../features/leads/presentation/providers/leads_providers.dart';
import '../../data/follow_up_repository.dart';
import '../../domain/models/follow_up_model.dart';
import '../providers/follow_ups_providers.dart';

/// Call via [showScheduleFollowUpSheet].
class ScheduleFollowUpSheet extends ConsumerStatefulWidget {
  final String leadId;
  final String leadName;
  final String leadStatus;

  const ScheduleFollowUpSheet({
    super.key,
    required this.leadId,
    required this.leadName,
    required this.leadStatus,
  });

  @override
  ConsumerState<ScheduleFollowUpSheet> createState() =>
      _ScheduleFollowUpSheetState();
}

class _ScheduleFollowUpSheetState
    extends ConsumerState<ScheduleFollowUpSheet> {
  final _noteCtrl = TextEditingController();

  // Default: tomorrow at 10:00 AM
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryLight,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryLight,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  DateTime get _combinedDueAt => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Future<void> _save() async {
    final due = _combinedDueAt;
    if (due.isBefore(DateTime.now())) {
      setState(() => _error = 'Due date and time must be in the future.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Check for an existing pending follow-up before creating.
      // Isolated try/catch: if the check itself fails (network error etc.),
      // we skip the duplicate warning and proceed with creation rather than
      // blocking the agent — the check is a convenience guard, not a
      // safety constraint.
      FollowUpModel? existing;
      try {
        existing = await ref
            .read(followUpRepositoryProvider)
            .fetchPendingFollowUpForLead(widget.leadId);
      } catch (_) {
        existing = null;
      }

      if (!mounted) return;

      if (existing != null) {
        // Surface a confirmation dialog. _saving stays true so the button
        // stays disabled while the dialog is open.
        final proceed = await _showDuplicateDialog(existing.dueAt);
        if (!mounted) return;
        if (proceed != true) {
          // Agent chose Cancel — stay on the form with data intact.
          setState(() => _saving = false);
          return;
        }
      }

      await ref.read(followUpRepositoryProvider).createFollowUp(
            leadId: widget.leadId,
            dueAt: due,
            leadStatus: widget.leadStatus,
            taskDescription:
                _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );

      if (!mounted) return;
      ref.invalidate(followUpsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(leadDetailProvider(widget.leadId));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow-up scheduled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<bool?> _showDuplicateDialog(DateTime existingDueAt) {
    final local = existingDueAt.toLocal();
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    final dateStr =
        '${local.day} ${months[local.month]}, $h:$m $period';

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        contentPadding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
        actionsPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.warningBgLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_repeat_rounded,
                color: AppColors.warningTextLight,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Pending follow-up exists',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This lead already has a pending follow-up due $dateStr. Schedule another anyway?',
              style: const TextStyle(
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
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Schedule Anyway',
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
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──────────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg,
                  AppSpacing.xl, AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title ──────────────────────────────────────────
                  Text(
                    'Schedule Follow-up',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.leadName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Date + Time pickers ─────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _PickerButton(
                          label: 'Date',
                          value: _formatDate(_selectedDate),
                          icon: Icons.calendar_today_outlined,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _PickerButton(
                          label: 'Time',
                          value: _formatTime(_selectedTime),
                          icon: Icons.access_time_rounded,
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Task note ───────────────────────────────────────
                  AppTextField(
                    label: 'Note',
                    hint: 'e.g. Call to discuss budget',
                    controller: _noteCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    optional: true,
                  ),

                  // ── Error banner ────────────────────────────────────
                  if (_error != null) ...[
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
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.dangerTextLight,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  PrimaryButton(
                    label: 'Schedule',
                    onPressed: _saving ? null : _save,
                    loading: _saving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Picker button ──────────────────────────────────────────────────────────────

class _PickerButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAltLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 16, color: AppColors.textSecondaryLight),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimaryLight,
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

// ── Convenience launcher ───────────────────────────────────────────────────────

Future<void> showScheduleFollowUpSheet(
  BuildContext context, {
  required String leadId,
  required String leadName,
  required String leadStatus,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ScheduleFollowUpSheet(
      leadId: leadId,
      leadName: leadName,
      leadStatus: leadStatus,
    ),
  );
}
