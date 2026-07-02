class FollowUpModel {
  final String id;
  final String leadId;
  final String agentId;
  final String taskDescription;
  final DateTime dueAt;
  final String priority;
  final DateTime? completedAt;
  final DateTime? lastRemindedAt;
  final DateTime createdAt;

  // Populated only when reading from the follow_ups_with_status view.
  // Values: 'overdue', 'due_today', 'upcoming', 'completed'.
  final String? derivedStatus;

  // Joined from leads — only present when reading from the view.
  final String? leadName;
  final String? leadArea;

  const FollowUpModel({
    required this.id,
    required this.leadId,
    required this.agentId,
    required this.taskDescription,
    required this.dueAt,
    required this.priority,
    this.completedAt,
    this.lastRemindedAt,
    required this.createdAt,
    this.derivedStatus,
    this.leadName,
    this.leadArea,
  });

  factory FollowUpModel.fromJson(Map<String, dynamic> json) => FollowUpModel(
        id: json['id'] as String,
        leadId: json['lead_id'] as String,
        agentId: json['agent_id'] as String,
        taskDescription: json['task_description'] as String,
        dueAt: DateTime.parse(json['due_at'] as String),
        priority: json['priority'] as String? ?? 'warm',
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        lastRemindedAt: json['last_reminded_at'] != null
            ? DateTime.parse(json['last_reminded_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        derivedStatus: json['derived_status'] as String?,
        leadName: json['lead_name'] as String?,
        leadArea: json['lead_area'] as String?,
      );
}
