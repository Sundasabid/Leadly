import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/notification_model.dart';

class NotificationsRepository {
  final _client = Supabase.instance.client;

  String get _uid => _client.auth.currentUser!.id;

  Future<List<NotificationModel>> fetchNotifications() async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('agent_id', _uid)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => NotificationModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('agent_id', _uid);
  }

  Future<void> markAllAsRead() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('agent_id', _uid)
        .eq('is_read', false);
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) => NotificationsRepository());
