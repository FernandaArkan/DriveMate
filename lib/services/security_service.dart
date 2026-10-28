import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/user_repository.dart';

enum PinVerificationStatus {
  success,
  incorrect,
  lockedOut,
  notSet,
}

class PinVerificationResult {
  final PinVerificationStatus status;
  final int remainingAttempts;
  final int lockoutSecondsRemaining;
  final String? message;

  const PinVerificationResult({
    required this.status,
    this.remainingAttempts = 0,
    this.lockoutSecondsRemaining = 0,
    this.message,
  });

  bool get isSuccess => status == PinVerificationStatus.success;
  bool get isLockedOut => status == PinVerificationStatus.lockedOut;
}

class SecurityService extends ChangeNotifier {
  SecurityService._internal();

  static final SecurityService instance = SecurityService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Keys for SharedPreferences
  static const String keyBiometricEnabled = 'setting_biometric_enabled';
  static const String keyPinEnabled = 'setting_pin_enabled';
  static const String keyPinHash = 'security_pin_hash_v2';
  static const String keyPinSalt = 'security_pin_salt_v2';
  static const String keyPinFailedAttempts = 'security_pin_failed_attempts';
  static const String keyPinLockoutUntil = 'security_pin_lockout_until';

  // Constants
  static const int maxPinAttempts = 5;
  static const int lockoutDurationSeconds = 30;
  static const int minPinLength = 6;
  static const int hashIterations = 10000;

  bool _isBiometricEnabled = false;
  bool _isPinEnabled = false;
  bool _isPinSet = false;
  bool _isLocked = false;
  bool _isAuthenticatingLocalSecurity = false;
  DateTime? _pausedTimestamp;

  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isPinEnabled => _isPinEnabled;
  bool get isPinSet => _isPinSet;
  bool get isLocked => _isLocked;
  bool get isSecurityActive => _isBiometricEnabled || (_isPinEnabled && _isPinSet);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isBiometricEnabled = prefs.getBool(keyBiometricEnabled) ?? false;
      _isPinEnabled = prefs.getBool(keyPinEnabled) ?? false;
      final savedHash = prefs.getString(keyPinHash);
      final savedSalt = prefs.getString(keyPinSalt);
      _isPinSet = savedHash != null &&
          savedHash.isNotEmpty &&
          savedSalt != null &&
          savedSalt.isNotEmpty;

      // If user has biometric enabled in SQLite profile, keep in sync
      final currentUser = UserRepository.instance.currentUser;
      if (currentUser != null && currentUser.isBiometricEnabled) {
        _isBiometricEnabled = true;
      }
    } catch (e) {
      debugPrint('Error initializing SecurityService: $e');
    } finally {
      notifyListeners();
    }
  }

  // =========================================================
  // BIOMETRIC AUTHENTICATION
  // =========================================================

  Future<bool> isBiometricHardwareAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricEnrolled() async {
    try {
      final available = await isBiometricHardwareAvailable();
      if (!available) return false;
      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric({String? reason}) async {
    final enrolled = await isBiometricEnrolled();
    if (!enrolled) return false;

    _isAuthenticatingLocalSecurity = true;
    try {
      final success = await _localAuth.authenticate(
        localizedReason: reason ??
            'Pindai sidik jari atau wajah Anda untuk memverifikasi keamanan DriveMate',
      );
      return success;
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication PlatformException: $e');
      return false;
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    } finally {
      // Short delay before resetting to prevent race condition with app resume lifecycle
      Future.delayed(const Duration(milliseconds: 600), () {
        _isAuthenticatingLocalSecurity = false;
      });
    }
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      final canEnroll = await isBiometricEnrolled();
      if (!canEnroll) {
        return false;
      }

      final authenticated = await authenticateBiometric(
        reason: 'Pindai sidik jari atau wajah untuk mengaktifkan kunci biometrik',
      );
      if (!authenticated) {
        return false;
      }
    }

    _isBiometricEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyBiometricEnabled, enabled);
      await UserRepository.instance.toggleBiometric(enabled);
    } catch (e) {
      debugPrint('Error saving biometric preference: $e');
    }

    notifyListeners();
    return true;
  }

  // =========================================================
  // PIN MANAGEMENT & CRYPTOGRAPHY
  // =========================================================

  static List<int> _generateSalt([int length = 32]) {
    final rnd = Random.secure();
    return List<int>.generate(length, (_) => rnd.nextInt(256));
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  static String _derivePinHash(String pin, List<int> saltBytes) {
    List<int> current = utf8.encode(pin) + saltBytes;
    for (int i = 0; i < hashIterations; i++) {
      current = sha256.convert(current).bytes;
    }
    return _bytesToHex(current);
  }

  static bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<bool> setPin(String pin) async {
    final cleanPin = pin.trim();
    if (cleanPin.length < minPinLength) {
      return false;
    }

    try {
      final salt = _generateSalt(32);
      final saltHex = _bytesToHex(salt);
      final hashHex = _derivePinHash(cleanPin, salt);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyPinSalt, saltHex);
      await prefs.setString(keyPinHash, hashHex);
      await prefs.setBool(keyPinEnabled, true);
      await prefs.setInt(keyPinFailedAttempts, 0);
      await prefs.setInt(keyPinLockoutUntil, 0);

      _isPinSet = true;
      _isPinEnabled = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving PIN: $e');
      return false;
    }
  }

  Future<PinVerificationResult> verifyPin(String inputPin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutUntil = prefs.getInt(keyPinLockoutUntil) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now < lockoutUntil) {
        final secondsRemaining = ((lockoutUntil - now) / 1000).ceil();
        return PinVerificationResult(
          status: PinVerificationStatus.lockedOut,
          lockoutSecondsRemaining: secondsRemaining,
          message: 'PIN terkunci. Tunggu $secondsRemaining detik.',
        );
      }

      final savedHash = prefs.getString(keyPinHash);
      final savedSaltHex = prefs.getString(keyPinSalt);

      if (savedHash == null || savedSaltHex == null) {
        return const PinVerificationResult(
          status: PinVerificationStatus.notSet,
          message: 'PIN belum diatur.',
        );
      }

      final saltBytes = _hexToBytes(savedSaltHex);
      final computedHash = _derivePinHash(inputPin.trim(), saltBytes);

      if (_constantTimeCompare(computedHash, savedHash)) {
        // Correct PIN
        await prefs.setInt(keyPinFailedAttempts, 0);
        await prefs.setInt(keyPinLockoutUntil, 0);
        return const PinVerificationResult(
          status: PinVerificationStatus.success,
        );
      } else {
        // Wrong PIN
        int failedAttempts = (prefs.getInt(keyPinFailedAttempts) ?? 0) + 1;
        await prefs.setInt(keyPinFailedAttempts, failedAttempts);

        if (failedAttempts >= maxPinAttempts) {
          final lockoutEnd = now + (lockoutDurationSeconds * 1000);
          await prefs.setInt(keyPinLockoutUntil, lockoutEnd);
          await prefs.setInt(keyPinFailedAttempts, 0);
          return const PinVerificationResult(
            status: PinVerificationStatus.lockedOut,
            lockoutSecondsRemaining: lockoutDurationSeconds,
            message: 'Terlalu banyak percobaan salah. PIN dikunci selama $lockoutDurationSeconds detik.',
          );
        }

        final remaining = maxPinAttempts - failedAttempts;
        return PinVerificationResult(
          status: PinVerificationStatus.incorrect,
          remainingAttempts: remaining,
          message: 'PIN salah. Sisa percobaan: $remaining',
        );
      }
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return const PinVerificationResult(
        status: PinVerificationStatus.incorrect,
        remainingAttempts: 0,
      );
    }
  }

  Future<bool> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    final verifyOld = await verifyPin(oldPin);
    if (!verifyOld.isSuccess) {
      return false;
    }

    return await setPin(newPin);
  }

  Future<bool> disablePin(String currentPin) async {
    final verify = await verifyPin(currentPin);
    if (!verify.isSuccess) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyPinEnabled, false);
      await prefs.remove(keyPinHash);
      await prefs.remove(keyPinSalt);
      await prefs.setInt(keyPinFailedAttempts, 0);
      await prefs.setInt(keyPinLockoutUntil, 0);

      _isPinEnabled = false;
      _isPinSet = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error disabling PIN: $e');
      return false;
    }
  }

  Future<void> togglePinEnabled(bool enabled) async {
    if (!enabled && _isPinSet) {
      // Disabling requires PIN validation via disablePin
      _isPinEnabled = false;
    } else if (enabled && _isPinSet) {
      _isPinEnabled = true;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyPinEnabled, _isPinEnabled);
    notifyListeners();
  }

  // =========================================================
  // APP LIFECYCLE & SCREEN LOCK
  // =========================================================

  void onAppPaused() {
    // If local auth dialog itself paused the activity, don't record as backgrounding
    if (_isAuthenticatingLocalSecurity) return;

    if (UserRepository.instance.isLoggedIn && isSecurityActive) {
      _pausedTimestamp = DateTime.now();
    }
  }

  void onAppResumed() {
    if (_isAuthenticatingLocalSecurity) return;

    if (_pausedTimestamp != null &&
        UserRepository.instance.isLoggedIn &&
        isSecurityActive) {
      // Lock the app upon return
      _isLocked = true;
      _pausedTimestamp = null;
      notifyListeners();
    }
  }

  void lockApp() {
    if (UserRepository.instance.isLoggedIn && isSecurityActive) {
      _isLocked = true;
      notifyListeners();
    }
  }

  void unlock() {
    _isLocked = false;
    _pausedTimestamp = null;
    notifyListeners();
  }
}
