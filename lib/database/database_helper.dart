import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/service_record.dart';
import '../models/vehicle.dart';
import '../models/user_profile.dart';
import '../models/reminder_item.dart';
import '../models/trip_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('drivemate.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        year INTEGER NOT NULL,
        plate TEXT NOT NULL,
        mileage INTEGER NOT NULL,
        fuelLevel INTEGER NOT NULL DEFAULT 65,
        status TEXT NOT NULL DEFAULT 'Aktif',
        isPrimary INTEGER NOT NULL DEFAULT 0,
        lastServiceDate TEXT,
        taxDueDate TEXT,
        createdAt TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE service_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicleId INTEGER NOT NULL,
        title TEXT NOT NULL,
        serviceType TEXT NOT NULL,
        date TEXT NOT NULL,
        mileage INTEGER NOT NULL,
        workshop TEXT NOT NULL,
        cost INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'Selesai',
        prevHash TEXT NOT NULL,
        hash TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicleId INTEGER,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        category TEXT NOT NULL,
        timeAgo TEXT NOT NULL,
        targetDate TEXT,
        targetMileage INTEGER,
        isRead INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destination TEXT NOT NULL,
        distanceKm REAL NOT NULL,
        durationMinutes INTEGER NOT NULL,
        date TEXT NOT NULL,
        startLocation TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        avatarUrl TEXT,
        isBiometricEnabled INTEGER NOT NULL DEFAULT 0,
        token TEXT,
        passwordHash TEXT
      )
    ''');

    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    // 1. Initial Vehicles
    final civicId = await db.insert('vehicles', {
      'name': 'Civic',
      'brand': 'Honda',
      'year': 2022,
      'plate': 'B 1234 KZ',
      'mileage': 12450,
      'fuelLevel': 65,
      'status': 'Dalam kondisi baik',
      'isPrimary': 1,
      'lastServiceDate': '10 Mar 2025',
      'taxDueDate': '12 Jul 2026',
      'createdAt': DateTime.now().toIso8601String(),
      'isSynced': 1,
    });

    await db.insert('vehicles', {
      'name': 'NMAX',
      'brand': 'Yamaha',
      'year': 2023,
      'plate': 'AB 5678 CD',
      'mileage': 8200,
      'fuelLevel': 80,
      'status': 'Dalam kondisi baik',
      'isPrimary': 0,
      'lastServiceDate': '05 Jan 2025',
      'taxDueDate': '20 Nov 2026',
      'createdAt': DateTime.now().toIso8601String(),
      'isSynced': 1,
    });

    // 2. Initial Blockchain Service Records (Linked by SHA-256)
    var prevHash = '0000000000000000000000000000000000000000000000000000000000000000';
    
    final rec1 = ServiceRecord(
      vehicleId: civicId,
      title: 'Pemeriksaan Rem',
      serviceType: 'Pemeriksaan',
      date: '12 Mei 2024',
      mileage: 6000,
      workshop: 'Honda Workshop',
      cost: 350000,
      notes: 'Pemeriksaan berkala kampas rem depan dan belakang.',
      status: 'Selesai',
      prevHash: prevHash,
      timestamp: '2024-05-12T10:00:00',
    );
    await db.insert('service_records', rec1.toMap());
    prevHash = rec1.hash;

    final rec2 = ServiceRecord(
      vehicleId: civicId,
      title: 'Ganti Filter Udara',
      serviceType: 'Penggantian',
      date: '23 Agu 2024',
      mileage: 8000,
      workshop: 'AutoCare Bengkel',
      cost: 200000,
      notes: 'Penggantian filter udara original OEM Honda.',
      status: 'Selesai',
      prevHash: prevHash,
      timestamp: '2024-08-23T14:30:00',
    );
    await db.insert('service_records', rec2.toMap());
    prevHash = rec2.hash;

    final rec3 = ServiceRecord(
      vehicleId: civicId,
      title: 'Servis Berkala',
      serviceType: 'Servis',
      date: '15 Nov 2024',
      mileage: 10000,
      workshop: 'Honda Workshop',
      cost: 1200000,
      notes: 'Servis 10.000 km komplit: tune up, rotasi ban, cek fluida.',
      status: 'Selesai',
      prevHash: prevHash,
      timestamp: '2024-11-15T09:15:00',
    );
    await db.insert('service_records', rec3.toMap());
    prevHash = rec3.hash;

    final rec4 = ServiceRecord(
      vehicleId: civicId,
      title: 'Ganti Oli Mesin',
      serviceType: 'Servis',
      date: '10 Mar 2025',
      mileage: 12000,
      workshop: 'AutoCare Bengkel',
      cost: 650000,
      notes: 'Ganti oli Fully Synthetic 0W-20 & filter oli.',
      status: 'Selesai',
      prevHash: prevHash,
      timestamp: '2025-03-10T11:00:00',
    );
    await db.insert('service_records', rec4.toMap());

    // 3. Initial Reminders
    await db.insert('reminders', {
      'vehicleId': civicId,
      'title': 'Pengingat Servis',
      'message': 'Servis berkala sudah mendekati. Dalam 2.500 km lagi.',
      'category': 'Servis',
      'timeAgo': '2 jam lalu',
      'targetMileage': 15000,
      'isRead': 0,
    });

    await db.insert('reminders', {
      'vehicleId': civicId,
      'title': 'Pajak Kendaraan',
      'message': 'Pajak kendaraan Anda akan jatuh tempo pada 12 Jul 2026.',
      'category': 'Pajak',
      'timeAgo': '5 jam lalu',
      'targetDate': '12 Jul 2026',
      'isRead': 0,
    });

    await db.insert('reminders', {
      'vehicleId': civicId,
      'title': 'Cuaca Buruk',
      'message': 'Diperkirakan hujan di lokasi Anda pada 1 jam ke depan.',
      'category': 'Sistem',
      'timeAgo': '8 jam lalu',
      'isRead': 0,
    });

    await db.insert('reminders', {
      'vehicleId': civicId,
      'title': 'Pembaruan Aplikasi',
      'message': 'Versi terbaru tersedia. Fitur lebih lengkap dan stabil.',
      'category': 'Sistem',
      'timeAgo': '1 hari lalu',
      'isRead': 1,
    });

    // 4. Initial User Profile
    await db.insert('user_profile', {
      'id': 1,
      'name': 'Andi Pratama',
      'email': 'andi@email.com',
      'phone': '081234567890',
      'avatarUrl': null,
      'isBiometricEnabled': 0,
      'token': 'drivemate_jwt_token_sample_123',
      'passwordHash': '123456',
    });

    // 5. Initial Trip
    await db.insert('trips', {
      'destination': 'Bengkel AutoCare',
      'distanceKm': 2.4,
      'durationMinutes': 8,
      'date': '2026-10-20',
      'startLocation': 'Lokasi Anda',
      'notes': 'Perjalanan menuju bengkel servis terdekat',
    });
  }

  // === VEHICLE CRUD ===
  Future<List<Vehicle>> getVehicles() async {
    final db = await database;
    final maps = await db.query('vehicles', orderBy: 'isPrimary DESC, id ASC');
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<Vehicle?> getPrimaryVehicle() async {
    final db = await database;
    final maps = await db.query('vehicles', where: 'isPrimary = ?', whereArgs: [1], limit: 1);
    if (maps.isNotEmpty) {
      return Vehicle.fromMap(maps.first);
    }
    final all = await getVehicles();
    return all.isNotEmpty ? all.first : null;
  }

  Future<int> insertVehicle(Vehicle vehicle) async {
    final db = await database;
    if (vehicle.isPrimary) {
      await db.update('vehicles', {'isPrimary': 0});
    }
    return await db.insert('vehicles', vehicle.toMap());
  }

  Future<int> updateVehicle(Vehicle vehicle) async {
    final db = await database;
    if (vehicle.isPrimary && vehicle.id != null) {
      await db.update('vehicles', {'isPrimary': 0}, where: 'id != ?', whereArgs: [vehicle.id]);
    }
    return await db.update(
      'vehicles',
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  Future<int> deleteVehicle(int id) async {
    final db = await database;
    final deleted = await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
    final remaining = await getVehicles();
    if (remaining.isNotEmpty && !remaining.any((v) => v.isPrimary)) {
      await setPrimaryVehicle(remaining.first.id!);
    }
    return deleted;
  }

  Future<void> setPrimaryVehicle(int id) async {
    final db = await database;
    await db.update('vehicles', {'isPrimary': 0});
    await db.update('vehicles', {'isPrimary': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // === SERVICE RECORDS CRUD & BLOCKCHAIN ===
  Future<List<ServiceRecord>> getServiceRecords({int? vehicleId}) async {
    final db = await database;
    final maps = vehicleId != null
        ? await db.query('service_records', where: 'vehicleId = ?', whereArgs: [vehicleId], orderBy: 'id DESC')
        : await db.query('service_records', orderBy: 'id DESC');
    return maps.map((m) => ServiceRecord.fromMap(m)).toList();
  }

  Future<int> addServiceRecord(ServiceRecord record) async {
    final db = await database;
    return await db.insert('service_records', record.toMap());
  }

  Future<bool> verifyBlockchainIntegrity({int? vehicleId}) async {
    final db = await database;
    final maps = vehicleId != null
        ? await db.query('service_records', where: 'vehicleId = ?', whereArgs: [vehicleId], orderBy: 'id ASC')
        : await db.query('service_records', orderBy: 'id ASC');
    
    if (maps.isEmpty) return true;

    String expectedPrevHash = '0000000000000000000000000000000000000000000000000000000000000000';
    for (int i = 0; i < maps.length; i++) {
      final rec = ServiceRecord.fromMap(maps[i]);
      if (i > 0 && rec.prevHash != expectedPrevHash) {
        return false;
      }
      if (!rec.verifyHash()) {
        return false;
      }
      expectedPrevHash = rec.hash;
    }
    return true;
  }

  // === REMINDERS ===
  Future<List<ReminderItem>> getReminders() async {
    final db = await database;
    final maps = await db.query('reminders', orderBy: 'id DESC');
    return maps.map((m) => ReminderItem.fromMap(m)).toList();
  }

  Future<int> addReminder(ReminderItem item) async {
    final db = await database;
    return await db.insert('reminders', item.toMap());
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // === TRIPS ===
  Future<List<TripRecord>> getTrips() async {
    final db = await database;
    final maps = await db.query('trips', orderBy: 'id DESC');
    return maps.map((m) => TripRecord.fromMap(m)).toList();
  }

  Future<int> addTrip(TripRecord trip) async {
    final db = await database;
    return await db.insert('trips', trip.toMap());
  }

  // === USER PROFILE ===
  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final maps = await db.query('user_profile', where: 'id = 1', limit: 1);
    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUserProfile(UserProfile profile) async {
    final db = await database;
    return await db.update('user_profile', profile.toMap(), where: 'id = 1');
  }
}
