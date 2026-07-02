import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/follow_up_model.dart';

class FollowUpRepository {
  final _client = Supabase.instance.client;

  String get _uid => _client.auth.currentUser!.id;

  /// Maps a lead's status to a follow-up priority value.
  /// hot→hot, cold→cold, everything else (new/warm/done)→warm.
  static String priorityFromLeadStatus(String leadStatus) =>
      switch (leadStatus) {
        'hot' => 'hot',
        'cold' => 'cold',
        _ => 'warm',
      };

  /// Inserts a new follow-up for [leadId] due at [dueAt].
  /// [taskDescription] falls back to "Follow up" if not provided,
  /// satisfying the NOT NULL constraint without forcing UI input.
  /// [leadStatus] is mapped to priority so the follow-up reflects the
  /// lead's current urgency instead of always defaulting to 'warm'.
  Future<void> createFollowUp({
    required String leadId,
    required DateTime dueAt,
    required String leadStatus,
    String? taskDescription,
  }) async {
    await _client.from('follow_ups').insert({
      'lead_id': leadId,
      'agent_id': _uid,
      'task_description': taskDescription?.trim().isEmpty ?? true
          ? 'Follow up'
          : taskDescription!.trim(),
      'due_at': dueAt.toUtc().toIso8601String(),
      'priority': priorityFromLeadStatus(leadStatus),
    });
  }

  /// Queries the follow_ups_with_status view.
  /// Pass [derivedStatus] to filter to one tab ('overdue', 'due_today',
  /// 'upcoming', 'completed'). Null fetches all rows.
  Future<List<FollowUpModel>> fetchFollowUps({String? derivedStatus}) async {
    var query = _client
        .from('follow_ups_with_status')
        .select()
        .eq('agent_id', _uid);

    if (derivedStatus != null) {
      query = query.eq('derived_status', derivedStatus);
    }

    final rows = await query.order('due_at', ascending: true);
    return (rows as List)
        .map((r) => FollowUpModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Returns the soonest pending (completed_at is null) follow-up for
  /// [leadId], or null if none exists. Used by ScheduleFollowUpSheet to
  /// warn the agent before creating a duplicate pending follow-up.
  Future<FollowUpModel?> fetchPendingFollowUpForLead(String leadId) async {
    final rows = await _client
        .from('follow_ups')
        .select()
        .eq('lead_id', leadId)
        .eq('agent_id', _uid)
        .isFilter('completed_at', null)
        .order('due_at', ascending: true)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return FollowUpModel.fromJson(rows.first);
  }

  /// Sets completed_at = now() on the base table.
  Future<void> markComplete(String followUpId) async {
    await _client
        .from('follow_ups')
        .update({'completed_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', followUpId)
        .eq('agent_id', _uid);
  }
}

final followUpRepositoryProvider =
    Provider<FollowUpRepository>((ref) => FollowUpRepository());
