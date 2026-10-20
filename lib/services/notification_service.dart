import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('requestPermissions error: $e');
      return false;
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    try {
      await init();
      const androidDetails = AndroidNotificationDetails(
        'drivemate_channel',
        'DriveMate Reminders',
        channelDescription: 'Pengingat servis dan jadwal kendaraan DriveMate',
        importance: Importance.max,
        priority: Priority.high,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }
}
