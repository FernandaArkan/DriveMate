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

  Future<LocationCheckResult> checkAndRequestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationCheckResult(
          status: LocationPermissionStatus.serviceDisabled,
          message: 'Layanan lokasi (GPS) pada perangkat Anda tidak aktif. Silakan aktifkan GPS.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationCheckResult(
            status: LocationPermissionStatus.denied,
            message: 'Izin lokasi ditolak. Fitur peta memerlukan izin untuk mencari SPBU & bengkel terdekat.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationCheckResult(
          status: LocationPermissionStatus.deniedForever,
          message: 'Izin lokasi ditolak secara permanen. Buka pengaturan aplikasi untuk mengizinkan akses lokasi.',
        );
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

  Future<Position?> getCurrentLocation() async {
    try {
      final permCheck = await checkAndRequestPermission();
      if (!permCheck.isGranted) return null;

      // Coba ambil posisi terakhir terlebih dahulu untuk kecepatan
      final lastPos = await Geolocator.getLastKnownPosition();

      try {
        final freshPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        return freshPos;
      } catch (_) {
        return lastPos;
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
