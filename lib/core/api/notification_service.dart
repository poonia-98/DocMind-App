

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;


class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
  if (_initialized) return;

  tzdata.initializeTimeZones(); // 🔥 REQUIRED

  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await _notificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: _onNotificationTapped,
  );

  _initialized = true;
}


  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - navigate to relevant screen
    print('Notification tapped: ${response.payload}');
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Schedule a notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await _notificationsPlugin.zonedSchedule(
  id,
  title,
  body,
  tz.TZDateTime.from(scheduledDate, tz.local),
  const NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders_channel',
      'Reminders',
      channelDescription: 'Notifications for obligations and reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  ),
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
  payload: payload,
);

  }

  /// Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'general_channel',
      'General',
      channelDescription: 'General notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, details, payload: payload);
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Schedule notifications for all reminders
  Future<void> scheduleAllReminders() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Get all pending reminders
      final reminders = await Supabase.instance.client
          .from('reminders')
          .select('*, obligations(title, due_date)')
          .eq('user_id', userId)
          .eq('sent', false)
          .gte('remind_at', DateTime.now().toIso8601String());

      // Schedule each reminder
      for (var reminder in reminders) {
        final remindAt = DateTime.parse(reminder['remind_at']);
        final obligation = reminder['obligations'];
        
        if (remindAt.isAfter(DateTime.now())) {
          await scheduleNotification(
            id: reminder['id'],
            title: 'Reminder: ${obligation['title']}',
            body: 'Due on ${_formatDate(obligation['due_date'])}',
            scheduledDate: remindAt,
            payload: 'obligation_${reminder['obligation_id']}',
          );
        }
      }
    } catch (e) {
      print('Failed to schedule reminders: $e');
    }
  }

  /// Schedule notifications for expiring entities
  Future<void> scheduleExpiryNotifications() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final entities = await Supabase.instance.client
          .from('life_entities')
          .select()
          .eq('user_id', userId);

      final now = DateTime.now();

      for (var entity in entities) {
        final expiryDateStr = entity['metadata']?['expiry_date'];
        if (expiryDateStr == null) continue;

        try {
          final expiryDate = DateTime.parse(expiryDateStr);
          final daysUntil = expiryDate.difference(now).inDays;

          // Schedule notifications at 30, 7, 3, and 1 day before expiry
          final notificationDays = [30, 7, 3, 1];
          
          for (var days in notificationDays) {
            if (daysUntil == days) {
              final notificationDate = DateTime(
                now.year,
                now.month,
                now.day,
                9, // 9 AM
                0,
              );

              await scheduleNotification(
                id: entity['id'] * 100 + days, // Unique ID
                title: '${entity['name']} expiring soon',
                body: 'Expires in $days days',
                scheduledDate: notificationDate,
                payload: 'entity_${entity['id']}',
              );
            }
          }
        } catch (e) {
          print('Failed to parse expiry date for entity ${entity['id']}');
        }
      }
    } catch (e) {
      print('Failed to schedule expiry notifications: $e');
    }
  }

  /// Reschedule all notifications (call after settings change)
  Future<void> rescheduleAll() async {
    await cancelAllNotifications();
    await scheduleAllReminders();
    await scheduleExpiryNotifications();
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      final months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return date;
    }
  }
}

