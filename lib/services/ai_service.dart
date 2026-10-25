import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
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

class AiService {
  AiService._internal();
  static final AiService instance = AiService._internal();

  /// Mengirim pertanyaan ke backend AI endpoint jika tersedia.
  Future<String> askAi(String query, {List<AiChatMessage>? history}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return 'Pertanyaan tidak boleh kosong.';

    try {
      // 1. Hubungkan ke backend AI endpoint dengan batas waktu 30 detik
      final apiResponse = await ApiService.instance.post(
        '/api/ai.php',
        body: {
          'message': cleanQuery,
          if (history != null)
            'history': history
                .where((m) => !m.isError)
                .take(6)
                .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
                .toList(),
        },
        timeout: const Duration(seconds: 30),
      );

      // Jika backend merespons sukses
      if (apiResponse.isSuccess && apiResponse.data != null) {
        final data = apiResponse.data!;
        final reply = data['reply'] ?? data['message'] ?? data['answer'] ?? data['data'];
        if (reply != null && reply.toString().trim().isNotEmpty) {
          return reply.toString().trim();
        }
      }

      // 2. Jika backend AI endpoint error atau belum siap
      return await _handleUnconfiguredBackendAi(cleanQuery, apiResponse.message);
    } on TimeoutException {
      return 'Waktu koneksi ke server AI habis (Timeout). Mohon periksa koneksi internet Anda atau coba kembali beberapa saat lagi.';
    } catch (e) {
      debugPrint('AiService Error: $e');
      return await _handleUnconfiguredBackendAi(cleanQuery, e.toString());
    }
  }

  /// Menangani kondisi backend AI belum siap dengan transparan dan analitis
  Future<String> _handleUnconfiguredBackendAi(String query, String? backendError) async {
    final q = query.toLowerCase();

    // Dapatkan data kendaraan nyata dari database lokal pengguna
    String vehicleContext = '';
    try {
      final vehicles = await DatabaseHelper.instance.getVehicles();
      if (vehicles.isNotEmpty) {
        final primary = vehicles.first;
        vehicleContext = '\n\nInformasi Terkait Kendaraan Anda:\n'
            '• Unit: ${primary.brand} ${primary.name} (${primary.year})\n'
            '• Jarak Tempuh Saat Ini: ${primary.mileage} km\n'
            '• Bahan Bakar: ${primary.fuelLevel}%\n'
            '• Pajak Jatuh Tempo: ${primary.taxDueDate ?? "Belum diatur"}';
      }
    } catch (_) {}

    if (q.contains('oli') || q.contains('pelumas')) {
      return '[Mode Asisten Otomotif]'
          '\nPenggantian oli mesin dianjurkan setiap 5.000 - 10.000 km atau maksimal 6 bulan sekali. '
          'Gunakan viskositas sesuai buku manual kendaraan.$vehicleContext'
          '\n\nCatatan: Integrasi Cloud AI Server (/api/ai.php) saat ini belum aktif ($backendError).';
    } else if (q.contains('rem') || q.contains('bunyi')) {
      return '[Mode Asisten Otomotif]'
          '\nBunyi decit pada rem umumnya terjadi karena kampas rem menipis atau kotoran pada rotor cakram. '
          'Periksa ketebalan kampas di bengkel terdekat.$vehicleContext'
          '\n\nCatatan: Integrasi Cloud AI Server (/api/ai.php) saat ini belum aktif ($backendError).';
    } else if (q.contains('aki') || q.contains('baterai')) {
      return '[Mode Asisten Otomotif]'
          '\nUmur pakai aki kendaraan berkisar 1,5 - 2,5 tahun. Tanda aki mulai lemah antara lain putaran starter melambat dan tegangan di bawah 12.4V.$vehicleContext'
          '\n\nCatatan: Integrasi Cloud AI Server (/api/ai.php) saat ini belum aktif ($backendError).';
    }

    return 'Layanan Backend AI (/api/ai.php) belum aktif pada server backend (${ApiService.instance.baseUrl}).'
        '\n\nStatus Teknis:'
        '\n• Endpoint `/api/ai.php` memerlukan implementasi backend PHP yang terhubung ke API Key LLM (seperti Google Gemini API atau model AI lokal) agar kredensial API tidak terekspos langsung di aplikasi mobile.'
        '$vehicleContext';
  }
}
