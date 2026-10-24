import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
  error,
}

class LocationCheckResult {
  final LocationPermissionStatus status;
  final String message;

  const LocationCheckResult({required this.status, required this.message});
  bool get isGranted => status == LocationPermissionStatus.granted;
}

class LocationService {
  LocationService._internal();
  static final LocationService instance = LocationService._internal();

  Future<LocationCheckResult> checkAndRequestPermission({bool promptIfNeeded = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationCheckResult(
          status: LocationPermissionStatus.serviceDisabled,
          message: 'Layanan lokasi (GPS) pada perangkat Anda tidak aktif. Silakan aktifkan GPS.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();

      // Jika izin sudah diberikan sebelumnya, langsung kembalikan granted tanpa memicu dialog
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        return const LocationCheckResult(
          status: LocationPermissionStatus.granted,
          message: 'Izin lokasi telah diberikan.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationCheckResult(
          status: LocationPermissionStatus.deniedForever,
          message: 'Izin lokasi ditolak secara permanen. Buka pengaturan aplikasi untuk mengizinkan akses lokasi.',
        );
      }

      // Hanya minta izin jika diminta dan statusnya denied (belum permanen)
      if (permission == LocationPermission.denied) {
        if (!promptIfNeeded) {
          return const LocationCheckResult(
            status: LocationPermissionStatus.denied,
            message: 'Izin lokasi belum diberikan.',
          );
        }

        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationCheckResult(
            status: LocationPermissionStatus.denied,
            message: 'Izin lokasi ditolak. Fitur peta memerlukan izin untuk mencari SPBU & bengkel terdekat.',
          );
        }

        if (permission == LocationPermission.deniedForever) {
          return const LocationCheckResult(
            status: LocationPermissionStatus.deniedForever,
            message: 'Izin lokasi ditolak secara permanen. Buka pengaturan aplikasi untuk mengizinkan akses lokasi.',
          );
        }
      }

      return const LocationCheckResult(
        status: LocationPermissionStatus.granted,
        message: 'Izin lokasi diberikan.',
      );
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      return LocationCheckResult(
        status: LocationPermissionStatus.error,
        message: 'Gagal memeriksa izin lokasi: $e',
      );
    }
  }

  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  Future<Position?> getCurrentLocation({
    bool promptPermission = false,
    bool forceRefresh = false,
  }) async {
    try {
      // Periksa izin tanpa meminta ulang secara agresif
      final permission = await Geolocator.checkPermission();
      final hasPermission = permission == LocationPermission.whileInUse || permission == LocationPermission.always;

      if (!hasPermission) {
        if (promptPermission) {
          final permCheck = await checkAndRequestPermission(promptIfNeeded: true);
          if (!permCheck.isGranted) return null;
        } else {
          return null;
        }
      }

      final isGpsOn = await Geolocator.isLocationServiceEnabled();
      if (!isGpsOn) return null;

      // Jika tidak diminta forceRefresh, periksa posisi terakhir terlebih dahulu
      Position? lastPos;
      if (!forceRefresh) {
        lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && (lastPos.latitude != 0.0 || lastPos.longitude != 0.0)) {
          final age = DateTime.now().difference(lastPos.timestamp);
          if (age.inSeconds < 30) {
            return lastPos;
          }
        }
      }

      try {
        final freshPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (freshPos.latitude != 0.0 || freshPos.longitude != 0.0) {
          return freshPos;
        }
        return null;
      } catch (e) {
        debugPrint('Geolocator.getCurrentPosition failed: $e');
        if (!forceRefresh && lastPos != null) {
          return lastPos;
        }
        // Fallback terakhir: periksa posisi terakhir jika tersedia
        final fallback = await Geolocator.getLastKnownPosition();
        if (fallback != null && (fallback.latitude != 0.0 || fallback.longitude != 0.0)) {
          return fallback;
        }
        return null;
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000.0; // km
  }
}
