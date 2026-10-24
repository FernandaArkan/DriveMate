import 'dart:math';
import 'package:flutter/material.dart';
import '../services/sensor_service.dart';
import '../theme/app_theme.dart';

class DynamicCompassWidget extends StatefulWidget {
  const DynamicCompassWidget({
    super.key,
    this.size = 110.0,
    this.compact = false,
    this.onTap,
  });

  final double size;
  final bool compact;
  final VoidCallback? onTap;

  @override
  State<DynamicCompassWidget> createState() => _DynamicCompassWidgetState();
}

class _DynamicCompassWidgetState extends State<DynamicCompassWidget> {
  double _continuousAngle = 0.0;
  bool _initialized = false;

  void _updateAngle(double targetHeading) {
    if (!_initialized) {
      _continuousAngle = targetHeading;
      _initialized = true;
      return;
    }

    // Hitung jarak sudut terpendek untuk mencegah lonjakan rotasi 359° <-> 0°
    double diff = targetHeading - (_continuousAngle % 360.0);
    while (diff < -180.0) {
      diff += 360.0;
    }
    while (diff > 180.0) {
      diff -= 360.0;
    }

    _continuousAngle += diff;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SensorData>(
      valueListenable: SensorService.instance.sensorNotifier,
      builder: (context, sensorData, _) {
        final heading = sensorData.heading;
        final hasCompass = sensorData.isCompassSupported && heading != null;

        if (hasCompass) {
          _updateAngle(heading);
        }

        if (widget.compact) {
          return _buildCompactView(hasCompass, heading, sensorData.headingDirection);
        }

        return _buildFullCompassCard(hasCompass, heading, sensorData.headingDirection);
      },
    );
  }

  Widget _buildCompactView(bool hasCompass, double? heading, String direction) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: const Color(0xFFD6E2F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: hasCompass
                  ? TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: _continuousAngle, end: _continuousAngle),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutQuad,
                      builder: (context, angle, _) {
                        return Transform.rotate(
                          angle: -angle * (pi / 180.0),
                          child: const _MiniCompassDial(),
                        );
                      },
                    )
                  : const Icon(Icons.explore_off_rounded, color: AppTheme.textSecondary, size: 20),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasCompass ? '${heading!.toStringAsFixed(0)}° $direction' : 'Sensor Mati',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  hasCompass ? 'Arah Hadap' : 'Tidak Ada Kompas',
                  style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCompassCard(bool hasCompass, double? heading, String direction) {
    final size = widget.size;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFD8E4F2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indikator Puncak Arah Hadap
            Container(
              width: 8,
              height: 6,
              decoration: const BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
            const SizedBox(height: 2),

            // Piringan Kompas Berputar Dinamis
            SizedBox(
              width: size - 24,
              height: size - 24,
              child: hasCompass
                  ? TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: _continuousAngle, end: _continuousAngle),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      builder: (context, angle, _) {
                        return Transform.rotate(
                          angle: -angle * (pi / 180.0),
                          child: CustomPaint(
                            size: Size(size - 24, size - 24),
                            painter: _CompassDialPainter(),
                          ),
                        );
                      },
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(size - 24, size - 24),
                          painter: _CompassDialPainter(isInactive: true),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'Sensor\nTidak Aktif',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.warning),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 4),

            // Nilai Derajat & Arah Kardinal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hasCompass
                    ? '${heading!.toStringAsFixed(0)}° $direction'
                    : 'Tidak Tersedia',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: hasCompass ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCompassDial extends StatelessWidget {
  const _MiniCompassDial();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(32, 32),
      painter: _MiniCompassPainter(),
    );
  }
}

class _MiniCompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final circlePaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, circlePaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 1, borderPaint);

    // Jarum Merah (Utara / N)
    final northPath = Path()
      ..moveTo(center.dx, center.dy - radius + 3)
      ..lineTo(center.dx - 3, center.dy)
      ..lineTo(center.dx + 3, center.dy)
      ..close();
    final northPaint = Paint()..color = AppTheme.danger;
    canvas.drawPath(northPath, northPaint);

    // Jarum Abu-abu (Selatan / S)
    final southPath = Path()
      ..moveTo(center.dx, center.dy + radius - 3)
      ..lineTo(center.dx - 3, center.dy)
      ..lineTo(center.dx + 3, center.dy)
      ..close();
    final southPaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawPath(southPath, southPaint);

    // Titik tengah
    canvas.drawCircle(center, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompassDialPainter extends CustomPainter {
  _CompassDialPainter({this.isInactive = false});

  final bool isInactive;

  static const List<Map<String, dynamic>> directions = [
    {'name': 'N', 'angle': 0.0, 'isMajor': true, 'color': AppTheme.danger},
    {'name': 'NE', 'angle': 45.0, 'isMajor': false},
    {'name': 'E', 'angle': 90.0, 'isMajor': true},
    {'name': 'SE', 'angle': 135.0, 'isMajor': false},
    {'name': 'S', 'angle': 180.0, 'isMajor': true},
    {'name': 'SW', 'angle': 225.0, 'isMajor': false},
    {'name': 'W', 'angle': 270.0, 'isMajor': true},
    {'name': 'NW', 'angle': 315.0, 'isMajor': false},
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background lingkaran kompas
    final bgPaint = Paint()
      ..color = isInactive ? const Color(0xFFF8FAFC) : const Color(0xFFF1F6FB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final rimPaint = Paint()
      ..color = const Color(0xFFD6E2F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 1, rimPaint);

    // Gambar garis-garis derajat (ticks)
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int deg = 0; deg < 360; deg += 15) {
      final rad = (deg - 90) * (pi / 180.0);
      final isMajor = deg % 45 == 0;
      final isNorth = deg == 0;

      tickPaint.color = isInactive
          ? const Color(0xFFCBD5E1)
          : (isNorth ? AppTheme.danger : (isMajor ? AppTheme.textPrimary : const Color(0xFF94A3B8)));
      tickPaint.strokeWidth = isMajor ? 1.8 : 1.0;

      final tickLength = isMajor ? 6.0 : 3.5;
      final start = Offset(
        center.dx + (radius - 4) * cos(rad),
        center.dy + (radius - 4) * sin(rad),
      );
      final end = Offset(
        center.dx + (radius - 4 - tickLength) * cos(rad),
        center.dy + (radius - 4 - tickLength) * sin(rad),
      );

      canvas.drawLine(start, end, tickPaint);
    }

    // Gambar penanda N, NE, E, SE, S, SW, W, NW
    final textRadius = radius - 15.0;

    for (final dir in directions) {
      final deg = dir['angle'] as double;
      final name = dir['name'] as String;
      final isMajor = dir['isMajor'] as bool;
      final rad = (deg - 90) * (pi / 180.0);

      final textColor = isInactive
          ? const Color(0xFF94A3B8)
          : (name == 'N'
              ? AppTheme.danger
              : (isMajor ? AppTheme.textPrimary : const Color(0xFF64748B)));

      final textSpan = TextSpan(
        text: name,
        style: TextStyle(
          color: textColor,
          fontSize: isMajor ? 9.5 : 7.5,
          fontWeight: isMajor ? FontWeight.w900 : FontWeight.w700,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final x = center.dx + textRadius * cos(rad) - (textPainter.width / 2);
      final y = center.dy + textRadius * sin(rad) - (textPainter.height / 2);

      textPainter.paint(canvas, Offset(x, y));
    }

    // Jarum Kompas Klasik Tengah (Merah ke Utara, Biru Tua ke Selatan)
    final needleLength = radius * 0.45;
    final needleWidth = 4.0;

    // Jarum Merah (Utara / 0°)
    final northPath = Path()
      ..moveTo(center.dx, center.dy - needleLength)
      ..lineTo(center.dx - needleWidth, center.dy)
      ..lineTo(center.dx + needleWidth, center.dy)
      ..close();
    final northPaint = Paint()
      ..color = isInactive ? const Color(0xFFCBD5E1) : AppTheme.danger
      ..style = PaintingStyle.fill;
    canvas.drawPath(northPath, northPaint);

    // Jarum Biru/Abu (Selatan / 180°)
    final southPath = Path()
      ..moveTo(center.dx, center.dy + needleLength)
      ..lineTo(center.dx - needleWidth, center.dy)
      ..lineTo(center.dx + needleWidth, center.dy)
      ..close();
    final southPaint = Paint()
      ..color = isInactive ? const Color(0xFFE2E8F0) : const Color(0xFF475569)
      ..style = PaintingStyle.fill;
    canvas.drawPath(southPath, southPaint);

    // Titik pusat
    final pivotOuter = Paint()..color = Colors.white;
    final pivotInner = Paint()..color = isInactive ? const Color(0xFF94A3B8) : AppTheme.primary;
    canvas.drawCircle(center, 4, pivotOuter);
    canvas.drawCircle(center, 2, pivotInner);
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) =>
      oldDelegate.isInactive != isInactive;
}
