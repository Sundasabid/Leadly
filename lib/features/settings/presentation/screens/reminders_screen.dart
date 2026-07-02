import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/data/profile_repository.dart';
import '../../../auth/presentation/providers/profile_state_provider.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  // Null while the profile is still loading.
  int? _selected;
  // Set to the tapped option's hours while a save is in flight; null otherwise.
  int? _pendingHours;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selected == null) {
      final profile = ref.read(profileDataProvider).valueOrNull;
      if (profile != null) _selected = profile.reminderIntervalHours;
    }
  }

  Future<void> _save(int hours) async {
    if (_selected == hours || _saving) return;

    setState(() {
      _saving = true;
      _pendingHours = hours;
      _error = null;
    });

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateReminderInterval(hours);
      if (!mounted) return;
      ref.invalidate(profileDataProvider);
      setState(() {
        _selected = hours;
        _saving = false;
        _pendingHours = null;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _saving = false;
        _pendingHours = null;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _pendingHours = null;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileDataProvider);

    // Pre-fill once data arrives if didChangeDependencies didn't catch it.
    ref.listen(profileDataProvider, (_, next) {
      if (_selected == null) {
        final profile = next.valueOrNull;
        if (profile != null) {
          setState(() => _selected = profile.reminderIntervalHours);
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
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Text(
                    'Reminders',
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
                    if (_selected == null) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryLight),
                      );
                    }
                    return _Body(
                      selected: _selected!,
                      saving: _saving,
                      pendingHours: _pendingHours,
                      error: _error,
                      onSelect: _save,
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
  final int selected;
  final bool saving;
  final int? pendingHours;
  final String? error;
  final ValueChanged<int> onSelect;

  static const _options = [
    (hours: 4,  label: 'Every 4 hours'),
    (hours: 12, label: 'Every 12 hours'),
    (hours: 24, label: 'Every 24 hours'),
    (hours: 48, label: 'Every 48 hours'),
  ];

  const _Body({
    required this.selected,
    required this.saving,
    required this.pendingHours,
    required this.error,
    required this.onSelect,
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
            'Overdue follow-up reminders',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'How often should we remind you about overdue follow-ups?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryLight,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Option list — entire group disabled while a save is in flight.
          ...(_options.map((opt) => _OptionRow(
                label: opt.label,
                hours: opt.hours,
                isSelected: opt.hours == selected,
                // Spinner only on the exactly-tapped option.
                isSaving: opt.hours == pendingHours,
                disabled: saving,
                onTap: () => onSelect(opt.hours),
              ))),

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

// ── Option row ─────────────────────────────────────────────────────────────────

class _OptionRow extends StatelessWidget {
  final String label;
  final int hours;
  final bool isSelected;
  final bool isSaving;
  final bool disabled;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.hours,
    required this.isSelected,
    required this.isSaving,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md, horizontal: AppSpacing.xs),
            child: Row(
              children: [
                // Radio indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.borderLight,
                      width: isSelected ? 6 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: disabled && !isSelected
                          ? AppColors.textDisabledLight
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                // Spinner only on the currently-saving option (the
                // one whose hours != selected before the tap resolved).
                if (isSaving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryLight,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.dividerLight),
      ],
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
