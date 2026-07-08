import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class InsightsCategoryData {
  final String name;
  final int count;
  final double? changePct; // null = first week, no prior comparison

  const InsightsCategoryData({
    required this.name,
    required this.count,
    this.changePct,
  });

  factory InsightsCategoryData.fromJson(Map<String, dynamic> json) {
    return InsightsCategoryData(
      name: (json['name'] as String?) ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      changePct: json['change_pct'] == null
          ? null
          : (json['change_pct'] as num).toDouble(),
    );
  }
}

class DemandPoint {
  final DateTime date;
  final int count;
  const DemandPoint({required this.date, required this.count});
}

class InsightsCacheModel {
  final DateTime periodStart;
  final DateTime periodEnd;
  final InsightsCategoryData? topArea;
  final InsightsCategoryData? trendingPropertyType;
  final InsightsCategoryData? mostActiveBudgetRange;
  final InsightsCategoryData? hottestDemandCategory;
  final List<DemandPoint> demandTrend;

  const InsightsCacheModel({
    required this.periodStart,
    required this.periodEnd,
    this.topArea,
    this.trendingPropertyType,
    this.mostActiveBudgetRange,
    this.hottestDemandCategory,
    this.demandTrend = const [],
  });

  factory InsightsCacheModel.fromJson(Map<String, dynamic> json) {
    InsightsCategoryData? parseCategory(String key) {
      final v = json[key];
      if (v == null) return null;
      return InsightsCategoryData.fromJson(Map<String, dynamic>.from(v as Map));
    }

    final rawTrend = json['demand_trend'];
    final demandTrend = <DemandPoint>[];
    if (rawTrend is List) {
      for (final item in rawTrend) {
        if (item is Map) {
          final d = item['date'] as String?;
          final c = item['count'];
          if (d != null) {
            demandTrend.add(DemandPoint(
              date: DateTime.parse(d),
              count: (c as num?)?.toInt() ?? 0,
            ));
          }
        }
      }
    }

    return InsightsCacheModel(
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      topArea: parseCategory('top_performing_area'),
      trendingPropertyType: parseCategory('trending_property_type'),
      mostActiveBudgetRange: parseCategory('most_active_budget_range'),
      hottestDemandCategory: parseCategory('hottest_demand_category'),
      demandTrend: demandTrend,
    );
  }

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // True if this row covers the most recently completed Mon-Sun week.
  // Sunday is treated as still in-progress (weekday==7 -> 7 days back) so the
  // last *complete* week always ended the previous Saturday night.
  bool get isFresh {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final daysBack = today.weekday == 7 ? 7 : today.weekday % 7;
    final lastCompletedSunday = todayDate.subtract(Duration(days: daysBack));
    final periodEndDate = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);
    return !periodEndDate.isBefore(lastCompletedSunday);
  }

  // "Jun 16-22" (same month) or "May 26 - Jun 1" (month boundary).
  String get periodLabel {
    if (periodStart.month == periodEnd.month) {
      return '${_months[periodStart.month]} ${periodStart.day}-${periodEnd.day}';
    }
    return '${_months[periodStart.month]} ${periodStart.day}'
        ' - ${_months[periodEnd.month]} ${periodEnd.day}';
  }

  // Picks the category with the highest absolute change_pct.
  // Null when all change_pct values are null (first week, no prior comparison).
  // Single source of truth shared by topInsightCategoryKey and aiInsightSentence.
  ({InsightsCategoryData data, String key})? get _topCandidate {
    final candidates = <({InsightsCategoryData data, String key})>[
      if (topArea != null && topArea!.changePct != null)
        (data: topArea!, key: 'area'),
      if (trendingPropertyType != null && trendingPropertyType!.changePct != null)
        (data: trendingPropertyType!, key: 'property'),
      if (mostActiveBudgetRange != null && mostActiveBudgetRange!.changePct != null)
        (data: mostActiveBudgetRange!, key: 'budget'),
      if (hottestDemandCategory != null && hottestDemandCategory!.changePct != null)
        (data: hottestDemandCategory!, key: 'intent'),
    ];
    if (candidates.isEmpty) return null;
    return candidates.reduce(
      (a, b) => a.data.changePct!.abs() >= b.data.changePct!.abs() ? a : b,
    );
  }

  // Key of the winning category: 'area' | 'property' | 'budget' | 'intent' | null.
  // Null means all change_pct values were null (first-week fallback sentence).
  String? get topInsightCategoryKey => _topCandidate?.key;

  // Returns the single-sentence AI insight summary for the dashboard card.
  // Uses present tense + "this week" for fresh data; past tense + "(Jun 16-22)"
  // for stale data — never claims "this week" when the row is from a prior week.
  String get aiInsightSentence {
    final best = _topCandidate;
    if (best == null) {
      return 'Your first weekly insights are ready - tap to explore.';
    }

    final fresh = isFresh;
    final pct = best.data.changePct!;
    final dir = pct >= 0 ? 'up' : 'down';
    final absPct = pct.abs();
    final pctStr = absPct == absPct.roundToDouble()
        ? '${absPct.round()}%'
        : '${absPct.toStringAsFixed(1)}%';
    final name = best.data.name;
    final qualifier = fresh ? 'this week' : '($periodLabel)';

    return switch (best.key) {
      'area'     => 'Demand in $name ${fresh ? "is" : "was"} $dir $pctStr $qualifier.',
      'property' => '${_cap(name)} demand ${fresh ? "is" : "was"} $dir $pctStr $qualifier.',
      'budget'   => '$name budget leads ${fresh ? "are" : "were"} $dir $pctStr $qualifier.',
      'intent'   => '${_cap(name)} leads ${fresh ? "are" : "were"} $dir $pctStr $qualifier.',
      _          => 'Your weekly insights are ready - tap to explore.',
    };
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Repository ────────────────────────────────────────────────────────────────

class InsightsRepository {
  final SupabaseClient _client;
  const InsightsRepository(this._client);

  Future<InsightsCacheModel?> fetchLatest() async {
    final row = await _client
        .from('insights_cache')
        .select()
        .order('period_start', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return InsightsCacheModel.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// Returns all period_start dates this agent has insights for, newest first.
  /// RLS restricts results to agent_id = auth.uid() — no explicit filter needed.
  Future<List<DateTime>> fetchAvailableWeeks() async {
    final rows = await _client
        .from('insights_cache')
        .select('period_start')
        .order('period_start', ascending: false);
    return (rows as List)
        .map((row) => DateTime.parse(row['period_start'] as String))
        .toList();
  }

  /// Fetches insights for the exact week starting on [periodStart].
  /// Returns null if no row exists for that date.
  Future<InsightsCacheModel?> fetchByPeriod(DateTime periodStart) async {
    final dateStr =
        '${periodStart.year.toString().padLeft(4, '0')}-'
        '${periodStart.month.toString().padLeft(2, '0')}-'
        '${periodStart.day.toString().padLeft(2, '0')}';
    final row = await _client
        .from('insights_cache')
        .select()
        .eq('period_start', dateStr)
        .maybeSingle();
    if (row == null) return null;
    return InsightsCacheModel.fromJson(Map<String, dynamic>.from(row as Map));
  }
}

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository(Supabase.instance.client);
});
