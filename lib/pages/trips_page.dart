import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/database_helper.dart';
import '../models/trip_record.dart';
import '../services/location_service.dart';
import '../services/sensor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dynamic_compass_widget.dart';

class PlaceResult {
  final String name;
  final String address;
  final String category; // 'SPBU', 'Bengkel', atau 'Lokasi'
  final double latitude;
  final double longitude;
  final double? distanceKm;

  const PlaceResult({
    required this.name,
    required this.address,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
  });
}

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  final LocationService _locationService = LocationService.instance;
  final SensorService _sensorService = SensorService.instance;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  Position? _currentPosition;

  bool _isLoadingLocation = false;
  bool _isMapReady = false;
  bool _isSearching = false;
  bool _isNavigating = false;
  bool _showSensorPanel = false;

  String _selectedDestination = 'Pilih tempat tujuan';
  double _distanceKm = 0;
  int _durationMinutes = 0;

  PlaceResult? _selectedPlace;
  List<PlaceResult> _searchResults = [];
  String? _searchErrorMessage;
  String? _searchEmptyMessage;
  String _lastSearchQuery = '';

  final List<TripRecord> _savedTrips = [];

  static const LatLng _defaultLocation = LatLng(-7.7971, 110.3708); // Yogyakarta default

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
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // GPS & PERMISSION HANDLING
  // =========================================================

  Future<void> _fetchLocation() async {
    if (_isLoadingLocation) return;

    setState(() => _isLoadingLocation = true);

    try {
      final permCheck = await _locationService.checkAndRequestPermission();

      if (!permCheck.isGranted) {
        if (!mounted) return;
        setState(() => _isLoadingLocation = false);

        _handlePermissionFailure(permCheck);
        return;
      }

      final pos = await _locationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        _currentPosition = pos;
        _isLoadingLocation = false;
      });

      if (pos != null) {
        if (pos.heading >= 0) {
          _sensorService.updateGpsHeading(pos.heading);
        }
        if (_isMapReady) {
          _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
        }
      }

      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sinyal GPS belum terkunci. Pastikan Anda berada di area terbuka dan GPS aktif.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperoleh posisi GPS: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handlePermissionFailure(LocationCheckResult check) {
    if (check.status == LocationPermissionStatus.serviceDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(check.message),
          action: SnackBarAction(
            label: 'Aktifkan GPS',
            textColor: AppTheme.cyan,
            onPressed: () => _locationService.openLocationSettings(),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } else if (check.status == LocationPermissionStatus.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(check.message),
          action: SnackBarAction(
            label: 'Buka Pengaturan',
            textColor: AppTheme.cyan,
            onPressed: () => _locationService.openAppSettings(),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(check.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  LatLng get _mapCenter {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    return _defaultLocation;
  }

  // =========================================================
  // RIWAYAT PERJALANAN
  // =========================================================

  Future<void> _loadTrips() async {
    try {
      final trips = await DatabaseHelper.instance.getTrips();
      if (!mounted) return;
      setState(() {
        _savedTrips
          ..clear()
          ..addAll(trips);
      });
    } catch (e) {
      debugPrint('Gagal memuat riwayat perjalanan: $e');
    }
  }

  // =========================================================
  // PENCARIAN TEMPAT (BENGKEL, SPBU, NOMINATIM)
  // =========================================================

  Future<void> _searchPlaces([String? keyword]) async {
    final query = (keyword ?? _searchController.text).trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nama tempat, bengkel, atau SPBU.')),
      );
      return;
    }

    if (_isSearching) return;

    // 1. Periksa izin lokasi dan status GPS perangkat sebelum melakukan pencarian
    final permCheck = await _locationService.checkAndRequestPermission();
    if (!permCheck.isGranted) {
      _handlePermissionFailure(permCheck);
      return;
    }

    setState(() {
      _isLoadingLocation = true;
      _isSearching = true;
      _searchResults = [];
      _searchErrorMessage = null;
      _searchEmptyMessage = null;
      _lastSearchQuery = query;
    });

    // 2. Ambil koordinat GPS aktual dari perangkat (forceRefresh)
    Position? position;
    try {
      position = await _locationService.getCurrentLocation(forceRefresh: true);
    } catch (e) {
      debugPrint('Error mendapatkan GPS aktual saat pencarian: $e');
    }

    if (!mounted) return;

    // Tangani jika sinyal GPS belum terkunci atau koordinat tidak valid
    if (position == null || (position.latitude == 0.0 && position.longitude == 0.0)) {
      setState(() {
        _isLoadingLocation = false;
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lokasi GPS belum terkunci atau tidak valid. Pastikan GPS aktif dan berada di area terbuka.'),
          action: SnackBarAction(
            label: 'Cek GPS',
            textColor: AppTheme.cyan,
            onPressed: () => _locationService.openLocationSettings(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Perbarui state posisi terkini dengan koordinat GPS aktual
    setState(() {
      _currentPosition = position;
      _isLoadingLocation = false;
    });

    if (position.heading >= 0) {
      _sensorService.updateGpsHeading(position.heading);
    }

    try {
      final normalized = query.toLowerCase();

      final isFuel = normalized.contains('spbu') ||
          normalized.contains('bensin') ||
          normalized.contains('pom bensin') ||
          normalized.contains('pertamina') ||
          normalized.contains('shell') ||
          normalized.contains('gas');

      final isWorkshop = normalized.contains('bengkel') ||
          normalized.contains('servis') ||
          normalized.contains('service') ||
          normalized.contains('reparasi') ||
          normalized.contains('otomotif') ||
          normalized.contains('tambal');

      List<PlaceResult> results;

      if (isFuel || isWorkshop) {
        results = await _searchNearbyPlaces(
          position.latitude,
          position.longitude,
          fuel: isFuel,
          workshop: isWorkshop,
        );
      } else {
        results = await _searchByName(
          query,
          position.latitude,
          position.longitude,
        );
      }

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
        if (results.isEmpty) {
          final categoryName = isFuel && isWorkshop
              ? 'SPBU & bengkel'
              : (isFuel ? 'SPBU' : (isWorkshop ? 'bengkel' : 'tempat'));
          _searchEmptyMessage =
              'Tidak ada $categoryName ditemukan di sekitar lokasi Anda (radius 5 km). Coba beberapa saat lagi atau ubah kata kunci.';
          _searchErrorMessage = null;
        } else {
          _searchEmptyMessage = null;
          _searchErrorMessage = null;
          final first = results.first;
          if (_isMapReady) {
            _mapController.move(LatLng(first.latitude, first.longitude), 14);
          }
        }
      });
    } catch (e) {
      debugPrint('Error pencarian: ');
      if (!mounted) return;

      final errStr = e.toString();
      String friendlyError = 'Pencarian gagal: ';
      if (errStr.contains('504')) {
        friendlyError =
            'Overpass API tidak merespons, HTTP 504. Server peta sedang sibuk, silakan coba lagi.';
      } else if (errStr.contains('TimeoutException') || errStr.contains('kehabisan waktu')) {
        friendlyError =
            'Server peta kehabisan waktu, periksa koneksi internet Anda lalu coba lagi.';
      } else if (errStr.contains('429')) {
        friendlyError =
            'Batas akses Overpass API tercapai (Rate Limit 429). Mohon tunggu beberapa detik sebelum mencoba kembali.';
      } else if (errStr.contains('SocketException') || errStr.contains('Failed host lookup')) {
        friendlyError =
            'Tidak dapat terhubung ke internet. Periksa koneksi data atau Wi-Fi Anda.';
      }

      setState(() {
        _isSearching = false;
        _searchErrorMessage = friendlyError;
        _searchEmptyMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Coba Lagi',
            textColor: AppTheme.cyan,
            onPressed: () => _searchPlaces(query),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<List<PlaceResult>> _searchNearbyPlaces(
    double latitude,
    double longitude, {
    required bool fuel,
    required bool workshop,
  }) async {
    final filters = <String>[];

    if (fuel) {
      filters.add('nwr(around:5000,$latitude,$longitude)["amenity"="fuel"];');
    }

    if (workshop) {
      filters.addAll([
        'nwr(around:5000,$latitude,$longitude)["shop"="car_repair"];',
        'nwr(around:5000,$latitude,$longitude)["craft"="car_repair"];',
        'nwr(around:5000,$latitude,$longitude)["amenity"="car_repair"];',
        'nwr(around:5000,$latitude,$longitude)["shop"="motorcycle_repair"];',
        'nwr(around:5000,$latitude,$longitude)["shop"="tyres"];',
      ]);
    }

    final query = '''
[out:json][timeout:15];
(
  ${filters.join('\n')}
);
out center tags;
''';

    final mirrors = [
      'https://overpass-api.de/api/interpreter',
      'https://lz4.overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ];

    http.Response? response;
    String lastError = '';

    for (final mirror in mirrors) {
      try {
        response = await http
            .post(
              Uri.parse(mirror),
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
                'User-Agent': 'DriveMateApp/1.0 (contact: student@drivemate.id)',
                'Accept': 'application/json',
              },
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          break;
        } else if (response.statusCode == 429) {
          lastError = 'HTTP 429 (Rate limit)';
          debugPrint('Overpass  returned 429, trying next mirror...');
          await Future.delayed(const Duration(milliseconds: 300));
        } else if (response.statusCode == 504) {
          lastError = 'HTTP 504 (Gateway Timeout)';
          debugPrint('Overpass  returned 504, trying next mirror...');
          await Future.delayed(const Duration(milliseconds: 300));
        } else {
          lastError = 'HTTP ${response.statusCode}';
          debugPrint('Overpass  returned ${response.statusCode}, trying next mirror...');
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('Mirror  failed: ');
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    // Jika server Overpass mengalami 504/timeout, gunakan OpenStreetMap Nominatim sebagai fallback resmi dengan viewbox berpusat pada GPS pengguna
    if (response == null || response.statusCode != 200) {
      debugPrint('Overpass mirrors tidak merespons ($lastError). Beralih ke OpenStreetMap Nominatim fallback...');
      try {
        final fallbackKeyword = fuel && workshop
            ? 'SPBU'
            : (fuel ? 'SPBU' : 'Bengkel Mobil');
        final fallbackResults = await _searchByName(
          fallbackKeyword,
          latitude,
          longitude,
          radiusKm: 8.0,
          restrictToRadius: true,
        );
        if (fallbackResults.isNotEmpty) {
          return fallbackResults;
        }
      } catch (nominatimErr) {
        debugPrint('Nominatim fallback juga gagal: $nominatimErr');
      }

      if (lastError.contains('504')) {
        throw Exception('Overpass API tidak merespons, HTTP 504.');
      } else if (lastError.contains('TimeoutException') || lastError.contains('kehabisan waktu')) {
        throw Exception('Server peta kehabisan waktu, periksa koneksi internet.');
      } else {
        throw Exception('Server Overpass API tidak merespons ($lastError).');
      }
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];

    final places = <PlaceResult>[];
    final seenCoordinates = <String>{};

    for (final item in elements) {
      final element = item as Map<String, dynamic>;
      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final center = element['center'] as Map<String, dynamic>?;

      final rawLat = element['lat'] ?? center?['lat'];
      final rawLon = element['lon'] ?? center?['lon'];
      if (rawLat == null || rawLon == null) continue;

      final lat = double.tryParse(rawLat.toString());
      final lon = double.tryParse(rawLon.toString());
      if (lat == null || lon == null) continue;

      // Hindari duplikasi lokasi yang berdekatan dari node dan way yang sama
      final coordKey = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
      if (seenCoordinates.contains(coordKey)) continue;
      seenCoordinates.add(coordKey);

      final amenity = tags['amenity']?.toString();
      final shop = tags['shop']?.toString();
      final isFuelNode = amenity == 'fuel' || tags.containsKey('fuel');

      String? name = tags['name']?.toString().trim();
      if (name == null || name.isEmpty) {
        final brand = tags['brand']?.toString().trim();
        final operatorName = tags['operator']?.toString().trim();
        if (brand != null && brand.isNotEmpty) {
          name = 'SPBU $brand';
        } else if (operatorName != null && operatorName.isNotEmpty) {
          name = 'SPBU $operatorName';
        } else {
          name = isFuelNode ? 'SPBU' : 'Bengkel Otomotif';
        }
      }

      final category = isFuelNode
          ? 'SPBU'
          : (shop == 'car_repair' || tags['craft'] == 'car_repair' ? 'Bengkel' : (fuel ? 'SPBU' : 'Bengkel'));

      final addressParts = [
        tags['addr:street'],
        tags['addr:suburb'],
        tags['addr:city'],
      ].where((v) => v != null && v.toString().trim().isNotEmpty);

      final address = addressParts.isNotEmpty
          ? addressParts.join(', ')
          : (tags['operator']?.toString() ??
              tags['brand']?.toString() ??
              'Koordinat: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}');

      final distanceKm = LocationService.instance.calculateDistance(
        latitude,
        longitude,
        lat,
        lon,
      );

      places.add(
        PlaceResult(
          name: name,
          address: address,
          category: category,
          latitude: lat,
          longitude: lon,
          distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
        ),
      );
    }

    places.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
    return places.take(25).toList();
  }

  Future<List<PlaceResult>> _searchByName(
    String query,
    double latitude,
    double longitude, {
    double radiusKm = 15.0,
    bool restrictToRadius = false,
  }) async {
    // Hitung batas geografis viewbox berdasarkan koordinat aktual pengguna
    final deltaLat = radiusKm / 111.0;
    final latRad = latitude * (math.pi / 180.0);
    final cosLat = math.cos(latRad).abs().clamp(0.1, 1.0);
    final deltaLon = radiusKm / (111.0 * cosLat);

    final minLon = longitude - deltaLon;
    final maxLon = longitude + deltaLon;
    final minLat = latitude - deltaLat;
    final maxLat = latitude + deltaLat;

    final viewboxStr =
        "${minLon.toStringAsFixed(6)},${maxLat.toStringAsFixed(6)},${maxLon.toStringAsFixed(6)},${minLat.toStringAsFixed(6)}";

    final queryParams = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'limit': '25',
      'viewbox': viewboxStr,
      'addressdetails': '1',
    };

    if (restrictToRadius) {
      queryParams['bounded'] = '1';
    }

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      queryParams,
    );

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'DriveMateApp/1.0 (contact: student@drivemate.id)',
        'Accept-Language': 'id',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Layanan pencarian alamat OpenStreetMap tidak tersedia (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    final places = <PlaceResult>[];

    for (final item in data) {
      final result = item as Map<String, dynamic>;
      final lat = double.tryParse(result['lat']?.toString() ?? '');
      final lon = double.tryParse(result['lon']?.toString() ?? '');
      if (lat == null || lon == null) continue;

      final dist = LocationService.instance.calculateDistance(latitude, longitude, lat, lon);

      // Jika dibatasi radius (misal pencarian fallback SPBU/bengkel), saring objek yang berada di luar radius
      if (restrictToRadius && dist > radiusKm) {
        continue;
      }

      final normalizedQ = query.toLowerCase();
      final isFuelSearch = normalizedQ.contains('spbu') ||
          normalizedQ.contains('bensin') ||
          normalizedQ.contains('pertamina') ||
          normalizedQ.contains('shell');
      final isWorkshopSearch = normalizedQ.contains('bengkel') ||
          normalizedQ.contains('servis');

      final category = isFuelSearch ? 'SPBU' : (isWorkshopSearch ? 'Bengkel' : 'Tempat');

      places.add(
        PlaceResult(
          name: result['name']?.toString().trim().isNotEmpty == true
              ? result['name'].toString()
              : (result['display_name']?.toString().split(',').first ?? query),
          address: result['display_name']?.toString() ?? '',
          category: category,
          latitude: lat,
          longitude: lon,
          distanceKm: double.parse(dist.toStringAsFixed(2)),
        ),
      );
    }

    places.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
    return places;
  }

  // =========================================================
  // PEMILIHAN TEMPAT & NAVIGASI GOOGLE MAPS
  // =========================================================

  void _selectPlace(PlaceResult place) {
    final origin = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultLocation;

    final distance = Distance().as(
      LengthUnit.Kilometer,
      origin,
      LatLng(place.latitude, place.longitude),
    );

    setState(() {
      _selectedPlace = place;
      _selectedDestination = place.name;
      _distanceKm = double.parse(distance.toStringAsFixed(1));
      _durationMinutes = (distance / 30 * 60).ceil();
      if (_durationMinutes < 1) _durationMinutes = 1;
      _searchController.text = place.name;
    });

    if (_isMapReady) {
      _mapController.move(LatLng(place.latitude, place.longitude), 16);
    }
  }

  Future<bool> _openGoogleMaps() async {
    final place = _selectedPlace;
    if (place == null) return false;

    // Coba URL scheme standar google maps navigation terlebih dahulu
    final nativeUri = Uri.parse('google.navigation:q=${place.latitude},${place.longitude}&mode=d');
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '${_currentPosition != null ? "&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}" : ""}'
      '&destination=${place.latitude},${place.longitude}&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri);
      }
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Gagal membuka Maps: $e');
      try {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak dapat membuka aplikasi peta: $err')),
          );
        }
        return false;
      }
    }
  }

  Future<void> _startNavigation() async {
    if (_isNavigating) {
      _stopNavigation();
      return;
    }

    if (_selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih salah satu tempat tujuan dari hasil pencarian terlebih dahulu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final place = _selectedPlace!;
    setState(() => _isNavigating = true);

    final trip = TripRecord(
      destination: place.name,
      distanceKm: _distanceKm,
      durationMinutes: _durationMinutes,
      date: DateTime.now().toIso8601String().split('T').first,
      startLocation: _currentPosition != null
          ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(5)}'
          : 'Lokasi Pengguna',
      notes: 'Kategori: ${place.category}. Navigasi rute aktif.',
    );

    try {
      await DatabaseHelper.instance.addTrip(trip);
      await _loadTrips();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Membuka rute ke ${place.name} di Google Maps...'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _openGoogleMaps();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isNavigating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan perjalanan: $e')),
      );
    }
  }

  void _stopNavigation() {
    setState(() => _isNavigating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Status navigasi DriveMate dihentikan.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // INFORMASI LALU LINTAS (Transparan & Fungsional)
  // =========================================================

  void _showTrafficInfoModal() {
    final pos = _currentPosition;
    final now = DateTime.now();
    final hour = now.hour;

    // Perkiraan jam sibuk umum
    final isRushHour = (hour >= 7 && hour <= 9) || (hour >= 16 && hour <= 19);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.traffic_rounded, color: AppTheme.warning, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Lalu Lintas',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pantauan kemacetan jalan & kondisi rute',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2EAF4)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isRushHour ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                          color: isRushHour ? AppTheme.warning : AppTheme.success,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isRushHour
                                ? 'Peringatan Jam Sibuk (${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}): Potensi kepadatan di jalan utama.'
                                : 'Kondisi Jam Normal (${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}): Arus kendaraan cenderung lancar.',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: Color(0xFFE5EDF7)),
                    const Text(
                      'Catatan Layanan Peta:\n'
                      'Peta lokal DriveMate menggunakan tile OpenStreetMap gratis yang tidak menyediakan overlay kemacetan real-time berbayar (seperti Google Maps Traffic / TomTom Traffic API). Untuk melihat kemacetan aktual secara langsung di peta, gunakan tombol pantauan live di bawah.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (pos != null) {
                      final trafficUri = Uri.parse(
                        'https://www.google.com/maps/@${pos.latitude},${pos.longitude},14z/data=!5m1!1e1',
                      );
                      await launchUrl(trafficUri, mode: LaunchMode.externalApplication);
                    } else {
                      final trafficUri = Uri.parse('https://www.google.com/maps/@?api=1&map_action=map&layer=traffic');
                      await launchUrl(trafficUri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.map_rounded, size: 20),
                  label: const Text('Buka Pantauan Lalu Lintas di Google Maps', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // INFORMASI CUACA (Open-Meteo)
  // =========================================================

  Future<void> _showWeather() async {
    if (_currentPosition == null) {
      await _fetchLocation();
    }

    if (!mounted) return;
    final position = _currentPosition;

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktifkan GPS untuk melihat cuaca di sekitar Anda.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            SizedBox(width: 16),
            Expanded(child: Text('Memuat informasi cuaca GPS...')),
          ],
        ),
      ),
    );

    try {
      final uri = Uri.https(
        'api.open-meteo.com',
        '/v1/forecast',
        {
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
          'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m',
          'timezone': 'auto',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode != 200) {
        throw Exception('Server cuaca HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>;

      final temp = current['temperature_2m'];
      final feelsLike = current['apparent_temperature'];
      final humidity = current['relative_humidity_2m'];
      final wind = current['wind_speed_10m'];
      final rain = current['precipitation'];
      final code = (current['weather_code'] as num).toInt();

      String condition = 'Cerah berawan';
      IconData weatherIcon = Icons.wb_sunny_rounded;

      if (code == 0) {
        condition = 'Cerah';
        weatherIcon = Icons.wb_sunny_rounded;
      } else if ([1, 2, 3].contains(code)) {
        condition = 'Cerah berawan / Berawan';
        weatherIcon = Icons.cloud_rounded;
      } else if ([45, 48].contains(code)) {
        condition = 'Berkabut';
        weatherIcon = Icons.foggy;
      } else if ([51, 53, 55, 61, 63, 65, 80, 81].contains(code)) {
        condition = 'Hujan / Gerimis';
        weatherIcon = Icons.water_drop_rounded;
      } else if ([95, 96, 99].contains(code)) {
        condition = 'Badai Petir';
        weatherIcon = Icons.thunderstorm_rounded;
      }

      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (dlgContext) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Cuaca Terkini GPS', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(weatherIcon, size: 50, color: AppTheme.primary),
              const SizedBox(height: 8),
              Text(
                '${(temp as num).toStringAsFixed(1)} °C',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Text(condition, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Divider(height: 20),
              _weatherRow('Terasa seperti', '${(feelsLike as num).toStringAsFixed(1)} °C'),
              _weatherRow('Kelembapan', '$humidity%'),
              _weatherRow('Kecepatan angin', '$wind km/jam'),
              _weatherRow('Curah hujan', '$rain mm'),
              const SizedBox(height: 8),
              const Text('Sumber data cuaca: Open-Meteo', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat cuaca: $e')),
      );
    }
  }

  Widget _weatherRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // =========================================================
  // WIDGET BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Sensor Toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
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
                        tooltip: 'Sensor Kendaraan',
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) => _searchPlaces(v),
                    decoration: InputDecoration(
                      hintText: 'Cari lokasi, bengkel terdekat, SPBU...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Cari',
                              icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.primary),
                              onPressed: () => _searchPlaces(),
                            ),
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

            // Indikator Hasil Pencarian Kosong (Bukan Gangguan Jaringan)
            if (_searchEmptyMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_off_rounded, color: AppTheme.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _searchEmptyMessage!,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                      onPressed: () => setState(() => _searchEmptyMessage = null),
                    ),
                  ],
                ),
              ),

            // Indikator Gangguan Server Peta atau Jaringan
            if (_searchErrorMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: AppTheme.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _searchErrorMessage!,
                        style: const TextStyle(fontSize: 11, color: AppTheme.danger, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_lastSearchQuery.isNotEmpty)
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        onPressed: () => _searchPlaces(_lastSearchQuery),
                        child: const Text('Coba Lagi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),

            // Daftar Hasil Pencarian
            if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD6E2F0)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = _searchResults[index];
                    final isFuel = place.category == 'SPBU';
                    final isWorkshop = place.category == 'Bengkel';

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isFuel
                            ? const Color(0xFFFFA53D).withValues(alpha: 0.15)
                            : (isWorkshop ? AppTheme.primary.withValues(alpha: 0.15) : Colors.grey.shade200),
                        child: Icon(
                          isFuel
                              ? Icons.local_gas_station_rounded
                              : (isWorkshop ? Icons.car_repair_rounded : Icons.location_on_rounded),
                          color: isFuel ? const Color(0xFFFFA53D) : (isWorkshop ? AppTheme.primary : Colors.grey.shade700),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${place.category} • ${place.distanceKm != null ? "${place.distanceKm} km • " : ""}${place.address}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                      onTap: () => _selectPlace(place),
                    );
                  },
                ),
              ),

            if (_showSensorPanel) _buildSensorPanel(),

            // Peta OpenStreetMap dengan Pin Marker Hasil
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
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _mapCenter,
                        initialZoom: 15,
                        onMapReady: () {
                          _isMapReady = true;
                          if (_currentPosition != null) {
                            _mapController.move(_mapCenter, 16);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.drivemate',
                        ),

                        // Marker GPS Pengguna
                        if (_currentPosition != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _mapCenter,
                                width: 44,
                                height: 44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.my_location_rounded,
                                    color: AppTheme.primary,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        // Marker Hasil Pencarian (Bengkel, SPBU, Lokasi)
                        if (_searchResults.isNotEmpty)
                          MarkerLayer(
                            markers: _searchResults.map((place) {
                              final isSelected = _selectedPlace == place;
                              final isFuel = place.category == 'SPBU';
                              final isWorkshop = place.category == 'Bengkel';

                              final markerColor = isSelected
                                  ? Colors.red
                                  : (isFuel ? const Color(0xFFFFA53D) : (isWorkshop ? AppTheme.primary : Colors.teal));

                              return Marker(
                                point: LatLng(place.latitude, place.longitude),
                                width: isSelected ? 44 : 36,
                                height: isSelected ? 44 : 36,
                                child: GestureDetector(
                                  onTap: () => _selectPlace(place),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: markerColor, width: isSelected ? 2.5 : 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isFuel
                                          ? Icons.local_gas_station_rounded
                                          : (isWorkshop ? Icons.car_repair_rounded : Icons.location_on_rounded),
                                      color: markerColor,
                                      size: isSelected ? 24 : 20,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Peta © OpenStreetMap contributors')),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status GPS Tag
                  Positioned(
                    top: 16,
                    left: 36,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentPosition != null ? AppTheme.primary : AppTheme.warning,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _currentPosition != null ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _currentPosition != null ? 'GPS Aktif' : 'GPS Menunggu',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
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
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded, size: 18),
                    ),
                  ),

                  // Kompas Dinamis Real-Time
                  Positioned(
                    top: 68,
                    right: 36,
                    child: DynamicCompassWidget(
                      size: 96,
                      onTap: () {
                        if (_isMapReady && _currentPosition != null) {
                          _mapController.move(_mapCenter, _mapController.camera.zoom);
                        }
                      },
                    ),
                  ),

                  // Card Tujuan & Tombol Navigasi
                  Positioned(
                    left: 36,
                    right: 36,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.navy.withValues(alpha: 0.1),
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
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.navigation_rounded, color: AppTheme.primary, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedDestination,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _selectedPlace == null
                                          ? 'Pilih bengkel atau SPBU di daftar'
                                          : '${_selectedPlace!.category} • $_distanceKm km • perkiraan $_durationMinutes menit',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _isNavigating ? AppTheme.danger : AppTheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _startNavigation,
                              icon: Icon(_isNavigating ? Icons.stop_rounded : Icons.directions_rounded, size: 20),
                              label: Text(
                                _isNavigating ? 'Hentikan Navigasi' : 'Buka Navigasi Rute',
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

            const SizedBox(height: 10),

            // Tombol Pintasan (Bengkel, SPBU, Cuaca, Info Lalu Lintas)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _poiButton(
                      icon: Icons.car_repair_rounded,
                      label: 'Bengkel',
                      onTap: () {
                        _searchController.text = 'bengkel terdekat';
                        _searchPlaces('bengkel terdekat');
                      },
                    ),
                  ),
                  Expanded(
                    child: _poiButton(
                      icon: Icons.local_gas_station_rounded,
                      label: 'SPBU',
                      onTap: () {
                        _searchController.text = 'SPBU terdekat';
                        _searchPlaces('SPBU terdekat');
                      },
                    ),
                  ),
                  Expanded(
                    child: _poiButton(
                      icon: Icons.cloud_outlined,
                      label: 'Cuaca',
                      onTap: _showWeather,
                    ),
                  ),
                  Expanded(
                    child: _poiButton(
                      icon: Icons.traffic_rounded,
                      label: 'Lalu Lintas',
                      onTap: _showTrafficInfoModal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
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
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD8E4F2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  const Text(
                    'Monitoring Sensor Nyata',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _sensorStat(
                      label: 'Accelerometer',
                      value: '${data.gForce.toStringAsFixed(2)} G',
                      sub: 'X: ${data.accelX.toStringAsFixed(1)}  Y: ${data.accelY.toStringAsFixed(1)}',
                    ),
                  ),
                  Container(width: 1, height: 42, color: const Color(0xFFE2E9F3)),
                  Expanded(
                    child: _sensorStat(
                      label: 'Gyroscope',
                      value: '${data.gyroZ.toStringAsFixed(2)} rad/s',
                      sub: 'X: ${data.gyroX.toStringAsFixed(1)}  Y: ${data.gyroY.toStringAsFixed(1)}',
                    ),
                  ),
                  Container(width: 1, height: 42, color: const Color(0xFFE2E9F3)),
                  Expanded(
                    child: _sensorStat(
                      label: 'Kompas Hadap',
                      value: data.heading != null
                          ? "${data.heading!.toStringAsFixed(0)}° ${data.headingDirection}"
                          : '--',
                      sub: data.isCompassSupported
                          ? 'Sensor Kompas Aktif'
                          : 'Sensor Tidak Aktif',
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
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary)),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
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
              maxLines: 1,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
