import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._internal();
  static final BiometricService instance = BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: 'Pindai sidik jari atau wajah Anda untuk masuk ke DriveMate',
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
