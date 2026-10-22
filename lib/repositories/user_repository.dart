import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';

class AuthResult {
  const AuthResult({
    required this.isSuccess,
    this.message,
    this.user,
  });

  final bool isSuccess;
  final String? message;
  final UserProfile? user;
}

class UserRepository extends ChangeNotifier {
  UserRepository._internal();

  static final UserRepository instance = UserRepository._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  UserProfile? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;

  UserProfile? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserEmail = 'user_email';

  Future<void> initSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final savedEmail = prefs.getString(_keyUserEmail);

      final db = await _dbHelper.database;
      final countResult = await db.query('user_profile');

      // Jika database lokal benar-benar kosong, buat akun awal contoh
      if (countResult.isEmpty) {
        await restoreSampleAccount();
      }

      if (_isLoggedIn && savedEmail != null && savedEmail.isNotEmpty) {
        final matches = await db.query(
          'user_profile',
          where: 'LOWER(email) = ?',
          whereArgs: [savedEmail.trim().toLowerCase()],
          limit: 1,
        );
        if (matches.isNotEmpty) {
          _currentUser = UserProfile.fromMap(
            Map<String, dynamic>.from(matches.first),
          );
        }
      }

      _currentUser ??= await _dbHelper.getUserProfile();

      if (_currentUser == null) {
        _isLoggedIn = false;
        await prefs.setBool(_keyIsLoggedIn, false);
      }
    } catch (e) {
      debugPrint('Error initSession: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final input = identifier.trim().toLowerCase();

      final matches = await db.query(
        'user_profile',
        where: 'LOWER(email) = ? OR phone = ?',
        whereArgs: [input, identifier.trim()],
      );

      if (matches.isEmpty) {
        debugPrint('Login gagal: akun tidak ditemukan.');
        return false;
      }

      for (final map in matches) {
        final user = UserProfile.fromMap(Map<String, dynamic>.from(map));
        if (user.passwordHash == password) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_keyIsLoggedIn, true);
          await prefs.setString(_keyUserEmail, user.email);

          _currentUser = user;
          _isLoggedIn = true;
          return true;
        }
      }

      debugPrint('Login gagal: password salah.');
      return false;
    } catch (e) {
      debugPrint('Error login: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanPhone = phone.trim();
      final cleanName = name.trim();

      final db = await _dbHelper.database;

      // 1. Validasi duplikasi lokal
      final existingEmail = await db.query(
        'user_profile',
        where: 'LOWER(email) = ?',
        whereArgs: [cleanEmail],
        limit: 1,
      );

      if (existingEmail.isNotEmpty) {
        return const AuthResult(
          isSuccess: false,
          message: 'Email sudah terdaftar. Silakan login atau gunakan email lain.',
        );
      }

      // 2. Kirim request registrasi ke Backend API
      final apiResponse = await ApiService.instance.post(
        '/api/register.php',
        body: {
          'name': cleanName,
          'email': cleanEmail,
          'phone': cleanPhone,
          'password': password,
        },
      );

      // Jika server backend merespons berhasil
      if (apiResponse.isSuccess) {
        int newId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        String? token;

        if (apiResponse.data != null && apiResponse.data is Map) {
          final resData = apiResponse.data as Map<String, dynamic>;
          final userData = resData['data'] is Map ? resData['data'] as Map<String, dynamic> : null;
          if (userData != null && userData['id'] != null) {
            newId = int.tryParse(userData['id'].toString()) ?? newId;
          }
          token = resData['token']?.toString() ?? userData?['token']?.toString();
        }

        token ??= 'drivemate_jwt_${DateTime.now().millisecondsSinceEpoch}';

        final newUser = UserProfile(
          id: newId,
          name: cleanName,
          email: cleanEmail,
          phone: cleanPhone,
          passwordHash: password,
          token: token,
        );

        await db.insert('user_profile', newUser.toMap());

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyIsLoggedIn, true);
        await prefs.setString(_keyUserEmail, newUser.email);

        _currentUser = newUser;
        _isLoggedIn = true;

        return AuthResult(
          isSuccess: true,
          message: 'Pendaftaran berhasil dikonfirmasi oleh server! Selamat datang di DriveMate.',
          user: newUser,
        );
      } else {
        // Server mengembalikan error atau koneksi gagal
        final errMsg = apiResponse.message ?? 'Server backend menolak registrasi.';
        return AuthResult(
          isSuccess: false,
          message: 'Registrasi ke server gagal: $errMsg',
        );
      }
    } catch (e) {
      debugPrint('Error register: $e');
      return AuthResult(
        isSuccess: false,
        message: 'Terjadi kesalahan sistem saat registrasi: $e',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restoreSampleAccount() async {
    try {
      final db = await _dbHelper.database;

      final andi = UserProfile(
        id: 1,
        name: 'Andi Pratama',
        email: 'andi@email.com',
        phone: '081234567890',
        passwordHash: '123456',
        token: 'drivemate_jwt_token_sample_123',
      );

      final existing = await db.query(
        'user_profile',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (existing.isEmpty) {
        await db.insert('user_profile', andi.toMap());
      } else {
        await db.update(
          'user_profile',
          andi.toMap(),
          where: 'id = ?',
          whereArgs: [1],
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, false);
      await prefs.setString(_keyUserEmail, andi.email);

      _currentUser = andi;
      _isLoggedIn = false;

      debugPrint('Akun contoh Andi berhasil dipulihkan.');
      return true;
    } catch (e) {
      debugPrint('Error memulihkan akun Andi: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, false);
      _isLoggedIn = false;
    } catch (e) {
      debugPrint('Error logout: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<bool> updateProfile(UserProfile profile) async {
    try {
      final rows = await _dbHelper.updateUserProfile(profile);

      if (rows > 0) {
        _currentUser = profile;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }

    return false;
  }

  Future<void> toggleBiometric(bool enabled) async {
    if (_currentUser != null) {
      final updated = _currentUser!.copyWith(
        isBiometricEnabled: enabled,
      );

      await updateProfile(updated);
    }
  }
}
