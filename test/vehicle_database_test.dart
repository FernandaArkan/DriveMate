import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:drivemate/models/vehicle.dart';
import 'package:drivemate/models/service_record.dart';
import 'package:drivemate/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Vehicle Model & Database Unit Test', () {
    test('Vehicle model mapping works properly', () {
      final vehicle = Vehicle(
        id: 1,
        name: 'Civic',
        brand: 'Honda',
        year: 2022,
        plate: 'B 1234 KZ',
        mileage: 12450,
        fuelLevel: 65,
        status: 'Dalam kondisi baik',
        isPrimary: true,
      );

      final map = vehicle.toMap();
      expect(map['name'], 'Civic');
      expect(map['brand'], 'Honda');
      expect(map['isPrimary'], 1);

      final fromMap = Vehicle.fromMap(map);
      expect(fromMap.name, 'Civic');
      expect(fromMap.plate, 'B 1234 KZ');
      expect(fromMap.isPrimary, true);
    });

    test('Blockchain ServiceRecord SHA-256 hash chaining & verification works', () {
      final rec1 = ServiceRecord(
        vehicleId: 1,
        title: 'Pemeriksaan Rem',
        serviceType: 'Pemeriksaan',
        date: '12 Mei 2024',
        mileage: 6000,
        workshop: 'Honda Workshop',
        cost: 350000,
        prevHash: '0000000000000000000000000000000000000000000000000000000000000000',
        timestamp: '2024-05-12T10:00:00',
      );

      expect(rec1.hash.length, 64);
      expect(rec1.verifyHash(), true);

      // Block ke-2 mengikat hash block ke-1
      final rec2 = ServiceRecord(
        vehicleId: 1,
        title: 'Ganti Filter Udara',
        serviceType: 'Penggantian',
        date: '23 Agu 2024',
        mileage: 8000,
        workshop: 'AutoCare Bengkel',
        cost: 200000,
        prevHash: rec1.hash,
        timestamp: '2024-08-23T14:30:00',
      );

      expect(rec2.prevHash, rec1.hash);
      expect(rec2.verifyHash(), true);

      // Simulasi manipulasi data (data tampering)
      final tamperedRec = ServiceRecord(
        vehicleId: 1,
        title: 'Ganti Filter Udara PALSU',
        serviceType: 'Penggantian',
        date: '23 Agu 2024',
        mileage: 8000,
        workshop: 'AutoCare Bengkel',
        cost: 200000,
        prevHash: rec1.hash,
        hash: rec2.hash, // Hash lama tidak cocok dengan data baru
        timestamp: '2024-08-23T14:30:00',
      );

      expect(tamperedRec.verifyHash(), false); // Terdeteksi rusak
    });

    test('Blockchain protects notes and status from tampering', () {
      final rec = ServiceRecord(
        vehicleId: 1,
        title: 'Ganti Kampas Rem',
        serviceType: 'Penggantian',
        date: '10 Jan 2026',
        mileage: 15000,
        workshop: 'Bengkel Resmi',
        cost: 250000,
        notes: 'Original OEM part installed',
        status: 'Selesai',
        prevHash: ServiceRecord.genesisHash,
        timestamp: '2026-01-10T09:00:00',
      );

      expect(rec.verifyHash(), true);

      // Manipulasi notes
      final tamperedNotes = ServiceRecord(
        vehicleId: rec.vehicleId,
        title: rec.title,
        serviceType: rec.serviceType,
        date: rec.date,
        mileage: rec.mileage,
        workshop: rec.workshop,
        cost: rec.cost,
        notes: 'Part palsu non-OEM', // Dimanipulasi
        status: rec.status,
        prevHash: rec.prevHash,
        hash: rec.hash, // Hash asli
        timestamp: rec.timestamp,
      );
      expect(tamperedNotes.verifyHash(), false);

      // Manipulasi status
      final tamperedStatus = ServiceRecord(
        vehicleId: rec.vehicleId,
        title: rec.title,
        serviceType: rec.serviceType,
        date: rec.date,
        mileage: rec.mileage,
        workshop: rec.workshop,
        cost: rec.cost,
        notes: rec.notes,
        status: 'Dibatalkan', // Dimanipulasi
        prevHash: rec.prevHash,
        hash: rec.hash, // Hash asli
        timestamp: rec.timestamp,
      );
      expect(tamperedStatus.verifyHash(), false);
    });

    test('Blockchain maintains backward compatibility with legacy hashes', () {
      // Record lama yang dihitung menggunakan formula legacy (tanpa notes & status)
      final legacyHash = ServiceRecord.calculateLegacyHash(
        vehicleId: 1,
        title: 'Servis Berkala Lama',
        serviceType: 'Servis',
        date: '01 Jan 2024',
        mileage: 5000,
        workshop: 'Bengkel Lama',
        cost: 100000,
        prevHash: ServiceRecord.genesisHash,
        timestamp: '2024-01-01T10:00:00',
      );

      final legacyRecord = ServiceRecord(
        vehicleId: 1,
        title: 'Servis Berkala Lama',
        serviceType: 'Servis',
        date: '01 Jan 2024',
        mileage: 5000,
        workshop: 'Bengkel Lama',
        cost: 100000,
        notes: 'Catatan lama',
        status: 'Selesai',
        prevHash: ServiceRecord.genesisHash,
        hash: legacyHash,
        timestamp: '2024-01-01T10:00:00',
      );

      // Record lama tetap valid berkat backward compatibility fallback
      expect(legacyRecord.verifyHash(), true);
    });

    test('DatabaseHelper service records and blockchain verification works', () async {
      final dbHelper = DatabaseHelper.instance;
      final records = await dbHelper.getServiceRecords();
      expect(records.isNotEmpty, true);

      final integrity = await dbHelper.verifyBlockchainIntegrity();
      expect(integrity, true);
    });
  });
}
