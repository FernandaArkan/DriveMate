import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/security_service.dart';

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
      debugPrint('[SESSION DEBUG] A: mulai initSession');

      final prefs = await SharedPreferences.getInstance();

      _isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final savedEmail = prefs.getString(_keyUserEmail);

      debugPrint(
        '[SESSION DEBUG] B: SharedPreferences selesai '
        '(loggedIn=$_isLoggedIn)',
      );

      final db = await _dbHelper.database;

      debugPrint('[SESSION DEBUG] C: database terbuka');

      final countResult = await db.query('user_profile');

      debugPrint(
        '[SESSION DEBUG] D: query profil selesai '
        '(jumlah=${countResult.length})',
      );

      // Pertahankan perilaku pemulihan akun contoh yang sudah ada.
      if (countResult.isEmpty) {
        debugPrint('[SESSION DEBUG] E: memulihkan akun contoh');

        await restoreSampleAccount();

        debugPrint('[SESSION DEBUG] F: pemulihan akun selesai');
      }

      if (_isLoggedIn &&
          savedEmail != null &&
          savedEmail.isNotEmpty) {
        debugPrint('[SESSION DEBUG] G: mencari profil session');

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

        debugPrint(
          '[SESSION DEBUG] H: pencarian profil selesai '
          '(ditemukan=${matches.isNotEmpty})',
        );
      }

      if (_currentUser == null) {
        debugPrint('[SESSION DEBUG] I: mengambil profil lokal');

        _currentUser = await _dbHelper.getUserProfile();

        debugPrint(
          '[SESSION DEBUG] J: pengambilan profil selesai '
          '(adaProfil=${_currentUser != null})',
        );
      }

      if (_currentUser == null) {
        _isLoggedIn = false;
        await prefs.setBool(_keyIsLoggedIn, false);

        debugPrint(
          '[SESSION DEBUG] K: profil tidak ditemukan, '
          'status login dinonaktifkan',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[SESSION DEBUG] ERROR: $e');
      debugPrint('[SESSION DEBUG] STACK TRACE:\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();

      debugPrint('[SESSION DEBUG] Z: initSession selesai');
    }
  }

  Future<bool> validateSession() async {
    if (!_isLoggedIn || _currentUser == null) {
      return false;
    }

    try {
      final token = _currentUser?.token;

      if (token != null && token.isNotEmpty) {
        final apiResponse = await ApiService.instance.get(
          '/api/vehicles.php?user_id=${_currentUser!.id}',
          token: token,
        );

        if (apiResponse.statusCode == 401) {
          debugPrint(
            'Backend rejected session token (401). Logging out.',
          );
          await logout();
          return false;
        }
      }
    } catch (e) {
      debugPrint(
        'Session validation backend check ($e). '
        'Maintaining offline session.',
      );
    }

    return _isLoggedIn && _currentUser != null;
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final cleanIdentifier = identifier.trim();
      final db = await _dbHelper.database;

      // 1. Coba login ke Backend API jika online.
      try {
        final apiResponse = await ApiService.instance.post(
          '/api/login.php',
          body: {
            'identifier': cleanIdentifier,
            'password': password,
          },
        );

        if (apiResponse.isSuccess && apiResponse.data != null) {
          final resData = apiResponse.data!;

          final userData = resData['data'] is Map
              ? resData['data'] as Map<String, dynamic>
              : null;

          final token = resData['token']?.toString() ??
              userData?['token']?.toString() ??
              'token_${DateTime.now().millisecondsSinceEpoch}';

          final userId = userData != null && userData['id'] != null
              ? int.tryParse(userData['id'].toString()) ?? 1
              : 1;

          final name = userData?['name']?.toString() ?? 'User';
          final email = userData?['email']?.toString() ?? cleanIdentifier;
          final phone = userData?['phone']?.toString() ?? '';

          final user = UserProfile(
            id: userId,
            name: name,
            email: email,
            phone: phone,
            passwordHash: password,
            token: token,
          );

          final existing = await db.query(
            'user_profile',
            where: 'id = ? OR LOWER(email) = ?',
            whereArgs: [user.id, user.email.toLowerCase()],
            limit: 1,
          );

          if (existing.isEmpty) {
            await db.insert('user_profile', user.toMap());
          } else {
            await db.update(
              'user_profile',
              user.toMap(),
              where: 'id = ?',
              whereArgs: [user.id],
            );
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_keyIsLoggedIn, true);
          await prefs.setString(_keyUserEmail, user.email);

          _currentUser = user;
          _isLoggedIn = true;

          return true;
        } else if (apiResponse.statusCode == 401) {
          debugPrint('Login ditolak server: ${apiResponse.message}');
          return false;
        }
      } catch (netErr) {
        debugPrint(
          'Backend tidak dapat dijangkau ($netErr), '
          'beralih ke verifikasi lokal.',
        );
      }

      // 2. Fallback verifikasi lokal SQLite.
      final input = cleanIdentifier.toLowerCase();

      final matches = await db.query(
        'user_profile',
        where: 'LOWER(email) = ? OR phone = ?',
        whereArgs: [input, cleanIdentifier],
      );

      if (matches.isEmpty) {
        debugPrint('Login gagal: akun tidak ditemukan.');
        return false;
      }

      for (final map in matches) {
        final user = UserProfile.fromMap(
          Map<String, dynamic>.from(map),
        );

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

      // 1. Validasi duplikasi lokal.
      final existingEmail = await db.query(
        'user_profile',
        where: 'LOWER(email) = ?',
        whereArgs: [cleanEmail],
        limit: 1,
      );

      if (existingEmail.isNotEmpty) {
        return const AuthResult(
          isSuccess: false,
          message:
              'Email sudah terdaftar. Silakan login atau gunakan email lain.',
        );
      }

      // 2. Kirim request registrasi ke Backend API.
      final apiResponse = await ApiService.instance.post(
        '/api/register.php',
        body: {
          'name': cleanName,
          'email': cleanEmail,
          'phone': cleanPhone,
          'password': password,
        },
      );

      if (apiResponse.isSuccess) {
        int newId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        String? token;

        if (apiResponse.data != null && apiResponse.data is Map) {
          final resData = apiResponse.data as Map<String, dynamic>;

          final userData = resData['data'] is Map
              ? resData['data'] as Map<String, dynamic>
              : null;

          if (userData != null && userData['id'] != null) {
            newId =
                int.tryParse(userData['id'].toString()) ?? newId;
          }

          token = resData['token']?.toString() ??
              userData?['token']?.toString();
        }

        token ??=
            'drivemate_jwt_${DateTime.now().millisecondsSinceEpoch}';

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
          message:
              'Pendaftaran berhasil dikonfirmasi oleh server! Selamat datang di DriveMate.',
          user: newUser,
        );
      } else {
        final errMsg =
            apiResponse.message ?? 'Server backend menolak registrasi.';

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

      SecurityService.instance.unlock();
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