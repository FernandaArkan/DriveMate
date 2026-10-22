import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../theme/app_theme.dart';

enum ActivityCategory {
  all,
  vehicle,
  service,
  trip,
  reminder,
}

class UserActivity {
  final String id;
  final ActivityCategory category;
  final String title;
  final String description;
  final DateTime dateTime;
  final IconData icon;
  final Color color;

  const UserActivity({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.icon,
    required this.color,
  });

  String get formattedDate {
    return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
  }
}

class ActivityService {
  ActivityService._internal();
  static final ActivityService instance = ActivityService._internal();

  /// Mengumpulkan aktivitas nyata dari seluruh sumber data yang ada di aplikasi
  Future<List<UserActivity>> getUserActivities() async {
    final List<UserActivity> activities = [];
    final db = DatabaseHelper.instance;

    try {
      // 1. Data Kendaraan
      final vehicles = await db.getVehicles();
      for (final v in vehicles) {
        DateTime parsedDate = DateTime.now();
        if (v.createdAt != null && v.createdAt!.isNotEmpty) {
          parsedDate = DateTime.tryParse(v.createdAt!) ?? DateTime.now();
        }

        activities.add(
          UserActivity(
            id: 'veh_${v.id ?? v.plate}',
            category: ActivityCategory.vehicle,
            title: 'Kendaraan Terdaftar',
            description: '${v.brand} ${v.name} (${v.plate}) • ${v.year}',
            dateTime: parsedDate,
            icon: Icons.directions_car_rounded,
            color: AppTheme.primary,
          ),
        );
      }

      // 2. Data Catatan Servis (Blockchain)
      final services = await db.getServiceRecords();
      for (final s in services) {
        DateTime parsedDate = DateTime.now();
        final ts = s.timestamp;
        if (ts != null && ts.isNotEmpty) {
          parsedDate = DateTime.tryParse(ts) ?? DateTime.now();
        } else if (s.date.isNotEmpty) {
          parsedDate = DateTime.tryParse(s.date) ?? DateTime.now();
        }

        final shortHash = s.hash.length >= 8 ? s.hash.substring(0, 8) : s.hash;

        activities.add(
          UserActivity(
            id: 'serv_${s.id ?? shortHash}',
            category: ActivityCategory.service,
            title: 'Servis: ${s.title}',
            description: '${s.serviceType} di ${s.workshop} • Biaya: Rp ${_formatRupiah(s.cost)}',
            dateTime: parsedDate,
            icon: Icons.build_circle_rounded,
            color: const Color(0xFF20B486),
          ),
        );
      }

      // 3. Data Perjalanan & Rute
      final trips = await db.getTrips();
      for (final t in trips) {
        DateTime parsedDate = DateTime.now();
        if (t.date.isNotEmpty) {
          parsedDate = DateTime.tryParse(t.date) ?? DateTime.now();
        }

        activities.add(
          UserActivity(
            id: 'trip_${t.id ?? t.destination}',
            category: ActivityCategory.trip,
            title: 'Perjalanan: ${t.destination}',
            description: 'Jarak ${t.distanceKm} km • Durasi ${t.durationMinutes} menit',
            dateTime: parsedDate,
            icon: Icons.navigation_rounded,
            color: const Color(0xFFFFA53D),
          ),
        );
      }

      // 4. Data Pengingat Aktif
      final reminders = await db.getReminders();
      for (final r in reminders) {
        activities.add(
          UserActivity(
            id: 'rem_${r.id ?? r.title}',
            category: ActivityCategory.reminder,
            title: 'Pengingat: ${r.title}',
            description: '${r.message} (${r.category})',
            dateTime: DateTime.now().subtract(const Duration(hours: 1)),
            icon: Icons.notifications_active_rounded,
            color: Colors.blueAccent,
          ),
        );
      }

      // Urutkan aktivitas dari yang paling baru
      activities.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    } catch (e) {
      debugPrint('Error mengumpulkan aktivitas pengguna: $e');
    }

    return activities;
  }

  static String _formatRupiah(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
  }
}
