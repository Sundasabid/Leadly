import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/change_badge.dart';
import '../../data/insights_repository.dart';
import '../providers/insights_providers.dart';

class WeeklyInsightsScreen extends ConsumerWidget {
  const WeeklyInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsCacheProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Weekly Insights',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
        iconTheme:
            const IconThemeData(color: AppColors.textPrimaryLight),
      ),
      body: insightsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, stack) => const _EmptyState(),
        data: (insights) =>
            insights == null ? const _EmptyState() : _Body(insights: insights),
      ),
    );
  }
}

// ── Empty / no-data state ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primaryTintLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: AppColors.primaryLight,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'No insights yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Check back after your first week of activity.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main scrollable body ───────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final InsightsCacheModel insights;

  const _Body({required this.insights});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + AppSpacing.xl;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(insights: insights),
          const SizedBox(height: AppSpacing.xl),
          _CategoryGrid(insights: insights),
          if (insights.demandTrend.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _DemandTrendSection(points: insights.demandTrend),
          ],
        ],
      ),
    );
  }
}

// ── Header: subtitle + period label ───────────────────────────────────────────

class _Header extends StatelessWidget {
  final InsightsCacheModel insights;

  const _Header({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data-driven insights from your leads',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.primaryTintLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            insights.periodLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryLight,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 2x2 category grid ─────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final InsightsCacheModel insights;

  const _CategoryGrid({required this.insights});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.1,
      children: [
        _CategoryCard(
          label: 'Top Area',
          icon: Icons.location_on_rounded,
          data: insights.topArea,
        ),
        _CategoryCard(
          label: 'Property Type',
          icon: Icons.home_rounded,
          data: insights.trendingPropertyType,
        ),
        _CategoryCard(
          label: 'Budget Range',
          icon: Icons.payments_rounded,
          data: insights.mostActiveBudgetRange,
        ),
        _CategoryCard(
          label: 'Demand',
          icon: Icons.trending_up_rounded,
          data: insights.hottestDemandCategory,
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final InsightsCategoryData? data;

  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTintLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primaryLight, size: 18),
              ),
              if (data?.changePct != null)
                ChangeBadge(changePct: data!.changePct!),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 2),
          if (data == null || data!.name.isEmpty)
            const Text(
              'No data',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            )
          else ...[
            Text(
              data!.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${data!.count} ${data!.count == 1 ? "lead" : "leads"}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Demand Trend chart ─────────────────────────────────────────────────────────

class _DemandTrendSection extends StatelessWidget {
  final List<DemandPoint> points;

  const _DemandTrendSection({required this.points});

  static const _dayAbbr = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final maxY = points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    // Ensure y-axis top is at least 1 so an all-zero week still renders.
    final topY = (maxY < 1 ? 1 : maxY).toDouble();

    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i].count.toDouble()),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Demand Trend',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 180,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceAltLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: 0,
              maxY: topY + 1,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: topY <= 4 ? 1 : null,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value != value.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondaryLight,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value != value.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      final idx = value.toInt();
                      if (idx < 0 || idx >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final weekday = points[idx].date.weekday;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _dayAbbr[weekday],
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: AppColors.primaryLight,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, pct, bar, idx) =>
                        FlDotCirclePainter(
                      radius: 3.5,
                      color: AppColors.primaryLight,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primaryLight.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
