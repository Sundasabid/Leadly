import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
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

  final Set<String> _completing = {};
  final Map<String, String> _rowErrors = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabCtrl.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
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

      await showCompleteOutcomeSheet(
        context,
        leadId: fu.leadId,
        leadName: fu.leadName ?? 'Lead',
        currentLeadStatus: 'new',
      );

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
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
              child: Text(
                'Follow-ups',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: asyncFollowUps.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryLight, strokeWidth: 2),
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

                  final idx = _tabCtrl.index;

                  return Column(
                    children: [
                      // ── Custom tab pills ───────────────────────────────
                      SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg),
                          children: [
                            _TabPill(
                              label: 'Overdue',
                              count: overdue.length,
                              active: idx == 0,
                              isOverdue: true,
                              onTap: () => _tabCtrl.animateTo(0),
                            ),
                            const SizedBox(width: 12),
                            _TabPill(
                              label: 'Due Today',
                              count: dueToday.length,
                              active: idx == 1,
                              onTap: () => _tabCtrl.animateTo(1),
                            ),
                            const SizedBox(width: 12),
                            _TabPill(
                              label: 'Upcoming',
                              count: upcoming.length,
                              active: idx == 2,
                              onTap: () => _tabCtrl.animateTo(2),
                            ),
                            const SizedBox(width: 12),
                            _TabPill(
                              label: 'Completed',
                              count: completed.length,
                              active: idx == 3,
                              onTap: () => _tabCtrl.animateTo(3),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // ── Tab content ─────────────────────────────────────
                      Expanded(
                        child: TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _TabView(
                              items: overdue,
                              tabStatus: 'overdue',
                              showCheckbox: true,
                              completing: _completing,
                              rowErrors: _rowErrors,
                              onComplete: _markComplete,
                              bottomPad: bottomPad,
                            ),
                            _TabView(
                              items: dueToday,
                              tabStatus: 'due_today',
                              showCheckbox: true,
                              completing: _completing,
                              rowErrors: _rowErrors,
                              onComplete: _markComplete,
                              bottomPad: bottomPad,
                            ),
                            _TabView(
                              items: upcoming,
                              tabStatus: 'upcoming',
                              showCheckbox: true,
                              completing: _completing,
                              rowErrors: _rowErrors,
                              onComplete: _markComplete,
                              bottomPad: bottomPad,
                            ),
                            _TabView(
                              items: completed,
                              tabStatus: 'completed',
                              showCheckbox: false,
                              completing: _completing,
                              rowErrors: _rowErrors,
                              onComplete: _markComplete,
                              bottomPad: bottomPad,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom tab pill ────────────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final bool isOverdue;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.count,
    required this.active,
    this.isOverdue = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = isOverdue
        ? const Color(0xFFEF4444)
        : const Color(0xFF1B3A8A);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.w400,
                  color: active
                      ? const Color(0xFF1B3A8A)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab content view ───────────────────────────────────────────────────────────

class _TabView extends StatelessWidget {
  final List<FollowUpModel> items;
  final String tabStatus;
  final bool showCheckbox;
  final Set<String> completing;
  final Map<String, String> rowErrors;
  final ValueChanged<FollowUpModel> onComplete;
  final double bottomPad;

  const _TabView({
    required this.items,
    required this.tabStatus,
    required this.showCheckbox,
    required this.completing,
    required this.rowErrors,
    required this.onComplete,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _emptyState(tabStatus);

    final accent = _accentColor(tabStatus);

    if (tabStatus == 'upcoming') {
      return _GroupedUpcomingList(
        items: items,
        accentColor: accent,
        completing: completing,
        rowErrors: rowErrors,
        onComplete: onComplete,
        bottomPad: bottomPad,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
      itemCount: items.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _FollowUpCard(
          followUp: items[i],
          accentColor: accent,
          showCheckbox: showCheckbox,
          isCompleting: completing.contains(items[i].id),
          error: rowErrors[items[i].id],
          onComplete: () => onComplete(items[i]),
        ),
      ),
    );
  }
}

Widget _emptyState(String tabStatus) => switch (tabStatus) {
      'overdue' => const _EmptyState(
          icon: LucideIcons.checkCircle2,
          iconColor: Color(0xFF10B981),
          iconBg: Color(0xFFECFDF5),
          title: 'All caught up!',
          subtitle: 'No overdue follow-ups',
        ),
      'due_today' => const _EmptyState(
          icon: LucideIcons.sun,
          iconColor: Color(0xFFF59E0B),
          iconBg: Color(0xFFFFFBEB),
          title: 'Nothing due today',
          subtitle: 'Check back later or schedule a follow-up',
        ),
      'upcoming' => const _EmptyState(
          icon: LucideIcons.calendar,
          iconColor: Color(0xFF1B3A8A),
          iconBg: Color(0xFFEFF6FF),
          title: 'Nothing scheduled',
          subtitle: 'Schedule follow-ups from your lead cards',
        ),
      'completed' => const _EmptyState(
          icon: LucideIcons.clock,
          iconColor: Color(0xFF9CA3AF),
          iconBg: Color(0xFFF3F4F6),
          title: 'No completed follow-ups yet',
          subtitle: 'Complete follow-ups to see them here',
        ),
      _ => const SizedBox.shrink(),
    };

// ── Grouped list for the Upcoming tab ─────────────────────────────────────────

class _GroupedUpcomingList extends StatelessWidget {
  final List<FollowUpModel> items;
  final Color accentColor;
  final Set<String> completing;
  final Map<String, String> rowErrors;
  final ValueChanged<FollowUpModel> onComplete;
  final double bottomPad;

  const _GroupedUpcomingList({
    required this.items,
    required this.accentColor,
    required this.completing,
    required this.rowErrors,
    required this.onComplete,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final oneWeekLater = today.add(const Duration(days: 7));

    final tomorrowItems = <FollowUpModel>[];
    final thisWeekItems = <FollowUpModel>[];
    final laterItems = <FollowUpModel>[];

    for (final fu in items) {
      final local = fu.dueAt.toLocal();
      final dueDay = DateTime(local.year, local.month, local.day);
      if (dueDay == tomorrow) {
        tomorrowItems.add(fu);
      } else if (dueDay.isAfter(tomorrow) && !dueDay.isAfter(oneWeekLater)) {
        thisWeekItems.add(fu);
      } else {
        laterItems.add(fu);
      }
    }

    final listItems = <Object>[];
    if (tomorrowItems.isNotEmpty) {
      listItems.add('TOMORROW');
      listItems.addAll(tomorrowItems);
    }
    if (thisWeekItems.isNotEmpty) {
      listItems.add('THIS WEEK');
      listItems.addAll(thisWeekItems);
    }
    if (laterItems.isNotEmpty) {
      listItems.add('LATER');
      listItems.addAll(laterItems);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
      itemCount: listItems.length,
      itemBuilder: (ctx, i) {
        final item = listItems[i];
        if (item is String) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              item,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9CA3AF),
                letterSpacing: 0.5,
              ),
            ),
          );
        }
        final fu = item as FollowUpModel;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _FollowUpCard(
            followUp: fu,
            accentColor: accentColor,
            showCheckbox: true,
            isCompleting: completing.contains(fu.id),
            error: rowErrors[fu.id],
            onComplete: () => onComplete(fu),
          ),
        );
      },
    );
  }
}

// ── Follow-up card ─────────────────────────────────────────────────────────────

class _FollowUpCard extends StatelessWidget {
  final FollowUpModel followUp;
  final Color accentColor;
  final bool showCheckbox;
  final bool isCompleting;
  final String? error;
  final VoidCallback onComplete;

  const _FollowUpCard({
    required this.followUp,
    required this.accentColor,
    required this.showCheckbox,
    required this.isCompleting,
    required this.error,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/leads/${followUp.leadId}'),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main content: accent bar + body
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  Container(width: 4, color: accentColor),

                  // Body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TOP ROW: lead name + priority badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  followUp.leadName ?? 'Unknown Lead',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF111827),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _PriorityBadge(
                                  priority: followUp.priority),
                            ],
                          ),

                          // SECOND ROW: area with MapPin icon
                          if (followUp.leadArea != null &&
                              followUp.leadArea!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.mapPin,
                                  size: 12,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    followUp.leadArea!,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF6B7280),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 6),

                          // THIRD ROW: task description
                          Text(
                            followUp.taskDescription,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF4B5563),
                              fontStyle: followUp.taskDescription
                                          .toLowerCase()
                                          .trim() ==
                                      'follow up'
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 8),

                          // BOTTOM ROW: clock + due time + circle
                          Row(
                            children: [
                              Icon(LucideIcons.clock,
                                  size: 12, color: accentColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatDue(followUp.dueAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              // Completion circle
                              if (isCompleting)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryLight,
                                  ),
                                )
                              else if (showCheckbox)
                                GestureDetector(
                                  onTap: onComplete,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            const Color(0xFFD1D5DB),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                // Completed indicator
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF10B981),
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Per-row error
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 12, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
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
              ),
          ],
        ),
      ),
    );
  }
}

// ── Priority badge ─────────────────────────────────────────────────────────────

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
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;

  const _EmptyState({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondaryLight,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: AppColors.dangerTextLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Could not load follow-ups',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
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
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Color _accentColor(String status) => switch (status) {
      'overdue'   => const Color(0xFFEF4444),
      'due_today' => const Color(0xFFF59E0B),
      'upcoming'  => const Color(0xFF1B3A8A),
      'completed' => const Color(0xFF10B981),
      _           => const Color(0xFF1B3A8A),
    };

String _formatDue(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(local.year, local.month, local.day);
  final diff = dueDay.difference(today).inDays;
  final t = _timeStr(local);
  if (diff == 0) return 'Today, $t';
  if (diff == 1) return 'Tomorrow, $t';
  if (diff == -1) return 'Yesterday, $t';
  if (diff < 0) return '${-diff}d ago, $t';
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${local.day} ${months[local.month]}, $t';
}

String _timeStr(DateTime local) {
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $period';
}
