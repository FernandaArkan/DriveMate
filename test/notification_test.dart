import 'package:flutter_test/flutter_test.dart';
import 'package:drivemate/services/notification_service.dart';
import 'package:drivemate/models/reminder_item.dart';

void main() {
  group('NotificationService & Reminder Unit Tests', () {
    final notifService = NotificationService.instance;

    test('parseDateTimeFlexible handles ISO-8601 strings', () {
      final date = notifService.parseDateTimeFlexible('2026-11-15T14:30:00');
      expect(date, isNotNull);
      expect(date!.year, 2026);
      expect(date.month, 11);
      expect(date.day, 15);
      expect(date.hour, 14);
      expect(date.minute, 30);
    });

    test('parseDateTimeFlexible handles yyyy-MM-dd HH:mm with timezone suffix', () {
      final date = notifService.parseDateTimeFlexible('2026-12-01 08:45 WIB');
      expect(date, isNotNull);
      expect(date!.year, 2026);
      expect(date.month, 12);
      expect(date.day, 1);
      expect(date.hour, 8);
      expect(date.minute, 45);
    });

    test('parseDateTimeFlexible handles Indonesian date strings like 12 Jul 2026', () {
      final date = notifService.parseDateTimeFlexible('12 Jul 2026');
      expect(date, isNotNull);
      expect(date!.year, 2026);
      expect(date.month, 7);
      expect(date.day, 12);
      expect(date.hour, 9); // default hour
    });

    test('parseDateTimeFlexible handles Indonesian date strings with time like 20 Nov 2026 15:30', () {
      final date = notifService.parseDateTimeFlexible('20 Nov 2026 15:30');
      expect(date, isNotNull);
      expect(date!.year, 2026);
      expect(date.month, 11);
      expect(date.day, 20);
      expect(date.hour, 15);
      expect(date.minute, 30);
    });

    test('ReminderItem toMap and fromMap serialization maintains integrity', () {
      final item = ReminderItem(
        id: 42,
        vehicleId: 1,
        title: 'Ganti Oli Mesin 5.000 km',
        message: 'Sudah saatnya mengganti oli mesin Honda Civic.',
        category: 'Servis',
        timeAgo: 'Dijadwalkan',
        targetDate: '2026-11-10 10:00',
        targetMileage: 15000,
        isRead: false,
      );

      final map = item.toMap();
      expect(map['id'], 42);
      expect(map['vehicleId'], 1);
      expect(map['title'], 'Ganti Oli Mesin 5.000 km');
      expect(map['category'], 'Servis');
      expect(map['isRead'], 0);

      final deserialized = ReminderItem.fromMap(map);
      expect(deserialized.id, item.id);
      expect(deserialized.title, item.title);
      expect(deserialized.message, item.message);
      expect(deserialized.category, item.category);
      expect(deserialized.targetDate, item.targetDate);
      expect(deserialized.isRead, false);
    });

    test('ReminderItem handles isRead flag properly', () {
      final item = ReminderItem(
        id: 10,
        title: 'Pajak STNK',
        message: 'Pajak akan jatuh tempo',
        category: 'Pajak',
        timeAgo: '1 hari lalu',
        isRead: true,
      );

      final map = item.toMap();
      expect(map['isRead'], 1);

      final fromMap = ReminderItem.fromMap(map);
      expect(fromMap.isRead, true);
    });
  });
}
