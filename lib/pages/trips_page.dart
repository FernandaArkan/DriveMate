import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../database/database_helper.dart';
import '../models/trip_record.dart';
import '../services/location_service.dart';
import '../services/sensor_service.dart';
import '../theme/app_theme.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  final LocationService _locationService = LocationService.instance;
  final SensorService _sensorService = SensorService.instance;

  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String _selectedDestination = 'Bengkel AutoCare';
  double _distanceKm = 2.4;
  int _durationMinutes = 8;
  bool _isNavigating = false;
  bool _showSensorPanel = false;

  final List<TripRecord> _savedTrips = [];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _sensorService.startListening();
    _loadTrips();
  }

  @override
  void dispose() {
    _sensorService.stopListening();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLoadingLocation = true);
    final pos = await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _loadTrips() async {
    final trips = await DatabaseHelper.instance.getTrips();
    if (mounted) {
      setState(() {
        _savedTrips
          ..clear()
          ..addAll(trips);
      });
    }
  }

  Future<void> _startNavigation() async {
    setState(() => _isNavigating = true);

    final trip = TripRecord(
      destination: _selectedDestination,
      distanceKm: _distanceKm,
      durationMinutes: _durationMinutes,
      date: DateTime.now().toIso8601String().split('T').first,
      startLocation: _currentPosition != null
          ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(3)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(3)}'
          : 'Lokasi Anda (GPS Aktif)',
      notes: 'Perjalanan dipantau oleh sensor DriveMate',
    );

    await DatabaseHelper.instance.addTrip(trip);
    await _loadTrips();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigasi ke $_selectedDestination dimulai. Riwayat tercatat!'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectQuickPoi(String name, double dist, int dur) {
    setState(() {
      _selectedDestination = name;
      _distanceKm = dist;
      _durationMinutes = dur;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header & Search Bar (Mockup Layar 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Perjalanan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Sensor Kendaraan (G-Force & Gyro)',
                        icon: Icon(
                          _showSensorPanel ? Icons.sensors_rounded : Icons.sensors_outlined,
                          color: AppTheme.primary,
                        ),
                        onPressed: () {
                          setState(() => _showSensorPanel = !_showSensorPanel);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari lokasi, bengkel, SPBU...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // SENSOR PANEL JIKA DIBUKA
            if (_showSensorPanel) _buildSensorPanel(),

            // Interactive Map View Canvas (Mockup Layar 5)
            Expanded(
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEF5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFD6E2F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CustomPaint(
                      painter: _MapRoutePainter(
                        hasGPS: _currentPosition != null,
                      ),
                      child: Container(),
                    ),
                  ),

                  // Pin Lokasi Anda
                  Positioned(
                    top: 60,
                    right: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.my_location_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _currentPosition != null ? 'Lokasi GPS Aktif' : 'Lokasi Anda',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Refresh GPS Button
                  Positioned(
                    top: 16,
                    right: 36,
                    child: FloatingActionButton.small(
                      heroTag: 'refresh_gps',
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      onPressed: _fetchLocation,
                      child: _isLoadingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.gps_fixed_rounded, size: 18),
                    ),
                  ),

                  // Floating Card Navigasi Tujuan (Mockup Layar 5)
                  Positioned(
                    left: 36,
                    right: 36,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.navy.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.cyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: AppTheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tujuan: $_selectedDestination',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$_distanceKm km • $_durationMinutes menit',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _startNavigation,
                              child: Text(
                                _isNavigating ? 'Navigasi Sedang Berjalan' : 'Mulai Navigasi',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 4 Shortcut Cepat Bawah (Mockup Layar 5)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _poiButton(
                      icon: Icons.car_repair_rounded,
                      label: 'Bengkel Terdekat',
                      onTap: () => _selectQuickPoi('Bengkel AutoCare', 2.4, 8),
                    ),
                  ),
                  Expanded(
                    child: _poiButton(
                      icon: Icons.local_gas_station_rounded,
                      label: 'SPBU Terdekat',
                      onTap: () => _selectQuickPoi('SPBU Pertamina 34', 1.1, 4),
                    ),
                  ),
                  Expanded(
                    child: _poiButton(
                      icon: Icons.cloud_outlined,
                      label: 'Cuaca',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cuaca saat ini cerah berawan (29°C). Aman berkendara.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _poiButton(
                      icon: Icons.traffic_rounded,
                      label: 'Info Lalu Lintas',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lalu lintas menuju AutoCare lancar (kecepatan rata-rata 45 km/jam).'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorPanel() {
    return ValueListenableBuilder<SensorData>(
      valueListenable: _sensorService.sensorNotifier,
      builder: (context, data, _) {
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD8E4F2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monitoring Sensor Nyata (Hardware)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: data.isSupported
                          ? AppTheme.success.withValues(alpha: 0.12)
                          : AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data.isSupported ? 'Hardware Aktif' : 'Emulator Mode',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: data.isSupported ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _sensorStat(
                      label: 'Accelerometer (G-Force)',
                      value: '${data.gForce.toStringAsFixed(2)} G',
                      sub: 'X: ${data.accelX.toStringAsFixed(1)} Y: ${data.accelY.toStringAsFixed(1)}',
                    ),
                  ),
                  Container(width: 1, height: 36, color: const Color(0xFFE2E9F3)),
                  Expanded(
                    child: _sensorStat(
                      label: 'Gyroscope (Sudut Belok)',
                      value: '${data.gyroZ.toStringAsFixed(2)} rad/s',
                      sub: 'Roll: ${data.gyroX.toStringAsFixed(1)} Pitch: ${data.gyroY.toStringAsFixed(1)}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sensorStat({required String label, required String value, required String sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary)),
          Text(sub, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _poiButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4EBF5)),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter untuk merender rute jalan peta bergaya modern
class _MapRoutePainter extends CustomPainter {
  _MapRoutePainter({required this.hasGPS});

  final bool hasGPS;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFEDF3FA);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    final roadBorder = Paint()
      ..color = const Color(0xFFD6E3F2)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;

    // Garis-garis jalanan kota
    final path = Path()
      ..moveTo(0, size.height * 0.4)
      ..lineTo(size.width * 0.6, size.height * 0.4)
      ..lineTo(size.width * 0.6, size.height * 0.8)
      ..lineTo(size.width, size.height * 0.8);

    final path2 = Path()
      ..moveTo(size.width * 0.3, 0)
      ..lineTo(size.width * 0.3, size.height)
      ..moveTo(size.width * 0.75, 0)
      ..lineTo(size.width * 0.75, size.height);

    canvas.drawPath(path, roadBorder);
    canvas.drawPath(path, roadPaint);
    canvas.drawPath(path2, roadBorder);
    canvas.drawPath(path2, roadPaint);

    // Jalur rute navigasi biru (Mockup Layar 5)
    final routePaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final routeGlow = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.25)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePath = Path()
      ..moveTo(size.width * 0.75, size.height * 0.2)
      ..lineTo(size.width * 0.75, size.height * 0.4)
      ..lineTo(size.width * 0.3, size.height * 0.4)
      ..lineTo(size.width * 0.3, size.height * 0.65);

    canvas.drawPath(routePath, routeGlow);
    canvas.drawPath(routePath, routePaint);

    // Titik awal (Pin biru lingkaran)
    final startPin = Paint()..color = AppTheme.primary;
    final startInner = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.2), 8, startPin);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.2), 4, startInner);

    // Titik tujuan (Pin merah/cyan)
    final destPin = Paint()..color = AppTheme.danger;
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.65), 9, destPin);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.65), 4, startInner);
  }

  @override
  bool shouldRepaint(covariant _MapRoutePainter oldDelegate) =>
      oldDelegate.hasGPS != hasGPS;
}
