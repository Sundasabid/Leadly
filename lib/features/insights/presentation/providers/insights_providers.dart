import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/insights_repository.dart';

// Fetches the agent's most recent insights_cache row.
// Errors are caught silently and return null so the dashboard
// never shows an error banner for this non-critical feature.
final insightsCacheProvider =
    FutureProvider<InsightsCacheModel?>((ref) async {
  try {
    return await ref.read(insightsRepositoryProvider).fetchLatest();
  } catch (e, st) {
    debugPrint('Insights fetch failed silently: $e\n$st');
    return null;
  }
});
