import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Called by the OS when a notification arrives while the app is terminated.
// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  // No UI work here — Flutter is not running. FCM system tray handles display.
  debugPrint('[FCM] Background message: ${message.messageId}');
}

// ── Local notifications setup ─────────────────────────────────────────────────

const _channelId = 'propex_notifications';
const _channelName = 'Propex Notifications';
const _channelDesc = 'Lead follow-up reminders and weekly insights';

final _localNotifications = FlutterLocalNotificationsPlugin();

Future<void> _initLocalNotifications() async {
  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await _localNotifications.initialize(
    const InitializationSettings(android: androidSettings),
    onDidReceiveNotificationResponse: _onNotificationTap,
  );

  // Create the high-priority channel once (idempotent on subsequent calls).
  const channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.high,
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

void _onNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null) return;
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    _navigateFromData(data);
  } catch (_) {}
}

// ── Navigation helper ─────────────────────────────────────────────────────────

GoRouter? _router;

/// Call this from app.dart after the router is created so notification taps
/// can navigate. Safe to call on every build — GoRouter is the same instance.
void setFCMRouter(GoRouter router) => _router = router;

void _navigateFromData(Map<String, dynamic> data) {
  final router = _router;
  if (router == null) return;
  final leadId = data['related_lead_id'] as String?;
  if (leadId != null && leadId.isNotEmpty) {
    router.push('/leads/$leadId');
  } else {
    router.go('/notifications');
  }
}

// ── FCM Service ───────────────────────────────────────────────────────────────

class FCMService {
  static final _messaging = FirebaseMessaging.instance;

  /// Full initialisation: permissions, local notifications, token, listeners.
  /// Call once from main.dart after Firebase.initializeApp().
  static Future<void> init() async {
    await _initLocalNotifications();
    await _requestPermission();

    // Register the background handler before any streams are listened to.
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    // Show heads-up banner when app is in the foreground.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen for foreground messages and show a local notification.
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Handle notification tap when app is in background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigateFromData(message.data);
    });

    // Handle notification tap when app was terminated.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Delay so the router has time to mount.
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateFromData(initial.data);
      });
    }

    // Save initial token and refresh listener.
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);

    _messaging.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
        '[FCM] Permission: ${settings.authorizationStatus.name}');
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Upserts the FCM token into `device_tokens` for the current user.
  /// Safe to call multiple times — ON CONFLICT updates the existing row.
  static Future<void> _saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('device_tokens').upsert(
        {
          'agent_id': user.id,
          'token': token,
          'platform': 'android',
        },
        onConflict: 'token',
      );
      debugPrint('[FCM] Token saved');
    } on PostgrestException catch (e) {
      debugPrint('[FCM] Token save failed: ${e.message}');
    }
  }

  /// Delete the stored token on sign-out so stale tokens aren't used.
  static Future<void> deleteToken() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('token', token);
      await _messaging.deleteToken();
      debugPrint('[FCM] Token deleted');
    } catch (e) {
      debugPrint('[FCM] Token delete failed: $e');
    }
  }
}
