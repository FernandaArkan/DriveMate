import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../database/database_helper.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String channelId = 'drivemate_reminders';
  static const String channelName = 'Pengingat Servis DriveMate';
  static const String channelDescription =
      'Pengingat servis berkala, penggantian oli, dan perawatan kendaraan DriveMate';

  /// Callback opsional ketika notifikasi diklik pengguna
  Function(String? payload)? onNotificationClick;

  /// Inisialisasi Notification Plugin, Timezone lokal, dan Android Notification Channel
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Inisialisasi Timezone Database
      tz.initializeTimeZones();
      _configureLocalTimeZone();

      // 2. Pengaturan Inisialisasi Platform
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
          if (onNotificationClick != null) {
            onNotificationClick!(response.payload);
          }
        },
      );

      // 3. Buat Notification Channel Android secara eksplisit
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        const channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidImplementation.createNotificationChannel(channel);
      }

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully.');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Mengonfigurasi zona waktu lokal perangkat (WIB, WITA, WIT, atau matching offset)
  void _configureLocalTimeZone() {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;

      // Pemetaan cepat untuk zona waktu Indonesia
      if (offset.inHours == 7) {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
        return;
      } else if (offset.inHours == 8) {
        tz.setLocalLocation(tz.getLocation('Asia/Makassar'));
        return;
      } else if (offset.inHours == 9) {
        tz.setLocalLocation(tz.getLocation('Asia/Jayapura'));
        return;
      }

      // Cari lokasi yang memiliki offset UTC sama dengan perangkat saat ini
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == offset) {
          tz.setLocalLocation(location);
          return;
        }
      }

      // Fallback default Indonesia Barat (WIB)
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (e) {
      debugPrint('Failed to set local timezone: $e. Using default tz.local.');
    }
  }

  /// Memeriksa apakah izin notifikasi saat ini aktif/diizinkan oleh sistem
  Future<bool> areNotificationsEnabled() async {
    try {
      await init();
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final enabled = await androidImplementation.areNotificationsEnabled();
        return enabled ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('areNotificationsEnabled error: $e');
      return false;
    }
  }

  /// Meminta izin notifikasi runtime (Android 13+ POST_NOTIFICATIONS & iOS)
  Future<bool> requestPermissions() async {
    try {
      await init();
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted =
            await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }

      final darwinImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (darwinImplementation != null) {
        final granted = await darwinImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('requestPermissions error: $e');
      return false;
    }
  }

  /// Membuka halaman pengaturan notifikasi aplikasi di sistem OS
  Future<bool> openNotificationSettings() async {
    try {
      await init();
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final opened =
            await androidImplementation.openAppNotificationSettings();
        return opened ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('openNotificationSettings error: $e');
      return false;
    }
  }

  /// Meminta akses izin Exact Alarm jika diperlukan pengguna (Android 13/14+)
  Future<bool> requestExactAlarmsPermission() async {
    try {
      await init();
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted =
            await androidImplementation.requestExactAlarmsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('requestExactAlarmsPermission error: $e');
      return false;
    }
  }

  /// Mengirim notifikasi instan langsung (berguna untuk verifikasi channel notifikasi)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await init();

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
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
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing immediate notification: $e');
    }
  }

  /// Menjadwalkan notifikasi lokal di waktu tertentu (bekerja saat aplikasi di latar belakang atau ditutup)
  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    bool preferExact = false,
  }) async {
    try {
      await init();

      // Periksa izin notifikasi terlebih dahulu
      final isAllowed = await areNotificationsEnabled();
      if (!isAllowed) {
        debugPrint(
            'Peringatan: Izin notifikasi belum diberikan oleh pengguna.');
      }

      final tzNow = tz.TZDateTime.now(tz.local);
      var tzDateTime = tz.TZDateTime(
        tz.local,
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        scheduledDate.hour,
        scheduledDate.minute,
        scheduledDate.second,
      );

      // Jika waktu target sudah berlalu (misal keterlambatan input form beberapa detik),
      // jadwalkan 5 detik dari sekarang agar notifikasi tetap dapat dieksekusi.
      if (tzDateTime.isBefore(tzNow)) {
        if (tzNow.difference(tzDateTime).inSeconds < 120) {
          tzDateTime = tzNow.add(const Duration(seconds: 5));
        } else {
          debugPrint('Waktu pengingat sudah jauh berlalu: $tzDateTime');
          return false;
        }
      }

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      // Batalkan notifikasi lama dengan ID sama untuk mencegah notifikasi ganda
      await cancelNotification(id);

      // Secara default, gunakan inexactAllowWhileIdle untuk pengingat servis:
      // aman dari pembatasan Android 12-14+ tanpa izin special access exact alarm.
      // Jika pengguna secara spesifik meminta waktu sangat presisi, coba exactAllowWhileIdle.
      AndroidScheduleMode scheduleMode = preferExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDateTime,
          notificationDetails: notificationDetails,
          androidScheduleMode: scheduleMode,
          payload: payload,
        );
        debugPrint(
            'Notifikasi ID $id berhasil dijadwalkan pada $tzDateTime dengan mode $scheduleMode');
        return true;
      } catch (scheduleErr) {
        // Fallback jika exact alarm melempar SecurityException pada Android 12-14+
        debugPrint(
            'Gagal menjadwalkan dengan mode $scheduleMode ($scheduleErr). Beralih ke fallback inexactAllowWhileIdle...');
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDateTime,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
        return true;
      }
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      return false;
    }
  }

  /// Membatalkan notifikasi terjadwal berdasarkan ID
  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
      debugPrint('Notifikasi ID $id berhasil dibatalkan dari sistem OS.');
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  /// Membatalkan semua notifikasi terjadwal di sistem OS
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('Semua notifikasi berhasil dibatalkan dari sistem OS.');
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  /// Mengambil daftar semua notifikasi yang sedang aktif terjadwal di sistem OS
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      await init();
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Error getPendingNotifications: $e');
      return [];
    }
  }

  /// Memulihkan jadwal pengingat masa depan dari database ke AlarmManager sistem OS
  /// (Dijalankan saat aplikasi dibuka untuk memastikan tidak ada pengingat yang terlewat)
  Future<int> restoreScheduledReminders() async {
    int restoredCount = 0;
    try {
      await init();
      final reminders = await DatabaseHelper.instance.getReminders();
      final now = DateTime.now();

      for (final item in reminders) {
        if (item.id != null && item.targetDate != null) {
          try {
            final parsedDate = parseDateTimeFlexible(item.targetDate!);

            if (parsedDate != null && parsedDate.isAfter(now)) {
              await scheduleNotification(
                id: item.id!,
                title: 'DriveMate • ${item.title}',
                body: item.message,
                scheduledDate: parsedDate,
              );
              restoredCount++;
            }
          } catch (itemErr) {
            debugPrint('Gagal memulihkan reminder ${item.id}: $itemErr');
          }
        }
      }
      debugPrint(
          'restoreScheduledReminders: Berhasil memulihkan $restoredCount jadwal pengingat di OS.');
    } catch (e) {
      debugPrint('Error restoreScheduledReminders: $e');
    }
    return restoredCount;
  }

  /// Parser tanggal fleksibel untuk mendukung berbagai format:
  /// - ISO-8601 (2026-10-25T09:00:00)
  /// - Format tersimpan ("2026-10-25 09:00" atau "2026-10-25 09:00 WIB")
  /// - Format Indonesia bawaan ("12 Jul 2026", "12 Juli 2026 09:00")
  DateTime? parseDateTimeFlexible(String dateStr) {
    try {
      final clean = dateStr
          .replaceAll(' WIB', '')
          .replaceAll(' WITA', '')
          .replaceAll(' WIT', '')
          .trim();

      // Coba ISO-8601 langsung
      final iso = DateTime.tryParse(clean);
      if (iso != null) return iso;

      // Coba format "yyyy-MM-dd HH:mm" atau "yyyy-MM-dd"
      final parts = clean.split(' ');
      if (parts.isNotEmpty && parts[0].contains('-')) {
        final dateParts = parts[0].split('-').map(int.tryParse).toList();
        if (dateParts.length == 3 &&
            dateParts[0] != null &&
            dateParts[1] != null &&
            dateParts[2] != null) {
          int hour = 9;
          int minute = 0;
          if (parts.length >= 2 && parts[1].contains(':')) {
            final timeParts = parts[1].split(':').map(int.tryParse).toList();
            if (timeParts.length >= 2 &&
                timeParts[0] != null &&
                timeParts[1] != null) {
              hour = timeParts[0]!;
              minute = timeParts[1]!;
            }
          }
          return DateTime(
              dateParts[0]!, dateParts[1]!, dateParts[2]!, hour, minute);
        }
      }

      // Coba format tanggal bahasa Indonesia: "12 Jul 2026"
      final indonesianMonths = {
        'jan': 1, 'januari': 1,
        'feb': 2, 'februari': 2,
        'mar': 3, 'maret': 3,
        'apr': 4, 'april': 4,
        'mei': 5, 'may': 5,
        'jun': 6, 'juni': 6,
        'jul': 7, 'juli': 7,
        'agu': 8, 'ags': 8, 'agustus': 8, 'aug': 8,
        'sep': 9, 'september': 9,
        'okt': 10, 'oktober': 10, 'oct': 10,
        'nov': 11, 'november': 11,
        'des': 12, 'desember': 12, 'dec': 12,
      };

      if (parts.length >= 3) {
        final day = int.tryParse(parts[0]);
        final monthKey = parts[1].toLowerCase().replaceAll('.', '');
        final month = indonesianMonths[monthKey];
        final year = int.tryParse(parts[2]);

        if (day != null && month != null && year != null) {
          int hour = 9;
          int minute = 0;
          if (parts.length >= 4 && parts[3].contains(':')) {
            final t = parts[3].split(':').map(int.tryParse).toList();
            if (t.length >= 2 && t[0] != null && t[1] != null) {
              hour = t[0]!;
              minute = t[1]!;
            }
          }
          return DateTime(year, month, day, hour, minute);
        }
      }
    } catch (_) {}
    return null;
  }
}
