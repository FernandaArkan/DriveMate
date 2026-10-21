
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/user_profile.dart';

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
      // PEMULIHAN SEMENTARA AKUN CONTOH ANDI.
      // Hapus pemanggilan ini setelah akun berhasil dipulihkan.
      await restoreSampleAccount();

      final prefs = await SharedPreferences.getInstance();

      _isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      _currentUser = await _dbHelper.getUserProfile();

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
      final user = await _dbHelper.getUserProfile();

      if (user == null) {
        debugPrint('Login gagal: profil tidak ditemukan.');
        return false;
      }

      final input = identifier.trim();

      final emailMatches =
          user.email.trim().toLowerCase() == input.toLowerCase();
      final phoneMatches = user.phone.trim() == input;
      final passwordMatches = user.passwordHash == password;

      if ((emailMatches || phoneMatches) && passwordMatches) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool(_keyIsLoggedIn, true);
        await prefs.setString(_keyUserEmail, user.email);

        _currentUser = user;
        _isLoggedIn = true;
        return true;
      }

      debugPrint('Login gagal: email/nomor telepon atau password salah.');
      return false;
    } catch (e) {
      debugPrint('Error login: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;

      final existing = await db.query(
        'user_profile',
        limit: 1,
      );

      // Jangan menimpa profil yang sudah ada.
      if (existing.isNotEmpty) {
        debugPrint(
          'Pendaftaran dibatalkan: profil sudah ada. '
          'Database saat ini hanya mendukung satu profil.',
        );
        return false;
      }

      final newUser = UserProfile(
        id: 1,
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        passwordHash: password,
        token:
            'drivemate_jwt_${DateTime.now().millisecondsSinceEpoch}',
      );

      await db.insert('user_profile', newUser.toMap());

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserEmail, newUser.email);

      _currentUser = newUser;
      _isLoggedIn = true;
      return true;
    } catch (e) {
      debugPrint('Error register: $e');
      return false;
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
