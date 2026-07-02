import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/data/profile_repository.dart';
import '../../../auth/presentation/providers/profile_state_provider.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  // Null while the profile is still loading.
  bool? _notifyHotLeads;
  bool? _notifyFollowUpDue;
  bool? _notifyWeeklyInsight;

  // Key of the toggle currently being saved; null when idle.
  String? _pendingKey;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefillIfNeeded();
  }

  void _prefillIfNeeded() {
    if (_notifyHotLeads != null) return;
    final profile = ref.read(profileDataProvider).valueOrNull;
    if (profile == null) return;
    _notifyHotLeads = profile.notifyHotLeads;
    _notifyFollowUpDue = profile.notifyFollowUpDue;
    _notifyWeeklyInsight = profile.notifyWeeklyInsight;
  }

  Future<void> _toggle(String key, bool newValue) async {
    if (_saving) return;

    // Snapshot for rollback on error.
    final prevHot = _notifyHotLeads!;
    final prevFollowUp = _notifyFollowUpDue!;
    final prevWeekly = _notifyWeeklyInsight!;

    // Optimistic flip — switch moves immediately.
    setState(() {
      _saving = true;
      _pendingKey = key;
      _error = null;
      if (key == 'hot') _notifyHotLeads = newValue;
      if (key == 'followup') _notifyFollowUpDue = newValue;
      if (key == 'weekly') _notifyWeeklyInsight = newValue;
    });

    try {
      await ref.read(profileRepositoryProvider).updateNotificationPreferences(
            notifyHotLeads: _notifyHotLeads!,
            notifyFollowUpDue: _notifyFollowUpDue!,
            notifyWeeklyInsight: _notifyWeeklyInsight!,
          );
      if (!mounted) return;
      ref.invalidate(profileDataProvider);
      setState(() {
        _saving = false;
        _pendingKey = null;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _pendingKey = null;
        _error = e.message;
        _notifyHotLeads = prevHot;
        _notifyFollowUpDue = prevFollowUp;
        _notifyWeeklyInsight = prevWeekly;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _pendingKey = null;
        _error = e.toString().replaceFirst('Exception: ', '');
        _notifyHotLeads = prevHot;
        _notifyFollowUpDue = prevFollowUp;
        _notifyWeeklyInsight = prevWeekly;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileDataProvider);

    // Pre-fill once data arrives if didChangeDependencies didn't catch it.
    ref.listen(profileDataProvider, (_, next) {
      if (_notifyHotLeads == null) {
        final profile = next.valueOrNull;
        if (profile != null) {
          setState(() {
            _notifyHotLeads = profile.notifyHotLeads;
            _notifyFollowUpDue = profile.notifyFollowUpDue;
            _notifyWeeklyInsight = profile.notifyWeeklyInsight;
          });
        }
      }
    });

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
                  const Text(
                    'Notification Preferences',
                    style: TextStyle(
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
                child: profileAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryLight),
                  ),
                  error: (err, _) => _ErrorState(
                    message: err is PostgrestException
                        ? err.message
                        : err.toString().replaceFirst('Exception: ', ''),
                    onRetry: () => ref.invalidate(profileDataProvider),
                  ),
                  data: (_) {
                    if (_notifyHotLeads == null) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryLight),
                      );
                    }
                    return _Body(
                      notifyHotLeads: _notifyHotLeads!,
                      notifyFollowUpDue: _notifyFollowUpDue!,
                      notifyWeeklyInsight: _notifyWeeklyInsight!,
                      saving: _saving,
                      pendingKey: _pendingKey,
                      error: _error,
                      onToggle: _toggle,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final bool notifyHotLeads;
  final bool notifyFollowUpDue;
  final bool notifyWeeklyInsight;
  final bool saving;
  final String? pendingKey;
  final String? error;
  final void Function(String key, bool value) onToggle;

  const _Body({
    required this.notifyHotLeads,
    required this.notifyFollowUpDue,
    required this.notifyWeeklyInsight,
    required this.saving,
    required this.pendingKey,
    required this.error,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xl,
          AppSpacing.xl, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose which alerts you want to receive',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'You can turn off any notification type at any time.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryLight,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          _ToggleRow(
            title: 'New hot lead alerts',
            subtitle: 'Notify me when a lead is marked as hot.',
            value: notifyHotLeads,
            isPending: pendingKey == 'hot',
            disabled: saving,
            onChanged: (v) => onToggle('hot', v),
          ),
          const Divider(height: 1, color: AppColors.dividerLight),

          _ToggleRow(
            title: 'Follow-up due / overdue alerts',
            subtitle: 'Notify me when a follow-up is due or overdue.',
            value: notifyFollowUpDue,
            isPending: pendingKey == 'followup',
            disabled: saving,
            onChanged: (v) => onToggle('followup', v),
          ),
          const Divider(height: 1, color: AppColors.dividerLight),

          _ToggleRow(
            title: 'Weekly insight summaries',
            subtitle: 'Receive a weekly summary of your lead activity.',
            value: notifyWeeklyInsight,
            isPending: pendingKey == 'weekly',
            disabled: saving,
            onChanged: (v) => onToggle('weekly', v),
          ),
          const Divider(height: 1, color: AppColors.dividerLight),

          if (error != null) ...[
            const SizedBox(height: AppSpacing.lg),
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
                  fontSize: 13,
                  color: AppColors.dangerTextLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Toggle row ─────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool isPending;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isPending,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: disabled && !isPending
                            ? AppColors.textDisabledLight
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: disabled && !isPending
                        ? AppColors.textDisabledLight
                        : AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Replace the switch with a spinner while this specific row is saving.
          if (isPending)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryLight,
                ),
              ),
            )
          else
            Switch(
              value: value,
              onChanged: disabled ? null : onChanged,
              activeThumbColor: AppColors.primaryLight,
              activeTrackColor: AppColors.primaryTintLight,
            ),
        ],
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.dangerTextLight, size: 48),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Could not load settings.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
