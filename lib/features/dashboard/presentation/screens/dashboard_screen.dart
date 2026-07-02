import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../insights/data/insights_repository.dart';
import '../../../insights/presentation/providers/insights_providers.dart';
import '../../../leads/domain/models/lead_model.dart';
import '../providers/dashboard_provider.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    // Extra bottom clearance so content doesn't hide behind curved nav bar.
    final bottomPad = MediaQuery.of(context).padding.bottom + 80;

    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      extendBody: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Blue header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(Icons.notifications_outlined,
                              color: Colors.white, size: 20),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              constraints:
                                  const BoxConstraints(minWidth: 16),
                              height: 16,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              decoration: BoxDecoration(
                                color: AppColors.dangerTextLight,
                                borderRadius: BorderRadius.circular(
                                    AppRadius.pill),
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : '$unreadCount',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── White content ────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                ),
                child: statsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryLight),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.dangerTextLight, size: 48),
                          const SizedBox(height: AppSpacing.md),
                          Text(err.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondaryLight,
                                  fontSize: 14)),
                          const SizedBox(height: AppSpacing.lg),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(dashboardStatsProvider),
                            child: const Text('Retry',
                                style: TextStyle(
                                    color: AppColors.primaryLight,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (stats) => RefreshIndicator(
                    color: AppColors.primaryLight,
                    onRefresh: () async =>
                        ref.invalidate(dashboardStatsProvider),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.xl,
                          AppSpacing.lg, bottomPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Stats grid ─────────────────────────────
                          const Text(
                            'Overview',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Total Leads',
                                  value: stats.totalLeads,
                                  icon: Icons.people_rounded,
                                  iconBg: AppColors.primaryTintLight,
                                  iconColor: AppColors.primaryLight,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _StatCard(
                                  label: 'Hot Leads',
                                  value: stats.hotLeads,
                                  icon: Icons.local_fire_department_rounded,
                                  iconBg: const Color(0xFFFFEDD5),
                                  iconColor: const Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'New This Week',
                                  value: stats.newThisWeek,
                                  icon: Icons.person_add_rounded,
                                  iconBg: AppColors.successBgLight,
                                  iconColor: AppColors.successTextLight,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _StatCard(
                                  label: 'Warm Leads',
                                  value: stats.warmLeads,
                                  icon: Icons.trending_up_rounded,
                                  iconBg: AppColors.warningBgLight,
                                  iconColor: AppColors.warningTextLight,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // ── Insights cards (independent fetch) ──────
                          const _InsightsSection(),

                          // ── Recent leads ────────────────────────────
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Leads',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/leads'),
                                child: const Text(
                                  'See All',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          if (stats.recentLeads.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.xl),
                              child: Center(
                                child: Text(
                                  'No leads yet. Add your first lead!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...stats.recentLeads
                                .map((lead) => _RecentLeadCard(lead: lead)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Insights section ──────────────────────────────────────────────────────────

class _InsightsSection extends ConsumerWidget {
  const _InsightsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsCacheProvider);

    // While loading or on any error, render nothing — dashboard stays usable.
    // On null data (no cron row yet), also render nothing.
    return insightsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, stack) => const SizedBox.shrink(),
      data: (insights) {
        if (insights == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Market Trends',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _InsightCard(insights: insights),
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }
}

// ── Combined insight card ──────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final InsightsCacheModel insights;

  const _InsightCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    final sentence = insights.aiInsightSentence;
    final topArea = insights.topArea;

    return GestureDetector(
      onTap: () => context.push('/dashboard/insights'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceAltLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primaryTintLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_graph_rounded,
                color: AppColors.primaryLight,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly AI Insight',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sentence,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight,
                      height: 1.4,
                    ),
                  ),
                  if (topArea != null &&
                      insights.topInsightCategoryKey != 'area') ...[
                    const SizedBox(height: 3),
                    Text(
                      'Top area: ${topArea.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    insights.isFresh
                        ? 'Based on your leads'
                        : 'Data from ${insights.periodLabel}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryLight,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Change percentage badge ────────────────────────────────────────────────────

// ── Stat card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryLight,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent lead card ───────────────────────────────────────────────────────────

class _RecentLeadCard extends StatelessWidget {
  final LeadModel lead;
  const _RecentLeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/leads/${lead.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceAltLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            // Avatar initial
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primaryTintLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${lead.areaSociety}  •  ${lead.phone}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(status: lead.status, small: true),
          ],
        ),
      ),
    );
  }
}
