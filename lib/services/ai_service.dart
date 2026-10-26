import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AiChatMessage {
  AiChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final String time;
  final bool isError;
}

class AiServiceException implements Exception {
  final String message;
  const AiServiceException(this.message);

  @override
  String toString() => message;
}

class AiService {
  AiService._internal();
  static final AiService instance = AiService._internal();

  /// Menandai apakah sedang ada permintaan AI yang aktif berjalan
  bool _isRequestInFlight = false;

  /// Mengirim pertanyaan ke backend AI DriveMate yang terhubung ke Google Gemini API.
  Future<String> askAi(String query, {List<AiChatMessage>? history}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      throw const AiServiceException('Pertanyaan tidak boleh kosong.');
    }

    if (_isRequestInFlight) {
      throw const AiServiceException('Permintaan AI sebelumnya masih berlangsung. Mohon tunggu respon selesai.');
    }

    _isRequestInFlight = true;

    try {
      // Siapkan riwayat percakapan:
      // Abaikan pesan error dan lewati pesan bot pembuka agar giliran pertama riwayat diawali oleh user
      List<Map<String, String>> historyPayload = [];
      if (history != null && history.isNotEmpty) {
        final validMessages = history.where((m) => !m.isError).toList();
        // Cegah duplikasi jika pesan terakhir di history adalah pertanyaan saat ini
        if (validMessages.isNotEmpty && validMessages.last.isUser && validMessages.last.text.trim() == cleanQuery) {
          validMessages.removeLast();
        }
        final contextMessages = validMessages.skipWhile((m) => !m.isUser).toList();
        historyPayload = contextMessages
            .take(6)
            .map((m) => {
                  'role': m.isUser ? 'user' : 'assistant',
                  'content': m.text,
                })
            .toList();
      }

      // Hubungkan ke backend AI endpoint (/api/ai.php) dengan batas waktu 35 detik
      // (Memberikan toleransi cukup untuk retry bertahap 503 di backend)
      final apiResponse = await ApiService.instance.post(
        '/api/ai.php',
        body: {
          'message': cleanQuery,
          if (historyPayload.isNotEmpty) 'history': historyPayload,
        },
        timeout: const Duration(seconds: 35),
      );

      // Tangani jika response backend sukses (HTTP 2xx)
      if (apiResponse.isSuccess && apiResponse.data != null) {
        final data = apiResponse.data!;
        final reply = data['reply'] ?? data['message'] ?? data['answer'] ?? data['data'];
        if (reply != null && reply.toString().trim().isNotEmpty) {
          return reply.toString().trim();
        }
        throw const AiServiceException('Model Gemini AI tidak menghasilkan respon teks.');
      }

      // Jika backend merespons error (misal API key belum dikonfigurasi, kuota habis, error upstream Gemini 503)
      final rawErrorMsg = apiResponse.message;
      final cleanErrorMsg = _sanitizeErrorMessage(rawErrorMsg, apiResponse.statusCode);
      throw AiServiceException(cleanErrorMsg);
    } on TimeoutException {
      throw const AiServiceException(
        'Waktu koneksi ke server AI habis (Timeout). Mohon periksa koneksi internet Anda atau coba kembali beberapa saat lagi.',
      );
    } on AiServiceException {
      rethrow;
    } catch (e) {
      debugPrint('AiService Error: $e');
      final errStr = _sanitizeErrorMessage(e.toString(), null);
      throw AiServiceException('Gagal terhubung ke server AI: $errStr');
    } finally {
      _isRequestInFlight = false;
    }
  }

  /// Membersihkan respon error server agar tidak pernah menampilkan kode HTML mentah di ruang obrolan
  static String _sanitizeErrorMessage(String? raw, int? statusCode) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Terjadi kesalahan saat menghubungi server AI (${statusCode ?? "tanpa kode status"}).';
    }

    final trimmed = raw.trim();
    final containsHtml = trimmed.contains('<html') ||
        trimmed.contains('<!DOCTYPE') ||
        trimmed.contains('<head') ||
        trimmed.contains('<body') ||
        trimmed.contains('<div');

    if (statusCode == 503 || trimmed.contains('503')) {
      return 'Layanan Google Gemini AI sedang mengalami lonjakan beban/permintaan tinggi (HTTP 503). Silakan coba ajukan kembali pertanyaan Anda dalam beberapa saat.';
    }

    if (statusCode == 504 || trimmed.contains('504')) {
      return 'Server mengalami batas waktu respon (HTTP 504 Gateway Timeout). Silakan coba beberapa saat lagi.';
    }

    if (statusCode == 502 || trimmed.contains('502')) {
      return 'Gagal terhubung ke upstream AI (HTTP 502 Bad Gateway). Silakan coba beberapa saat lagi.';
    }

    if (containsHtml) {
      return 'Server mengembalikan halaman respon error (${statusCode ?? "HTTP Error"}). Silakan coba beberapa saat lagi.';
    }

    return trimmed;
  }
}
