import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../models/blockchain_document.dart';

class BlockchainDocumentService {
  BlockchainDocumentService._internal();
  static final BlockchainDocumentService instance = BlockchainDocumentService._internal();

  final ApiService _api = ApiService.instance;

  /// Generate or retrieve an existing PDF service record document with blockchain anchoring
  Future<ApiResponse<BlockchainDocument>> generatePdfDocument({
    required int serviceRecordId,
    int? vehicleId,
    int? userId,
    bool forceRegenerate = false,
    String? token,
  }) async {
    try {
      final body = <String, dynamic>{
        'service_record_id': serviceRecordId,
        'force_regenerate': forceRegenerate,
      };
      if (vehicleId != null) {
        body['vehicle_id'] = vehicleId;
      }
      if (userId != null) {
        body['user_id'] = userId;
      }

      final response = await _api.post(
        '/api/generate_pdf.php',
        body: body,
        token: token,
        timeout: const Duration(seconds: 15),
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'];
        if (data is Map<String, dynamic>) {
          final doc = BlockchainDocument.fromMap(data);
          return ApiResponse(
            isSuccess: true,
            data: doc,
            message: response.data!['message'] as String? ?? 'Sertifikat berhasil dibuat.',
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse(
        isSuccess: false,
        message: response.message ?? 'Gagal membuat sertifikat PDF riwayat servis.',
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('BlockchainDocumentService.generatePdfDocument error: $e');
      return ApiResponse(
        isSuccess: false,
        message: 'Terjadi kesalahan saat memproses dokumen blockchain: $e',
      );
    }
  }

  /// Verify a document ID via the verification API
  Future<ApiResponse<Map<String, dynamic>>> verifyDocument({
    required String documentId,
  }) async {
    try {
      final cleanId = documentId.trim();
      final endpoint = '/api/verify.php?document_id=${Uri.encodeComponent(cleanId)}&format=json';

      final response = await _api.get(endpoint);

      if (response.isSuccess && response.data != null) {
        Map<String, dynamic> data = {};
        if (response.data is Map<String, dynamic>) {
          data = response.data as Map<String, dynamic>;
        } else if (response.data is Map) {
          data = Map<String, dynamic>.from(response.data as Map);
        }

        return ApiResponse(
          isSuccess: true,
          data: data,
          message: data['status_title'] as String? ?? 'Verifikasi berhasil.',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse(
        isSuccess: false,
        message: response.message ?? 'Gagal memverifikasi dokumen ke server.',
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('BlockchainDocumentService.verifyDocument error: $e');
      return ApiResponse(
        isSuccess: false,
        message: 'Terjadi kesalahan saat menghubungi server verifikasi: $e',
      );
    }
  }

  /// Compute SHA-256 of file bytes and compare with registered document hash
  bool verifyFileHash(List<int> bytes, String expectedHash) {
    final computedHash = sha256.convert(bytes).toString().toLowerCase();
    final cleanExpected = expectedHash.trim().toLowerCase();
    return computedHash == cleanExpected;
  }

  /// Construct the public verification URL for QR code / web browser
  String getVerificationUrl(String documentId) {
    final base = _api.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/api/verify.php?document_id=${Uri.encodeComponent(documentId)}';
  }

  /// Construct the PDF viewing or downloading URL
  String getPdfUrl(String documentId, {bool download = false}) {
    final base = _api.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final dlParam = download ? '&download=1' : '';
    return '$base/api/view_pdf.php?document_id=${Uri.encodeComponent(documentId)}$dlParam';
  }
}
