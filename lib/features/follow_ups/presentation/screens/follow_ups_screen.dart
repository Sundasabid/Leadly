import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/follow_up_repository.dart';
import '../../domain/models/follow_up_model.dart';
import '../providers/follow_ups_providers.dart';
import '../widgets/complete_outcome_sheet.dart';

class FollowUpsScreen extends ConsumerStatefulWidget {
  const FollowUpsScreen({super.key});

  @override
  ConsumerState<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends ConsumerState<FollowUpsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Tracks which follow-up rows are currently calling markComplete().
  final Set<String> _completing = {};
  // Tracks per-row mark-complete errors: followUpId → error message.
  final Map<String, String> _rowErrors = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _markComplete(FollowUpModel fu) async {
    setState(() {
      _completing.add(fu.id);
      _rowErrors.remove(fu.id);
    });

    try {
      await ref.read(followUpRepositoryProvider).markComplete(fu.id);
      if (!mounted) return;
      setState(() => _completing.remove(fu.id));

      // Only open the outcome sheet after the DB write is confirmed.
      await showCompleteOutcomeSheet(
        context,
        leadId: fu.leadId,
        leadName: fu.leadName ?? 'Lead',
        currentLeadStatus: 'new', // safe fallback; sheet updates status forward
      );

      // followUpsProvider is invalidated inside the sheet after any action.
      // If the sheet was dismissed without action, invalidate here so the
      // completed row disappears from the active tabs.
      ref.invalidate(followUpsProvider);
    } on PostgrestException catch (e) {
      setState(() {
        _completing.remove(fu.id);
        _rowErrors[fu.id] = e.message;
      });
    } catch (e) {
      setState(() {
        _completing.remove(fu.id);
        _rowErrors[fu.id] = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncFollowUps = ref.watch(followUpsProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom + 80;

    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Blue header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xl,
                  AppSpacing.lg, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Follow-ups',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── White card with tabs ─────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                ),
                child: asyncFollowUps.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryLight),
                  ),
                  error: (err, _) => _ErrorState(
                    message: err is PostgrestException
                        ? err.message
                        : err.toString().replaceFirst('Exception: ', ''),
                    onRetry: () => ref.invalidate(followUpsProvider),
                  ),
                  data: (all) {
                    final overdue = all
                        .where((f) => f.derivedStatus == 'overdue')
                        .toList();
                    final dueToday = all
                        .where((f) => f.derivedStatus == 'due_today')
                        .toList();
                    final upcoming = all
                        .where((f) => f.derivedStatus == 'upcoming')
                        .toList();
                    final completed = all
                        .where((f) => f.derivedStatus == 'completed')
                        .toList();

                    return Column(
                      children: [
                        // Tab bar
                        TabBar(
                          controller: _tabCtrl,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelColor: AppColors.primaryLight,
                          unselectedLabelColor:
                              AppColors.textSecondaryLight,
                          indicatorColor: AppColors.primaryLight,
                          indicatorWeight: 2,
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle:
                              const TextStyle(fontSize: 13),
                          tabs: [
                            _CountTab(
                                label: 'Overdue',
                                count: overdue.length),
                            _CountTab(
                                label: 'Due Today',
                                count: dueToday.length),
                            _CountTab(
                                label: 'Upcoming',
                                count: upcoming.length),
                            _CountTab(
                                label: 'Completed',
                                count: completed.length),
                          ],
                        ),
                        const Divider(
                            height: 1,
                            color: AppColors.dividerLight),

                        // Tab content
                        Expanded(
                          child: TabBarView(
                            controller: _tabCtrl,
                            children: [
                              _TabView(
                                items: overdue,
                                showCheckbox: true,
                                completing: _completing,
                                rowErrors: _rowErrors,
                                onComplete: _markComplete,
                                bottomPad: bottomPad,
                                emptyMessage:
                                    'No overdue follow-ups.',
                              ),
                              _TabView(
                                items: dueToday,
                                showCheckbox: true,
                                completing: _completing,
                                rowErrors: _rowErrors,
                                onComplete: _markComplete,
                                bottomPad: bottomPad,
                                emptyMessage:
                                    'Nothing due today.',
                              ),
                              _TabView(
                                items: upcoming,
                                showCheckbox: true,
                                completing: _completing,
                                rowErrors: _rowErrors,
                                onComplete: _markComplete,
                                bottomPad: bottomPad,
                                emptyMessage:
                                    'No upcoming follow-ups.',
                              ),
                              _TabView(
                                items: completed,
                                showCheckbox: false,
                                completing: _completing,
                                rowErrors: _rowErrors,
                                onComplete: _markComplete,
                                bottomPad: bottomPad,
                                emptyMessage:
                                    'No completed follow-ups yet.',
                              ),
                            ],
                          ),
                        ),
                      ],
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

// ── Tab label with count badge ─────────────────────────────────────────────────

class _CountTab extends StatelessWidget {
  final String label;
  final int count;
  const _CountTab({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius:
                    BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab content view ───────────────────────────────────────────────────────────

class _TabView extends StatelessWidget {
  final List<FollowUpModel> items;
  final bool showCheckbox;
  final Set<String> completing;
  final Map<String, String> rowErrors;
  final ValueChanged<FollowUpModel> onComplete;
  final double bottomPad;
  final String emptyMessage;

  const _TabView({
    required this.items,
    required this.showCheckbox,
    required this.completing,
    required this.rowErrors,
    required this.onComplete,
    required this.bottomPad,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(
          top: AppSpacing.sm, bottom: bottomPad),
      itemCount: items.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColors.dividerLight),
      itemBuilder: (ctx, i) {
        final fu = items[i];
        return _FollowUpRow(
          followUp: fu,
          showCheckbox: showCheckbox,
          isCompleting: completing.contains(fu.id),
          error: rowErrors[fu.id],
          onComplete: () => onComplete(fu),
        );
      },
    );
  }
}

// ── Follow-up row ──────────────────────────────────────────────────────────────

class _FollowUpRow extends StatelessWidget {
  final FollowUpModel followUp;
  final bool showCheckbox;
  final bool isCompleting;
  final String? error;
  final VoidCallback onComplete;

  const _FollowUpRow({
    required this.followUp,
    required this.showCheckbox,
    required this.isCompleting,
    required this.error,
    required this.onComplete,
  });

  Color get _priorityColor => switch (followUp.priority) {
        'hot' => const Color(0xFFC2410C),
        'cold' => const Color(0xFF0369A1),
        _ => const Color(0xFF92400E),
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/leads/${followUp.leadId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Priority indicator strip
                Container(
                  width: 3,
                  height: 48,
                  margin:
                      const EdgeInsets.only(right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _priorityColor,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                  ),
                ),

                // Body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lead name + area
                      Text(
                        followUp.leadName ?? 'Unknown Lead',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (followUp.leadArea != null &&
                          followUp.leadArea!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          followUp.leadArea!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      // Task description
                      Text(
                        followUp.taskDescription,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Due time + priority badge
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: AppColors.textDisabledLight,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatDue(followUp.dueAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textDisabledLight,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _PriorityBadge(
                              priority: followUp.priority),
                        ],
                      ),
                    ],
                  ),
                ),

                // Checkbox / spinner
                if (showCheckbox)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: AppSpacing.sm),
                    child: isCompleting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryLight,
                            ),
                          )
                        : GestureDetector(
                            onTap: onComplete,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.borderLight,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                  ),
              ],
            ),

            // Per-row error
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.dangerBgLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.dangerTextLight,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onComplete,
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dangerTextLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDue(DateTime dt) {
    // Convert to local time before extracting date components — due_at comes
    // from Supabase as UTC and DateTime.parse returns a UTC DateTime.
    // Without .toLocal(), date comparisons are wrong during the 5-hour window
    // where Pakistan (UTC+5) is on a different calendar day than UTC.
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(local.year, local.month, local.day);
    final diff = dueDay.difference(today).inDays;

    final timeStr = _timeStr(local);

    if (diff == 0) return 'Today, $timeStr';
    if (diff == 1) return 'Tomorrow, $timeStr';
    if (diff == -1) return 'Yesterday, $timeStr';
    if (diff < 0) return '${(-diff)}d ago, $timeStr';

    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${local.day} ${months[local.month]}, $timeStr';
  }

  String _timeStr(DateTime local) {
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ── Priority badge (for follow-up priority, not lead status) ──────────────────

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (priority) {
      'hot' => (
          const Color(0xFFFFEDD5),
          const Color(0xFFC2410C),
          'Hot'
        ),
      'cold' => (
          const Color(0xFFE0F2FE),
          const Color(0xFF0369A1),
          'Cold'
        ),
      _ => (
          const Color(0xFFFEF9C3),
          const Color(0xFF92400E),
          'Warm'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
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
              'Could not load follow-ups.',
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
