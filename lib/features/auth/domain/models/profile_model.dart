class ProfileModel {
  final String id;
  final String name;
  final String agencyName;
  final String? city;
  final String? phoneNumber;
  final String? email;
  final String? avatarUrl;
  final String themePreference;
  final int reminderIntervalHours;
  final bool notifyHotLeads;
  final bool notifyFollowUpDue;
  final bool notifyWeeklyInsight;
  final DateTime createdAt;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.agencyName,
    this.city,
    this.phoneNumber,
    this.email,
    this.avatarUrl,
    required this.themePreference,
    required this.reminderIntervalHours,
    required this.notifyHotLeads,
    required this.notifyFollowUpDue,
    required this.notifyWeeklyInsight,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json['id'] as String,
        name: json['name'] as String,
        agencyName: json['agency_name'] as String,
        city: json['city'] as String?,
        phoneNumber: json['phone_number'] as String?,
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        themePreference: json['theme_preference'] as String? ?? 'light',
        reminderIntervalHours:
            json['reminder_interval_hours'] as int? ?? 12,
        notifyHotLeads: json['notify_hot_leads'] as bool? ?? true,
        notifyFollowUpDue: json['notify_follow_up_due'] as bool? ?? true,
        notifyWeeklyInsight: json['notify_weekly_insight'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'agency_name': agencyName,
        if (city != null) 'city': city,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'theme_preference': themePreference,
        'reminder_interval_hours': reminderIntervalHours,
        'notify_hot_leads': notifyHotLeads,
        'notify_follow_up_due': notifyFollowUpDue,
        'notify_weekly_insight': notifyWeeklyInsight,
      };

  ProfileModel copyWith({
    String? name,
    String? agencyName,
    String? city,
    String? phoneNumber,
    String? email,
    String? avatarUrl,
    String? themePreference,
    int? reminderIntervalHours,
    bool? notifyHotLeads,
    bool? notifyFollowUpDue,
    bool? notifyWeeklyInsight,
  }) =>
      ProfileModel(
        id: id,
        name: name ?? this.name,
        agencyName: agencyName ?? this.agencyName,
        city: city ?? this.city,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        themePreference: themePreference ?? this.themePreference,
        reminderIntervalHours:
            reminderIntervalHours ?? this.reminderIntervalHours,
        notifyHotLeads: notifyHotLeads ?? this.notifyHotLeads,
        notifyFollowUpDue: notifyFollowUpDue ?? this.notifyFollowUpDue,
        notifyWeeklyInsight: notifyWeeklyInsight ?? this.notifyWeeklyInsight,
        createdAt: createdAt,
      );
}
