class LeadModel {
  final String id;
  final String agentId;
  final String name;
  final String phone;
  final double? budgetPkr;
  final String areaSociety;
  final String propertyType;
  final String intent;
  final String timeline;
  final String? notes;
  final String status;
  final String source;
  final double? extractionConfidence;
  final String? linkedDuplicateOf;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LeadModel({
    required this.id,
    required this.agentId,
    required this.name,
    required this.phone,
    this.budgetPkr,
    required this.areaSociety,
    required this.propertyType,
    required this.intent,
    required this.timeline,
    this.notes,
    required this.status,
    required this.source,
    this.extractionConfidence,
    this.linkedDuplicateOf,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) => LeadModel(
        id: json['id'] as String,
        agentId: json['agent_id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        budgetPkr: (json['budget_pkr'] as num?)?.toDouble(),
        areaSociety: json['area_society'] as String,
        propertyType: json['property_type'] as String,
        intent: json['intent'] as String,
        timeline: json['timeline'] as String,
        notes: json['notes'] as String?,
        status: json['status'] as String? ?? 'new',
        source: json['source'] as String? ?? 'manual',
        extractionConfidence:
            (json['extraction_confidence'] as num?)?.toDouble(),
        linkedDuplicateOf: json['linked_duplicate_of'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toInsertJson(String agentId) => {
        'agent_id': agentId,
        'name': name,
        'phone': phone,
        if (budgetPkr != null) 'budget_pkr': budgetPkr,
        'area_society': areaSociety,
        'property_type': propertyType,
        'intent': intent,
        'timeline': timeline,
        if (notes != null) 'notes': notes,
        'status': status,
        'source': source,
        if (extractionConfidence != null)
          'extraction_confidence': extractionConfidence,
        if (linkedDuplicateOf != null)
          'linked_duplicate_of': linkedDuplicateOf,
      };
}

// Property types
const kPropertyTypes = [
  'House',
  'Plot',
  'Apartment',
  'Commercial',
  'Other',
];

// Intent options
const kIntentOptions = ['Buy', 'Rent', 'Invest'];

// Timeline options
const kTimelineOptions = [
  'Immediate',
  'Within 1 Month',
  '1–3 Months',
  '3–6 Months',
  '6+ Months',
];

// Status values
const kStatusNew = 'new';
const kStatusHot = 'hot';
const kStatusWarm = 'warm';
const kStatusCold = 'cold';
const kStatusDone = 'done';
