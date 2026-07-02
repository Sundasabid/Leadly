import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/leads_repository.dart';
import '../../domain/models/lead_model.dart';

/// Current filter/search/sort state for the Leads list screen.
final leadsFilterProvider = StateProvider<LeadsFilter>(
  (ref) => const LeadsFilter(),
);

/// Fetches leads whenever the filter changes.
final leadsAsyncProvider = FutureProvider<List<LeadModel>>((ref) {
  final filter = ref.watch(leadsFilterProvider);
  return ref.read(leadsRepositoryProvider).fetchLeads(filter: filter);
});

/// Fetches a single lead by ID — used by S12 Lead Detail.
final leadDetailProvider =
    FutureProvider.family<LeadModel?, String>((ref, leadId) {
  return ref.read(leadsRepositoryProvider).fetchLead(leadId);
});
