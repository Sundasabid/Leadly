import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/insights_repository.dart';

// Fetches the agent's most recent insights_cache row.
// Errors are caught silently and return null so the dashboard
// never shows an error banner for this non-critical feature.
final insightsCacheProvider =
    FutureProvider.autoDispose<InsightsCacheModel?>((ref) async {
  try {
    return await ref.read(insightsRepositoryProvider).fetchLatest();
  } catch (e, st) {
    debugPrint('Insights fetch failed silently: $e\n$st');
    return null;
  }
});

// All distinct weeks this agent has insights for, newest first.
final availableWeeksProvider =
    FutureProvider.autoDispose<List<DateTime>>((ref) async {
  try {
    return await ref.read(insightsRepositoryProvider).fetchAvailableWeeks();
  } catch (e, st) {
    debugPrint('Available weeks fetch failed: $e\n$st');
    return [];
  }
});

// Insights for a specific week identified by its period_start date.
final insightsByPeriodProvider =
    FutureProvider.family<InsightsCacheModel?, DateTime>(
        (ref, periodStart) async {
  try {
    return await ref
        .read(insightsRepositoryProvider)
        .fetchByPeriod(periodStart);
  } catch (e, st) {
    debugPrint('Insights by period fetch failed: $e\n$st');
    return null;
  }
});
