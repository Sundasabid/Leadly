class NotificationModel {
  final String id;
  final String agentId;
  final String type;
  final String title;
  final String message;
  final String? relatedLeadId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.agentId,
    required this.type,
    required this.title,
    required this.message,
    this.relatedLeadId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        agentId: json['agent_id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        relatedLeadId: json['related_lead_id'] as String?,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
