import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/change_badge.dart';
import '../../data/insights_repository.dart';
import '../providers/insights_providers.dart';

class WeeklyInsightsScreen extends ConsumerStatefulWidget {
  const WeeklyInsightsScreen({super.key});

  @override
  ConsumerState<WeeklyInsightsScreen> createState() =>
      _WeeklyInsightsScreenState();
}

class _WeeklyInsightsScreenState
    extends ConsumerState<WeeklyInsightsScreen> {
  int _selectedIndex = 0;
  List<DateTime> _weeks = const [];
  InsightsCacheModel? _insights;
  bool _loading = true;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final weeks = await ref.read(availableWeeksProvider.future);
      InsightsCacheModel? insights;
      if (weeks.isNotEmpty) {
        insights =
            await ref.read(insightsByPeriodProvider(weeks[0]).future);
      }
      if (!mounted) return;
      setState(() {
        _weeks = weeks;
        _insights = insights;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _navigateTo(int newIndex) async {
    if (newIndex < 0 ||
        newIndex >= _weeks.length ||
        _navigating) {
      return;
    }
    setState(() {
      _selectedIndex = newIndex;
      _navigating = true;
    });
    try {
      final insights =
          await ref.read(insightsByPeriodProvider(_weeks[newIndex]).future);
      if (!mounted) return;
      setState(() {
        _insights = insights;
        _navigating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 80;
    final canGoPrev = _weeks.length > 1 && _selectedIndex < _weeks.length - 1;
    final canGoNext = _weeks.length > 1 && _selectedIndex > 0;
    final showNav = _weeks.length > 1;

    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Navy header ──────────────────────────────────────────────
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
                  Text(
                    'Weekly Insights',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // ── White content card ───────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                ),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryLight),
                      )
                    : (_weeks.isEmpty || _insights == null)
                        ? const _EmptyState()
                        : _navigating
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primaryLight),
                              )
                            : SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.lg,
                                    AppSpacing.lg,
                                    bottomPad),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _NavHeader(
                                      periodLabel: _insights!.periodLabel,
                                      showNav: showNav,
                                      canGoPrev: canGoPrev,
                                      canGoNext: canGoNext,
                                      onPrev: canGoPrev
                                          ? () => _navigateTo(
                                              _selectedIndex + 1)
                                          : null,
                                      onNext: canGoNext
                                          ? () => _navigateTo(
                                              _selectedIndex - 1)
                                          : null,
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                    _CategoryGrid(insights: _insights!),
                                    if (_insights!.demandTrend.isNotEmpty) ...[
                                      const SizedBox(height: AppSpacing.xl),
                                      _DemandTrendSection(
                                          points: _insights!.demandTrend),
                                    ],
                                  ],
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

// ── Nav header ────────────────────────────────────────────────────────────────

class _NavHeader extends StatelessWidget {
  final String periodLabel;
  final bool showNav;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _NavHeader({
    required this.periodLabel,
    required this.showNav,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data-driven insights from your leads',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showNav)
              _NavArrow(
                icon: LucideIcons.chevronLeft,
                enabled: canGoPrev,
                onTap: onPrev,
              ),
            if (showNav) const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                periodLabel,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            if (showNav) const SizedBox(width: AppSpacing.xs),
            if (showNav)
              _NavArrow(
                icon: LucideIcons.chevronRight,
                enabled: canGoNext,
                onTap: onNext,
              ),
          ],
        ),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Icon(
        icon,
        size: 22,
        color: enabled
            ? AppColors.primaryLight
            : AppColors.textDisabledLight,
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

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
            const Icon(
              LucideIcons.barChart2,
              color: AppColors.primaryLight,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No insights yet',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
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

// ── 2x2 category grid ─────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final InsightsCacheModel insights;

  const _CategoryGrid({required this.insights});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CategoryCard(label: 'Top Area', icon: LucideIcons.mapPin, data: insights.topArea),
      _CategoryCard(label: 'Property Type', icon: LucideIcons.building2, data: insights.trendingPropertyType),
      _CategoryCard(label: 'Budget Range', icon: LucideIcons.wallet, data: insights.mostActiveBudgetRange),
      _CategoryCard(label: 'Demand', icon: LucideIcons.trendingUp, data: insights.hottestDemandCategory),
    ];
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: cards[1]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: cards[3]),
            ],
          ),
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
    final hasData = data != null && data!.count > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryTintLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
          left: const BorderSide(color: AppColors.primaryLight, width: 3),
          top: const BorderSide(color: Color(0xFFBFDBFE)),
          right: const BorderSide(color: Color(0xFFBFDBFE)),
          bottom: const BorderSide(color: Color(0xFFBFDBFE)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primaryLight, size: 24),
              const Spacer(),
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
          if (!hasData)
            const Text(
              'No leads this week',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryLight,
              ),
            )
          else ...[
            Text(
              data!.name.isNotEmpty ? data!.name : '-',
              style: const TextStyle(
                fontSize: 14,
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

// ── Demand trend chart ────────────────────────────────────────────────────────

class _DemandTrendSection extends StatelessWidget {
  final List<DemandPoint> points;

  const _DemandTrendSection({required this.points});

  static const _dayAbbr = [
    '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  Widget build(BuildContext context) {
    final maxY = points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final topY = (maxY < 1 ? 1 : maxY).toDouble();

    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i].count.toDouble()),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demand Trend',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: 0,
                maxY: topY + 1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.borderLight.withValues(alpha: 0.6),
                    strokeWidth: 1,
                  ),
                ),
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
                          style: GoogleFonts.poppins(
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
                            style: GoogleFonts.poppins(
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
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primaryLight.withValues(alpha: 0.20),
                          AppColors.primaryLight.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
