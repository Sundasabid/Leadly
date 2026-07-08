import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
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
  int? _selected;
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
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Reminders',
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

            // ── Grey body ────────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
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
    (hours: 4,  short: '4h',  label: 'Every 4 hours'),
    (hours: 12, short: '12h', label: 'Every 12 hours'),
    (hours: 24, short: '24h', label: 'Every 24 hours'),
    (hours: 48, short: '48h', label: 'Every 48 hours'),
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
          AppSpacing.lg, AppSpacing.xl,
          AppSpacing.lg, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Follow-up Reminders',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
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

          ...(_options.map((opt) => _ReminderCard(
                hours: opt.hours,
                shortLabel: opt.short,
                fullLabel: opt.label,
                isSelected: opt.hours == selected,
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

// ── Reminder card ──────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final int hours;
  final String shortLabel;
  final String fullLabel;
  final bool isSelected;
  final bool isSaving;
  final bool disabled;
  final VoidCallback onTap;

  const _ReminderCard({
    required this.hours,
    required this.shortLabel,
    required this.fullLabel,
    required this.isSelected,
    required this.isSaving,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTintLight : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.primaryLight
                        : AppColors.textPrimaryLight,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fullLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? AppColors.primaryLight
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (isSaving)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryLight,
                ),
              )
            else if (isSelected)
              const Icon(LucideIcons.checkCircle2,
                  color: AppColors.primaryLight, size: 22),
          ],
        ),
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
