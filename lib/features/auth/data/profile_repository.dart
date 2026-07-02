import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/profile_model.dart';

class ProfileRepository {
  final _client = Supabase.instance.client;

  Future<ProfileModel?> fetchProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }

  Future<void> updateProfile({
    required String name,
    required String agencyName,
    required String phoneNumber,
    String? city,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    await _client.from('profiles').update({
      'name': name,
      'agency_name': agencyName,
      'phone_number': phoneNumber,
      'city': city,
    }).eq('id', user.id);
  }

  Future<void> updateReminderInterval(int hours) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    await _client.from('profiles').update({
      'reminder_interval_hours': hours,
    }).eq('id', user.id);
  }

  Future<void> updateNotificationPreferences({
    required bool notifyHotLeads,
    required bool notifyFollowUpDue,
    required bool notifyWeeklyInsight,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    await _client.from('profiles').update({
      'notify_hot_leads': notifyHotLeads,
      'notify_follow_up_due': notifyFollowUpDue,
      'notify_weekly_insight': notifyWeeklyInsight,
    }).eq('id', user.id);
  }

}

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository());
