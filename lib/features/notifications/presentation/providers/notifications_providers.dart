import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/notifications_repository.dart';
import '../../domain/models/notification_model.dart';

/// Full notifications list, newest first.
/// Invalidating this provider refreshes both the screen list and
/// unreadCountProvider — one call keeps the badge and list in sync.
final notificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) {
  return ref.read(notificationsRepositoryProvider).fetchNotifications();
});

/// Unread count derived from notificationsProvider — no separate DB query.
/// Returns 0 while loading or on error so the badge stays hidden.
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
