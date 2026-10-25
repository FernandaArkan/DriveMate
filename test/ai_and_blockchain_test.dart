import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:drivemate/models/service_record.dart';
import 'package:drivemate/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Blockchain & Integrity Tests', () {
    test('calculateHash includes notes and status', () {
      final hashWithNotesA = ServiceRecord.calculateHash(
        vehicleId: 1,
        title: 'Ganti Busi',
        serviceType: 'Penggantian',
        date: '25 Okt 2026',
        mileage: 15000,
        workshop: 'Bengkel DriveMate',
        cost: 75000,
        notes: 'Busi Iridium',
        status: 'Selesai',
        prevHash: ServiceRecord.genesisHash,
        timestamp: '2026-10-25T10:00:00',
      );

      final hashWithNotesB = ServiceRecord.calculateHash(
        vehicleId: 1,
        title: 'Ganti Busi',
        serviceType: 'Penggantian',
        date: '25 Okt 2026',
        mileage: 15000,
        workshop: 'Bengkel DriveMate',
        cost: 75000,
        notes: 'Busi Standar', // Berbeda notes
        status: 'Selesai',
        prevHash: ServiceRecord.genesisHash,
        timestamp: '2026-10-25T10:00:00',
      );

      final hashWithStatusC = ServiceRecord.calculateHash(
        vehicleId: 1,
        title: 'Ganti Busi',
        serviceType: 'Penggantian',
        date: '25 Okt 2026',
        mileage: 15000,
        workshop: 'Bengkel DriveMate',
        cost: 75000,
        notes: 'Busi Iridium',
        status: 'Tertunda', // Berbeda status
        prevHash: ServiceRecord.genesisHash,
        timestamp: '2026-10-25T10:00:00',
      );

      expect(hashWithNotesA, isNot(equals(hashWithNotesB)));
      expect(hashWithNotesA, isNot(equals(hashWithStatusC)));
    });

    test('verifyHash verifies both V2 and legacy V1 hashes', () {
      // V2 Record (dengan notes & status)
      final recV2 = ServiceRecord(
        vehicleId: 1,
        title: 'Tune Up',
        serviceType: 'Servis',
        date: '25 Okt 2026',
        mileage: 20000,
        workshop: 'AutoCare',
        cost: 300000,
        notes: 'Tune up mesin dan injektor',
        status: 'Selesai',
        prevHash: ServiceRecord.genesisHash,
        timestamp: '2026-10-25T11:00:00',
      );
      expect(recV2.verifyHash(), true);

      // V1 Legacy Record (tanpa notes & status pada perhitungan hash)
      final legacyHash = ServiceRecord.calculateLegacyHash(
        vehicleId: 1,
        title: 'Servis Berkala Lama',
        serviceType: 'Servis',
        date: '01 Jan 2023',
        mileage: 5000,
        workshop: 'Bengkel Lama',
        cost: 150000,
        prevHash: ServiceRecord.genesisHash,
        timestamp: '2023-01-01T08:00:00',
      );

      final legacyRecord = ServiceRecord(
        vehicleId: 1,
        title: 'Servis Berkala Lama',
        serviceType: 'Servis',
        date: '01 Jan 2023',
        mileage: 5000,
        workshop: 'Bengkel Lama',
        cost: 150000,
        notes: 'Catatan servis lama',
        status: 'Selesai',
        prevHash: ServiceRecord.genesisHash,
        hash: legacyHash,
        timestamp: '2023-01-01T08:00:00',
      );
      expect(legacyRecord.verifyHash(), true);
    });

    test('Genesis hash is 64 characters SHA-256 string', () {
      expect(ServiceRecord.genesisHash.length, 64);
      expect(ServiceRecord.genesisHash, matches(r'^[0]+$'));
    });

    test('Blockchain detection fails if previous hash does not match previous block', () {
      final block1 = ServiceRecord(
        vehicleId: 2,
        title: 'Servis Pertama',
        serviceType: 'Servis',
        date: '01 Feb 2026',
        mileage: 1000,
        workshop: 'Bengkel A',
        cost: 100000,
        prevHash: ServiceRecord.genesisHash,
        timestamp: '2026-02-01T10:00:00',
      );

      // Block 2 tidak menyambung ke Block 1 (prevHash salah)
      final block2Broken = ServiceRecord(
        vehicleId: 2,
        title: 'Servis Kedua',
        serviceType: 'Servis',
        date: '01 Mar 2026',
        mileage: 5000,
        workshop: 'Bengkel B',
        cost: 200000,
        prevHash: 'invalid_prev_hash_1234567890abcdef1234567890abcdef1234567890abcdef',
        timestamp: '2026-03-01T10:00:00',
      );

      // Verifikasi internal hash masing-masing valid
      expect(block1.verifyHash(), true);
      expect(block2Broken.verifyHash(), true);

      // Namun rantai antara block1 dan block2 terputus
      expect(block2Broken.prevHash, isNot(equals(block1.hash)));
    });

    test('DatabaseHelper verifyBlockchainIntegrity returns true for empty list', () async {
      final dbHelper = DatabaseHelper.instance;
      // Kendaraan dengan ID 999999 yang tidak memiliki catatan servis
      final result = await dbHelper.verifyBlockchainIntegrity(vehicleId: 999999);
      expect(result, true);
    });
  });
}
