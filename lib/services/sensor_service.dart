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
  });

  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double gForce;
  final bool isSupported;
}

class SensorService {
  SensorService._internal();
  static final SensorService instance = SensorService._internal();

  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  final ValueNotifier<SensorData> sensorNotifier = ValueNotifier<SensorData>(SensorData());

  double _latestAccelX = 0.0;
  double _latestAccelY = 0.0;
  double _latestAccelZ = 0.0;

  void startListening({VoidCallback? onUnavailable}) {
    try {
      _accelSub = userAccelerometerEventStream().listen(
        (event) {
          _latestAccelX = event.x;
          _latestAccelY = event.y;
          _latestAccelZ = event.z;

          final totalAccel = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          final gForce = (totalAccel / 9.8) + 1.0;

          sensorNotifier.value = SensorData(
            accelX: _latestAccelX,
            accelY: _latestAccelY,
            accelZ: _latestAccelZ,
            gyroX: sensorNotifier.value.gyroX,
            gyroY: sensorNotifier.value.gyroY,
            gyroZ: sensorNotifier.value.gyroZ,
            gForce: gForce,
            isSupported: true,
          );
        },
        onError: (e) {
          debugPrint('Accelerometer stream error: $e');
          sensorNotifier.value = SensorData(isSupported: false);
          onUnavailable?.call();
        },
      );

      _gyroSub = gyroscopeEventStream().listen(
        (event) {
          sensorNotifier.value = SensorData(
            accelX: _latestAccelX,
            accelY: _latestAccelY,
            accelZ: _latestAccelZ,
            gyroX: event.x,
            gyroY: event.y,
            gyroZ: event.z,
            gForce: sensorNotifier.value.gForce,
            isSupported: true,
          );
        },
        onError: (e) {
          debugPrint('Gyroscope stream error: $e');
          sensorNotifier.value = SensorData(isSupported: false);
          onUnavailable?.call();
        },
      );
    } catch (e) {
      debugPrint('Sensor not supported on this platform: $e');
      sensorNotifier.value = SensorData(isSupported: false);
      onUnavailable?.call();
    }
  }

  void stopListening() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
  }
}
