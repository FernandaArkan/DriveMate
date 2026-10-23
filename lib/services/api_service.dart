import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/vehicle.dart';

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

  // Konfigurasi Base URL Backend (dapat disesuaikan dengan server lokal / cloud)
  final String baseUrl = ApiConfig.baseUrl;
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
          data: data,
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

  Future<ApiResponse<Map<String, dynamic>>> put(
    String endpoint, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .put(
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
          data: data,
          message: data['message'] as String? ?? 'Gagal memperbarui data.',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      return ApiResponse(
        isSuccess: false,
        message: 'Waktu koneksi habis (Timeout).',
      );
    } catch (e) {
      debugPrint('ApiService Put Error: $e');
      return ApiResponse(
        isSuccess: false,
        message: 'Gagal terhubung ke server ($e).',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(
    String endpoint, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .delete(
            uri,
            headers: _headers(token: token),
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
          data: data,
          message: data['message'] as String? ?? 'Gagal menghapus data.',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      return ApiResponse(
        isSuccess: false,
        message: 'Waktu koneksi habis (Timeout).',
      );
    } catch (e) {
      debugPrint('ApiService Delete Error: $e');
      return ApiResponse(
        isSuccess: false,
        message: 'Gagal terhubung ke server ($e).',
      );
    }
  }

  // === VEHICLES API ===

  Future<List<Vehicle>> getVehicles({int userId = 1, String? token}) async {
    try {
      final response = await get('/api/vehicles.php?user_id=$userId', token: token);
      if (response.isSuccess && response.data != null && response.data['data'] is List) {
        final list = response.data['data'] as List;
        return list.map((item) => Vehicle.fromMap(Map<String, dynamic>.from(item))).toList();
      }
    } catch (e) {
      debugPrint('Error getVehicles from API: $e');
    }
    return [];
  }

  Future<Vehicle> addVehicle({
    required Vehicle vehicle,
    int userId = 1,
    String? token,
  }) async {
    final response = await post(
      '/api/vehicles.php',
      body: vehicle.toApiMap(userId: userId),
      token: token,
    );

    if (response.isSuccess && response.data != null && response.data!['data'] != null) {
      return Vehicle.fromMap(Map<String, dynamic>.from(response.data!['data']));
    }

    throw Exception(response.message ?? 'Gagal menambahkan kendaraan ke server.');
  }

  Future<Vehicle?> updateVehicle({
    required Vehicle vehicle,
    int userId = 1,
    String? token,
  }) async {
    final map = vehicle.toApiMap(userId: userId);
    map['id'] = vehicle.id;

    final response = await put(
      '/api/vehicles.php',
      body: map,
      token: token,
    );

    if (response.isSuccess && response.data != null && response.data!['data'] != null) {
      return Vehicle.fromMap(Map<String, dynamic>.from(response.data!['data']));
    }
    return null;
  }

  Future<bool> deleteVehicle({
    required int id,
    int userId = 1,
    String? token,
  }) async {
    final response = await delete(
      '/api/vehicles.php?id=$id&user_id=$userId',
      token: token,
    );
    return response.isSuccess;
  }

  Future<bool> syncVehicles({
    required List<Vehicle> vehicles,
    int userId = 1,
    String? token,
  }) async {
    final response = await post(
      '/api/vehicles.php',
      body: {
        'action': 'sync',
        'user_id': userId,
        'vehicles': vehicles.map((v) => v.toApiMap(userId: userId)).toList(),
      },
      token: token,
    );
    return response.isSuccess;
  }
}
