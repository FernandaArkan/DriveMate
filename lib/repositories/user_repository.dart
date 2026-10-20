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
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      _currentUser = await _dbHelper.getUserProfile();
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
      // Validasi kredensial nyata
      if (user != null &&
          (user.email.toLowerCase() == identifier.trim().toLowerCase() ||
              user.phone == identifier.trim())) {
        if (user.passwordHash == null || user.passwordHash == password) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_keyIsLoggedIn, true);
          await prefs.setString(_keyUserEmail, user.email);
          _isLoggedIn = true;
          _currentUser = user;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error login: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
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
      final newUser = UserProfile(
        id: 1,
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        passwordHash: password,
        token: 'drivemate_jwt_${DateTime.now().millisecondsSinceEpoch}',
      );

      final db = await _dbHelper.database;
      await db.insert('user_profile', newUser.toMap(),
          conflictAlgorithm: null); // akan ditimpa atau update
      await _dbHelper.updateUserProfile(newUser);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserEmail, newUser.email);

      _isLoggedIn = true;
      _currentUser = newUser;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error register: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, false);
      _isLoggedIn = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error logout: $e');
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
      final updated = _currentUser!.copyWith(isBiometricEnabled: enabled);
      await updateProfile(updated);
    }
  }
}
