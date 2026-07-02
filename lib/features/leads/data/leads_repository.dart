import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/lead_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Filter / sort types
// fetchLeads() accepts a null filter (= all leads, default sort).
// Steps 5-6 extend filtering by passing populated LeadsFilter instances.
// ─────────────────────────────────────────────────────────────────────────────

enum LeadsSortOrder {
  newestFirst,
  oldestFirst,
  byBudgetHighLow,
  byNameAZ,
}

class LeadsFilter {
  final String? status;
  final String? searchQuery;
  final LeadsSortOrder sortOrder;

  const LeadsFilter({
    this.status,
    this.searchQuery,
    this.sortOrder = LeadsSortOrder.newestFirst,
  });

  LeadsFilter copyWith({
    String? status,
    String? searchQuery,
    LeadsSortOrder? sortOrder,
    bool clearStatus = false,
    bool clearSearch = false,
  }) =>
      LeadsFilter(
        status: clearStatus ? null : (status ?? this.status),
        searchQuery:
            clearSearch ? null : (searchQuery ?? this.searchQuery),
        sortOrder: sortOrder ?? this.sortOrder,
      );

  bool get hasActiveFilter =>
      status != null || (searchQuery?.isNotEmpty ?? false);
}

// ─────────────────────────────────────────────────────────────────────────────
// LeadInput - data the creation form provides.
// source defaults to 'manual'; voice-extracted leads pass source: 'voice'
// and extractionConfidence. All existing call sites are unaffected.
// ─────────────────────────────────────────────────────────────────────────────

class LeadInput {
  final String name;
  final String phone;
  final double? budgetPkr;
  final String areaSociety;
  final String propertyType; // display value, e.g. 'House'
  final String intent;       // display value, e.g. 'Buy'
  final String timeline;     // display value, e.g. 'Within 1 Month'
  final String? notes;
  final String source;
  final double? extractionConfidence;

  const LeadInput({
    required this.name,
    required this.phone,
    this.budgetPkr,
    required this.areaSociety,
    required this.propertyType,
    required this.intent,
    required this.timeline,
    this.notes,
    this.source = 'manual',
    this.extractionConfidence,
  });

  // Converts display-friendly values from the form dropdowns into the
  // lowercase / underscore-separated values the DB check constraints expect.
  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'phone': phone.trim(),
        if (budgetPkr != null) 'budget_pkr': budgetPkr,
        'area_society': areaSociety.trim(),
        'property_type': propertyType.toLowerCase(),
        'intent': intent.toLowerCase(),
        'timeline': _timelineDbValue(timeline),
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
        'source': source,
        if (extractionConfidence != null)
          'extraction_confidence': extractionConfidence,
      };

  // Single source of truth for display <-> DB timeline mapping.
  static const Map<String, String> _kTimelineMap = {
    'Immediate': 'immediate',
    'Within 1 Month': 'within_1_month',
    '1–3 Months': '1_3_months',
    '3–6 Months': '3_6_months',
    '6+ Months': '6_plus_months',
  };

  static String _timelineDbValue(String display) =>
      _kTimelineMap[display] ??
      display.toLowerCase().replaceAll(' ', '_').replaceAll('+', 'plus');

  // DB → display converters for pre-filling the review form.
  // All accept null and return null so missing extracted fields leave the
  // corresponding form field empty rather than throwing.

  static String? timelineFromDb(String? dbValue) {
    if (dbValue == null) return null;
    for (final entry in _kTimelineMap.entries) {
      if (entry.value == dbValue) return entry.key;
    }
    return null;
  }

  static String? propertyTypeFromDb(String? dbValue) {
    if (dbValue == null) return null;
    for (final t in kPropertyTypes) {
      if (t.toLowerCase() == dbValue) return t;
    }
    return null;
  }

  static String? intentFromDb(String? dbValue) {
    if (dbValue == null) return null;
    for (final i in kIntentOptions) {
      if (i.toLowerCase() == dbValue) return i;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LeadsRepository
// All Supabase calls for the leads feature go through here.
// Screens and providers never import supabase_flutter directly.
// ─────────────────────────────────────────────────────────────────────────────

class LeadsRepository {
  final SupabaseClient _client;

  LeadsRepository(this._client);

  // Fetch the agent's leads with optional filter, search, and sort.
  Future<List<LeadModel>> fetchLeads({LeadsFilter? filter}) async {
    var query = _client.from('leads').select();

    if (filter?.status != null) {
      query = query.eq('status', filter!.status!);
    }

    final q = filter?.searchQuery?.trim();
    if (q != null && q.isNotEmpty) {
      // OR across the three text columns agents are most likely to search by.
      query = query.or(
        'name.ilike.%$q%,phone.ilike.%$q%,area_society.ilike.%$q%',
      );
    }

    final rows = await switch (filter?.sortOrder ?? LeadsSortOrder.newestFirst) {
      LeadsSortOrder.newestFirst =>
        query.order('created_at', ascending: false),
      LeadsSortOrder.oldestFirst =>
        query.order('created_at', ascending: true),
      LeadsSortOrder.byBudgetHighLow =>
        query.order('budget_pkr', ascending: false, nullsFirst: false),
      LeadsSortOrder.byNameAZ =>
        query.order('name', ascending: true),
    };

    return rows.map(LeadModel.fromJson).toList();
  }

  // Fetch a single lead by ID - used by S12 Lead Detail.
  Future<LeadModel?> fetchLead(String leadId) async {
    final row = await _client
        .from('leads')
        .select()
        .eq('id', leadId)
        .maybeSingle();
    return row == null ? null : LeadModel.fromJson(row);
  }

  // Check for a duplicate phone number before saving - used by S10.
  // Returns the most recent existing lead with that phone, or null if none.
  // Uses limit(1) instead of maybeSingle() because "Continue Anyway" (S10)
  // allows multiple leads to legitimately share a phone over time - maybeSingle()
  // would throw once a second duplicate already exists.
  Future<LeadModel?> findDuplicateByPhone(String phone) async {
    final rows = await _client
        .from('leads')
        .select()
        .eq('phone', phone.trim())
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : LeadModel.fromJson(rows.first);
  }

  // Create a new lead. Status defaults to 'new', source to 'manual' at DB level.
  // Returns the full created row (with server-assigned id and timestamps).
  Future<LeadModel> createLead(LeadInput input) async {
    final agentId = _client.auth.currentUser!.id;
    final row = await _client
        .from('leads')
        .insert({'agent_id': agentId, ...input.toMap()})
        .select()
        .single();
    return LeadModel.fromJson(row);
  }

  // Create a lead that the agent explicitly saved after a duplicate warning.
  // The linked_duplicate_of FK records which existing lead it was flagged against.
  Future<LeadModel> createLeadAsDuplicate(
    LeadInput input,
    String existingLeadId,
  ) async {
    final agentId = _client.auth.currentUser!.id;
    final row = await _client
        .from('leads')
        .insert({
          'agent_id': agentId,
          ...input.toMap(),
          'linked_duplicate_of': existingLeadId,
        })
        .select()
        .single();
    return LeadModel.fromJson(row);
  }

  // Update a lead's status - called from S12 Lead Detail.
  Future<LeadModel> updateStatus(String leadId, String newStatus) async {
    final row = await _client
        .from('leads')
        .update({'status': newStatus})
        .eq('id', leadId)
        .select()
        .single();
    return LeadModel.fromJson(row);
  }

  // Update editable lead fields - called from S12 edit flow (later step).
  Future<LeadModel> updateLead(String leadId, LeadInput input) async {
    final row = await _client
        .from('leads')
        .update(input.toMap()) // agent_id is not updated
        .eq('id', leadId)
        .select()
        .single();
    return LeadModel.fromJson(row);
  }

  // Delete a lead by ID - needed for Steps 5-6 (list swipe-to-delete / bulk).
  Future<void> deleteLead(String leadId) async {
    await _client.from('leads').delete().eq('id', leadId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

final leadsRepositoryProvider = Provider<LeadsRepository>((ref) {
  return LeadsRepository(Supabase.instance.client);
});
