import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/follow_up_repository.dart';
import '../../domain/models/follow_up_model.dart';

/// Fetches all follow-ups for the current agent (no status filter).
/// Tab content and badge counts are computed client-side from this
/// single list so the whole screen refreshes with one invalidation.
final followUpsProvider = FutureProvider<List<FollowUpModel>>((ref) {
  return ref.read(followUpRepositoryProvider).fetchFollowUps();
});
