import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorData {
  SensorData({
    this.accelX = 0.0,
    this.accelY = 0.0,
    this.accelZ = 0.0,
    this.gyroX = 0.0,
    this.gyroY = 0.0,
    this.gyroZ = 0.0,
    this.gForce = 1.0,
    this.isSupported = true,
    this.heading,
    this.headingDirection = '--',
    this.isCompassSupported = false,
    this.magX = 0.0,
    this.magY = 0.0,
    this.magZ = 0.0,
  });

  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double gForce;
  final bool isSupported;
  final double? heading;
  final String headingDirection;
  final bool isCompassSupported;
  final double magX;
  final double magY;
  final double magZ;

  static String calculateCardinalDirection(double? heading) {
    if (heading == null) return '--';
    final normalized = (heading % 360 + 360) % 360;
    if (normalized >= 337.5 || normalized < 22.5) return 'N';
    if (normalized < 67.5) return 'NE';
    if (normalized < 112.5) return 'E';
    if (normalized < 157.5) return 'SE';
    if (normalized < 202.5) return 'S';
    if (normalized < 247.5) return 'SW';
    if (normalized < 292.5) return 'W';
    return 'NW';
  }
}

class SensorService {
  SensorService._internal();
  static final SensorService instance = SensorService._internal();

  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<AccelerometerEvent>? _rawAccelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  final ValueNotifier<SensorData> sensorNotifier =
      ValueNotifier<SensorData>(SensorData());

  double _latestAccelX = 0.0;
  double _latestAccelY = 0.0;
  double _latestAccelZ = 0.0;

  double _latestRawAccelX = 0.0;
  double _latestRawAccelY = 9.8;
  double _latestRawAccelZ = 0.0;

  double _latestMagX = 0.0;
  double _latestMagY = 0.0;
  double _latestMagZ = 0.0;

  double? _filteredHeading;
  bool _isCompassAvailable = false;

  void startListening({VoidCallback? onUnavailable}) {
    try {
      // 1. User Accelerometer (tanpa gravitasi, untuk G-Force & hentakan)
      _accelSub = userAccelerometerEventStream().listen(
        (event) {
          _latestAccelX = event.x;
          _latestAccelY = event.y;
          _latestAccelZ = event.z;

          final totalAccel =
              sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          final gForce = (totalAccel / 9.8) + 1.0;

          _emitUpdatedSensorData(
            accelX: _latestAccelX,
            accelY: _latestAccelY,
            accelZ: _latestAccelZ,
            gForce: gForce,
          );
        },
        onError: (e) {
          debugPrint('UserAccelerometer stream error: $e');
          _emitUpdatedSensorData(isSupported: false);
          onUnavailable?.call();
        },
      );

      // 2. Raw Accelerometer (termasuk vektor gravitasi, untuk tilt compensation kompas)
      _rawAccelSub = accelerometerEventStream().listen(
        (event) {
          _latestRawAccelX = event.x;
          _latestRawAccelY = event.y;
          _latestRawAccelZ = event.z;
          _computeHeading();
        },
        onError: (e) {
          debugPrint('Raw Accelerometer stream error: $e');
        },
      );

      // 3. Gyroscope (rotasi rad/s)
      _gyroSub = gyroscopeEventStream().listen(
        (event) {
          _emitUpdatedSensorData(
            gyroX: event.x,
            gyroY: event.y,
            gyroZ: event.z,
          );
        },
        onError: (e) {
          debugPrint('Gyroscope stream error: $e');
        },
      );

      // 4. Magnetometer (medan magnet bumi dalam microTesla, untuk orientasi utara)
      _magSub = magnetometerEventStream().listen(
        (event) {
          _latestMagX = event.x;
          _latestMagY = event.y;
          _latestMagZ = event.z;
          _isCompassAvailable = true;
          _computeHeading();
        },
        onError: (e) {
          debugPrint('Magnetometer stream error: $e');
          _isCompassAvailable = false;
          _emitUpdatedSensorData(isCompassSupported: false);
        },
      );
    } catch (e) {
      debugPrint('Sensor not supported on this platform: $e');
      sensorNotifier.value = SensorData(isSupported: false, isCompassSupported: false);
      onUnavailable?.call();
    }
  }

  void _computeHeading() {
    if (!_isCompassAvailable) return;

    final ax = _latestRawAccelX;
    final ay = _latestRawAccelY;
    final az = _latestRawAccelZ;
    final mx = _latestMagX;
    final my = _latestMagY;
    final mz = _latestMagZ;

    // Jika belum ada data medan magnet valid
    if (mx == 0.0 && my == 0.0 && mz == 0.0) return;

    double calculatedHeading;
    final normA = sqrt(ax * ax + ay * ay + az * az);

    if (normA > 0.5) {
      // Normalisasi vektor gravitasi
      final gX = ax / normA;
      final gY = ay / normA;
      final gZ = az / normA;

      // Sudut Pitch (-90° s/d +90°) dan Roll
      final pitch = asin((-gY).clamp(-1.0, 1.0));
      final cosPitch = cos(pitch);
      final roll = (cosPitch.abs() > 0.001)
          ? asin((gX / cosPitch).clamp(-1.0, 1.0))
          : atan2(gX, gZ);

      // Kompensasi kemiringan (tilt compensation) pada vektor medan magnet
      final xH = mx * cos(pitch) + mz * sin(pitch);
      final yH = mx * sin(roll) * sin(pitch) +
          my * cos(roll) -
          mz * sin(roll) * cos(pitch);

      // Hitung azimuth (derajat 0-360 terhadap kutub utara magnetik)
      final deg = atan2(-xH, yH) * (180.0 / pi);
      calculatedHeading = (deg % 360 + 360) % 360;
    } else {
      // 2D Azimuth datar tanpa kemiringan
      final deg = atan2(-mx, my) * (180.0 / pi);
      calculatedHeading = (deg % 360 + 360) % 360;
    }

    // Filter perataan (low-pass complementary) dengan penanganan putaran 359° <-> 0°
    if (_filteredHeading == null) {
      _filteredHeading = calculatedHeading;
    } else {
      double diff = calculatedHeading - _filteredHeading!;
      while (diff < -180.0) {
        diff += 360.0;
      }
      while (diff > 180.0) {
        diff -= 360.0;
      }
      _filteredHeading = (_filteredHeading! + diff * 0.2) % 360.0;
      if (_filteredHeading! < 0) _filteredHeading = _filteredHeading! + 360.0;
    }

    final heading = _filteredHeading!;
    final direction = SensorData.calculateCardinalDirection(heading);

    _emitUpdatedSensorData(
      heading: heading,
      headingDirection: direction,
      isCompassSupported: true,
      magX: mx,
      magY: my,
      magZ: mz,
    );
  }

  /// Integrasi heading GPS jika perangkat tidak memiliki magnetometer fisik
  void updateGpsHeading(double? gpsHeading) {
    if (_isCompassAvailable || gpsHeading == null || gpsHeading < 0) return;

    final normalized = (gpsHeading % 360 + 360) % 360;
    final direction = SensorData.calculateCardinalDirection(normalized);

    _emitUpdatedSensorData(
      heading: normalized,
      headingDirection: direction,
      isCompassSupported: true,
    );
  }

  void _emitUpdatedSensorData({
    double? accelX,
    double? accelY,
    double? accelZ,
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    double? gForce,
    bool? isSupported,
    double? heading,
    String? headingDirection,
    bool? isCompassSupported,
    double? magX,
    double? magY,
    double? magZ,
  }) {
    final current = sensorNotifier.value;
    sensorNotifier.value = SensorData(
      accelX: accelX ?? current.accelX,
      accelY: accelY ?? current.accelY,
      accelZ: accelZ ?? current.accelZ,
      gyroX: gyroX ?? current.gyroX,
      gyroY: gyroY ?? current.gyroY,
      gyroZ: gyroZ ?? current.gyroZ,
      gForce: gForce ?? current.gForce,
      isSupported: isSupported ?? current.isSupported,
      heading: heading ?? current.heading,
      headingDirection: headingDirection ?? current.headingDirection,
      isCompassSupported: isCompassSupported ?? current.isCompassSupported,
      magX: magX ?? current.magX,
      magY: magY ?? current.magY,
      magZ: magZ ?? current.magZ,
    );
  }

  void stopListening() {
    _accelSub?.cancel();
    _rawAccelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();

    _accelSub = null;
    _rawAccelSub = null;
    _gyroSub = null;
    _magSub = null;
    _filteredHeading = null;
    _isCompassAvailable = false;
  }
}
