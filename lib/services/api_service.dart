import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiResponse<T> {
  ApiResponse({
    required this.isSuccess,
    this.data,
    this.message,
    this.statusCode,
  });

  final bool isSuccess;
  final T? data;
  final String? message;
  final int? statusCode;
}

class ApiService {
  ApiService._internal();
  static final ApiService instance = ApiService._internal();

  // Konfigurasi Base URL Backend (dapat disesuaikan dengan server nyata)
  String baseUrl = 'https://api.drivemate.id/v1';
  final Duration timeoutDuration = const Duration(seconds: 10);

  Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .post(
            uri,
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          isSuccess: true,
          data: data,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          isSuccess: false,
          message: data['message'] as String? ?? 'Terjadi kesalahan pada server.',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      return ApiResponse(
        isSuccess: false,
        message: 'Koneksi waktu habis (Timeout). Periksa koneksi internet Anda.',
      );
    } catch (e) {
      debugPrint('ApiService Error: $e');
      return ApiResponse(
        isSuccess: false,
        message: 'Tidak dapat terhubung ke server backend ($e). Menggunakan mode offline.',
      );
    }
  }

  Future<ApiResponse<dynamic>> get(
    String endpoint, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .get(
            uri,
            headers: _headers(token: token),
          )
          .timeout(timeoutDuration);

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          isSuccess: true,
          data: data,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          isSuccess: false,
          message: 'Gagal mengambil data dari server.',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      return ApiResponse(
        isSuccess: false,
        message: 'Waktu koneksi habis (Timeout).',
      );
    } catch (e) {
      debugPrint('ApiService Get Error: $e');
      return ApiResponse(
        isSuccess: false,
        message: 'Koneksi server gagal. Data lokal tetap aman.',
      );
    }
  }
}
