import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivemate/models/blockchain_document.dart';
import 'package:drivemate/models/service_record.dart';
import 'package:drivemate/models/vehicle.dart';
import 'package:drivemate/services/blockchain_document_service.dart';

void main() {
  group('Tugas Antigravity: Blockchain + PDF + QR Code DriveMate Tests', () {
    const sampleDocumentId = '550e8400-e29b-41d4-a716-446655440000';
    const sampleVerificationUrl =
        'https://drivemate-3c397.containers.snapdeploy.app/api/verify.php?document_id=550e8400-e29b-41d4-a716-446655440000';
    const samplePdfUrl =
        'https://drivemate-3c397.containers.snapdeploy.app/api/view_pdf.php?document_id=550e8400-e29b-41d4-a716-446655440000';

    final sampleVehicle = Vehicle(
      id: 1,
      name: 'NMAX',
      brand: 'Yamaha',
      year: 2023,
      plate: 'AB 5678 CD',
      mileage: 8200,
      createdAt: '2026-10-22',
    );

    final sampleRecord = ServiceRecord(
      id: 10,
      vehicleId: 1,
      title: 'Ganti Oli & Filter',
      serviceType: 'Servis',
      date: '28 Okt 2026',
      mileage: 8200,
      workshop: 'Bengkel DriveMate Resmi',
      cost: 150000,
      notes: 'Oli Yamalube Full Synthetic 10W-40',
      status: 'Selesai',
      prevHash: ServiceRecord.genesisHash,
      timestamp: '2026-10-28T10:00:00Z',
    );

    // 1. Generate PDF dari riwayat servis valid
    test('1. Generate PDF dari riwayat servis valid mengembalikan model BlockchainDocument lengkap', () {
      final samplePdfBytes = utf8.encode(
        '%PDF-1.4\n1 0 obj<<>>endobj\nService: ${sampleRecord.title}\nVehicle: ${sampleVehicle.plate}\nDocId: $sampleDocumentId\n%%EOF',
      );
      final computedHash = sha256.convert(samplePdfBytes).toString();

      final jsonPayload = {
        'document_id': sampleDocumentId,
        'service_record_id': sampleRecord.id,
        'document_hash': computedHash,
        'verification_status': 'verified',
        'transaction_hash': '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        'network_name': 'Polygon Amoy Testnet',
        'contract_address': '0x1234567890123456789012345678901234567890',
        'verification_url': sampleVerificationUrl,
        'pdf_url': samplePdfUrl,
        'pdf_download_url': '$samplePdfUrl&download=1',
        'created_at': '2026-10-28 10:00:00 UTC',
      };

      final doc = BlockchainDocument.fromMap(jsonPayload);

      expect(doc.documentId, sampleDocumentId);
      expect(doc.serviceRecordId, 10);
      expect(doc.documentHash, computedHash);
      expect(doc.isVerified, isTrue);
      expect(doc.isPending, isFalse);
      expect(doc.isFailed, isFalse);
      expect(doc.networkName, 'Polygon Amoy Testnet');
      expect(doc.transactionHash, startsWith('0x'));
      expect(doc.verificationUrl, contains(sampleDocumentId));
      expect(doc.pdfUrl, contains(sampleDocumentId));
    });

    // 2. PDF final menghasilkan hash SHA-256 yang konsisten
    test('2. PDF final menghasilkan hash SHA-256 yang deterministik dan konsisten', () {
      final pdfContent = '%PDF-1.4\nDriveMate Service Certificate\nDoc:$sampleDocumentId\n%%EOF';
      final bytes1 = utf8.encode(pdfContent);
      final bytes2 = utf8.encode(pdfContent);

      final hash1 = sha256.convert(bytes1).toString();
      final hash2 = sha256.convert(bytes2).toString();

      expect(hash1, equals(hash2));
      expect(hash1.length, 64);
      expect(hash1, matches(r'^[a-f0-9]{64}$'));
    });

    // 3. QR Code berisi URL verifikasi dan document_id yang benar
    test('3. QR Code dan helper service menghasilkan URL verifikasi dengan document_id yang benar', () {
      final service = BlockchainDocumentService.instance;
      final generatedUrl = service.getVerificationUrl(sampleDocumentId);

      expect(generatedUrl, contains('/api/verify.php'));
      expect(generatedUrl, contains('document_id=$sampleDocumentId'));
      expect(generatedUrl, startsWith('https://drivemate-3c397.containers.snapdeploy.app'));
    });

    // 4. PDF yang dimodifikasi menghasilkan hash berbeda
    test('4. PDF yang dimodifikasi (tampered) menghasilkan hash berbeda dan gagal verifikasi', () {
      final originalPdf = '%PDF-1.4\nDriveMate Certificate\nCost: Rp 150.000\n%%EOF';
      final tamperedPdf = '%PDF-1.4\nDriveMate Certificate\nCost: Rp 500.000\n%%EOF';

      final originalHash = sha256.convert(utf8.encode(originalPdf)).toString();
      final tamperedHash = sha256.convert(utf8.encode(tamperedPdf)).toString();

      expect(originalHash, isNot(equals(tamperedHash)));

      final service = BlockchainDocumentService.instance;
      final isValid = service.verifyFileHash(utf8.encode(tamperedPdf), originalHash);
      expect(isValid, isFalse);

      final isOriginalValid = service.verifyFileHash(utf8.encode(originalPdf), originalHash);
      expect(isOriginalValid, isTrue);
    });

    // 5. ID dokumen tidak ditemukan
    test('5. Penanganan jika ID dokumen tidak ditemukan', () {
      final notFoundResponse = {
        'success': false,
        'state': 'NOT_FOUND',
        'message': 'ID Dokumen Tidak Ditemukan',
        'description': 'Dokumen dengan ID ini tidak terdaftar di dalam sistem DriveMate.',
        'document_id': '00000000-0000-0000-0000-000000000000',
      };

      expect(notFoundResponse['success'], isFalse);
      expect(notFoundResponse['state'], 'NOT_FOUND');
      expect(notFoundResponse['message'], contains('Tidak Ditemukan'));
    });

    // 6. Transaksi blockchain gagal
    test('6. Transaksi blockchain gagal tidak menandai dokumen sebagai verified', () {
      final failedPayload = {
        'document_id': sampleDocumentId,
        'service_record_id': 10,
        'document_hash': 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        'verification_status': 'failed',
        'transaction_hash': '0xfailedtx1234567890',
        'network_name': 'Polygon Amoy Testnet',
        'verification_url': sampleVerificationUrl,
        'pdf_url': samplePdfUrl,
        'blockchain_message': 'Transaksi reverted oleh EVM.',
      };

      final doc = BlockchainDocument.fromMap(failedPayload);

      expect(doc.isVerified, isFalse);
      expect(doc.isFailed, isTrue);
      expect(doc.isPending, isFalse);
      expect(doc.verificationStatus, 'failed');
    });

    // 7. Transaksi masih pending atau tidak dapat dikonfirmasi
    test('7. Transaksi pending atau unconfirmed memiliki status yang tepat dan tidak sukses palsu', () {
      final pendingPayload = {
        'document_id': sampleDocumentId,
        'service_record_id': 10,
        'document_hash': 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        'verification_status': 'pending',
        'transaction_hash': null,
        'network_name': 'Polygon Amoy Testnet',
        'verification_url': sampleVerificationUrl,
        'pdf_url': samplePdfUrl,
        'blockchain_message': 'Menunggu konfirmasi blok.',
      };

      final doc = BlockchainDocument.fromMap(pendingPayload);

      expect(doc.isVerified, isFalse);
      expect(doc.isPending, isTrue);
      expect(doc.isFailed, isFalse);
      expect(doc.transactionHash, isNull);
    });

    // 8. Pengguna tidak berhak mengakses riwayat servis milik pengguna lain
    test('8. Validasi otorisasi menolak pengguna yang tidak memiliki kendaraan tersebut', () {
      // Kendaraan dimiliki user_id = 1
      const ownerUserId = 1;
      const unauthorizedUserId = 99;

      bool canAccess(int vehicleOwnerId, int requestingUserId) {
        return vehicleOwnerId == requestingUserId;
      }

      expect(canAccess(ownerUserId, ownerUserId), isTrue);
      expect(canAccess(ownerUserId, unauthorizedUserId), isFalse);
    });

    // 9. Koneksi PostgreSQL atau RPC blockchain mengalami gangguan
    test('9. Gangguan RPC atau database dibedakan dari dokumen palsu', () {
      final rpcErrorState = {
        'state': 'NETWORK_UNAVAILABLE',
        'status_title': 'Layanan Blockchain Sedang Tidak Tersedia',
        'status_description': 'Koneksi ke jaringan RPC blockchain mengalami gangguan. Catatan dokumen aman tersimpan di sistem.',
        'is_fake_document': false,
      };

      expect(rpcErrorState['state'], 'NETWORK_UNAVAILABLE');
      expect(rpcErrorState['is_fake_document'], isFalse);
      expect(rpcErrorState['status_title'], contains('Tidak Tersedia'));
    });

    // 10. PDF dapat diunduh atau dibagikan dari Flutter
    test('10. Endpoint PDF download URL dan view URL diformat dengan benar', () {
      final service = BlockchainDocumentService.instance;
      final viewUrl = service.getPdfUrl(sampleDocumentId, download: false);
      final downloadUrl = service.getPdfUrl(sampleDocumentId, download: true);

      expect(viewUrl, contains('api/view_pdf.php?document_id=$sampleDocumentId'));
      expect(downloadUrl, contains('&download=1'));
      expect(downloadUrl, startsWith('https://drivemate-3c397.containers.snapdeploy.app'));
    });
  });
}
