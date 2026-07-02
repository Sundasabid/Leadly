import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../leads/data/leads_repository.dart';
import '../../../leads/domain/models/lead_model.dart';

class DashboardStats {
  final int totalLeads;
  final int hotLeads;
  final int warmLeads;
  final int newThisWeek;
  final List<LeadModel> recentLeads;

  const DashboardStats({
    required this.totalLeads,
    required this.hotLeads,
    required this.warmLeads,
    required this.newThisWeek,
    required this.recentLeads,
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final leads = await ref.read(leadsRepositoryProvider).fetchLeads();
  final weekAgo = DateTime.now().subtract(const Duration(days: 7));
  return DashboardStats(
    totalLeads: leads.length,
    hotLeads: leads.where((l) => l.status == kStatusHot).length,
    warmLeads: leads.where((l) => l.status == kStatusWarm).length,
    newThisWeek:
        leads.where((l) => l.createdAt.isAfter(weekAgo)).length,
    recentLeads: leads.take(3).toList(),
  );
});
