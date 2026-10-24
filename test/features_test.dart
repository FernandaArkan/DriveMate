import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivemate/services/location_service.dart';
import 'package:drivemate/services/ai_service.dart';
import 'package:drivemate/services/activity_service.dart';
import 'package:drivemate/repositories/user_repository.dart';
import 'package:drivemate/pages/trips_page.dart';
import 'package:drivemate/services/sensor_service.dart';

void main() {
  group('DriveMate New Features Unit Tests', () {
    test('LocationService calculates distance accurately in km', () {
      final loc = LocationService.instance;
      final distance = loc.calculateDistance(-6.1754, 106.8272, -6.1950, 106.8230);
      expect(distance, greaterThan(2.0));
      expect(distance, lessThan(3.0));
    });

    test('AiChatMessage stores attributes properly', () {
      final msg = AiChatMessage(
        text: 'Bagaimana cara cek oli?',
        isUser: true,
        time: '10:00',
      );
      expect(msg.text, 'Bagaimana cara cek oli?');
      expect(msg.isUser, true);
      expect(msg.time, '10:00');
      expect(msg.isError, false);
    });

    test('AuthResult instantiates successfully', () {
      const successResult = AuthResult(
        isSuccess: true,
        message: 'Registrasi sukses',
      );
      expect(successResult.isSuccess, true);
      expect(successResult.message, 'Registrasi sukses');

      const failResult = AuthResult(
        isSuccess: false,
        message: 'Email sudah terdaftar',
      );
      expect(failResult.isSuccess, false);
      expect(failResult.message, 'Email sudah terdaftar');
    });

    test('PlaceResult models and categories work correctly', () {
      const spbu = PlaceResult(
        name: 'SPBU Pertamina 31.123',
        address: 'Jl. Malioboro',
        category: 'SPBU',
        latitude: -7.79,
        longitude: 110.36,
        distanceKm: 1.25,
      );
      expect(spbu.category, 'SPBU');
      expect(spbu.distanceKm, 1.25);
    });

    test('UserActivity model formats properly', () {
      final act = UserActivity(
        id: 'test_1',
        category: ActivityCategory.vehicle,
        title: 'Mobil Ditambahkan',
        description: 'Honda Civic 2022',
        dateTime: DateTime(2026, 10, 22, 14, 30),
        icon: Icons.directions_car_rounded,
        color: Colors.blue,
      );
      expect(act.category, ActivityCategory.vehicle);
      expect(act.formattedDate, contains('2026'));
    });

    test('SensorData calculateCardinalDirection correctly maps 8 compass directions', () {
      expect(SensorData.calculateCardinalDirection(0), 'N');
      expect(SensorData.calculateCardinalDirection(360), 'N');
      expect(SensorData.calculateCardinalDirection(45), 'NE');
      expect(SensorData.calculateCardinalDirection(90), 'E');
      expect(SensorData.calculateCardinalDirection(135), 'SE');
      expect(SensorData.calculateCardinalDirection(180), 'S');
      expect(SensorData.calculateCardinalDirection(225), 'SW');
      expect(SensorData.calculateCardinalDirection(270), 'W');
      expect(SensorData.calculateCardinalDirection(315), 'NW');
      expect(SensorData.calculateCardinalDirection(null), '--');
    });

    test('Compass 0-360 wrap-around shortest angular difference calculation', () {
      // 359° to 1° should be +2° (clockwise), not -358°
      double currentAngle = 359.0;
      double targetHeading = 1.0;
      double diff = targetHeading - (currentAngle % 360.0);
      while (diff < -180.0) {
        diff += 360.0;
      }
      while (diff > 180.0) {
        diff -= 360.0;
      }
      expect(diff, 2.0);

      // 1° to 359° should be -2° (counter-clockwise), not +358°
      currentAngle = 1.0;
      targetHeading = 359.0;
      diff = targetHeading - (currentAngle % 360.0);
      while (diff < -180.0) {
        diff += 360.0;
      }
      while (diff > 180.0) {
        diff -= 360.0;
      }
      expect(diff, -2.0);
    });
  });
}
