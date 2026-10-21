
import 'dart:convert';

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

class PlaceResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const PlaceResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
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
  final TextEditingController _searchController =
      TextEditingController();

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

  final List<TripRecord> _savedTrips = [];

  static const LatLng _defaultLocation = LatLng(
    -7.7971,
    110.3708,
  );

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
  // GPS
  // =========================================================

  Future<void> _fetchLocation() async {
    if (_isLoadingLocation) return;

    setState(() => _isLoadingLocation = true);

    try {
      final pos = await _locationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        _currentPosition = pos;
        _isLoadingLocation = false;
      });

      if (pos != null && _isMapReady) {
        _mapController.move(
          LatLng(pos.latitude, pos.longitude),
          16,
        );
      }

      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lokasi GPS belum tersedia. '
              'Periksa izin lokasi dan GPS HP.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoadingLocation = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil lokasi GPS: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  LatLng get _mapCenter {
    if (_currentPosition != null) {
      return LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }

    return _defaultLocation;
  }

  // =========================================================
  // DATABASE RIWAYAT PERJALANAN
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
  // PENCARIAN TEMPAT
  // =========================================================

  Future<void> _searchPlaces([String? keyword]) async {
    final query = (keyword ?? _searchController.text).trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nama tempat, bengkel, atau SPBU.'),
        ),
      );
      return;
    }

    if (_isSearching) return;

    if (_currentPosition == null) {
      await _fetchLocation();
    }

    if (!mounted) return;

    final position = _currentPosition;

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lokasi GPS belum tersedia. Aktifkan GPS terlebih dahulu.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final normalized = query.toLowerCase();

      final isFuel = normalized.contains('spbu') ||
          normalized.contains('bensin') ||
          normalized.contains('pom bensin') ||
          normalized.contains('pertamina');

      final isWorkshop = normalized.contains('bengkel') ||
          normalized.contains('servis') ||
          normalized.contains('service') ||
          normalized.contains('otomotif');

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
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tempat tidak ditemukan. Coba kata kunci lain.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('ERROR PENCARIAN DRIVEMATE: $e');
      if (!mounted) return;

      setState(() => _isSearching = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pencarian gagal. Periksa internet lalu coba lagi. ($e)',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Mencari bengkel atau SPBU dalam radius 5 km dari GPS.
  Future<List<PlaceResult>> _searchNearbyPlaces(
    double latitude,
    double longitude, {
    required bool fuel,
    required bool workshop,
  }) async {
    final filters = <String>[];

    if (fuel) {
      filters.add(
        'nwr(around:5000,$latitude,$longitude)'
        '["amenity"="fuel"];',
      );
    }

    if (workshop) {
      filters.addAll([
        'nwr(around:5000,$latitude,$longitude)'
        '["shop"="car_repair"];',
        'nwr(around:5000,$latitude,$longitude)'
        '["craft"="car_repair"];',
        'nwr(around:5000,$latitude,$longitude)'
        '["amenity"="car_repair"];',
      ]);
    }

    final query = '''
[out:json][timeout:25];
(
  ${filters.join('\n')}
);
out center tags;
''';

    final response = await http
        .post(
          Uri.parse('https://overpass.kumi.systems/api/interpreter'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 30));

    debugPrint('=== DEBUG OVERPASS ===');
        debugPrint('Status HTTP: ${response.statusCode}');
          debugPrint('Respons server: ${response.body}');

if (response.statusCode != 200) {
  throw Exception('Overpass HTTP ${response.statusCode}');
}

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>;

    final places = <PlaceResult>[];

    for (final item in elements) {
      final element = item as Map<String, dynamic>;
      final tags =
          element['tags'] as Map<String, dynamic>? ?? {};

      final center =
          element['center'] as Map<String, dynamic>?;

      final lat = element['lat'] ?? center?['lat'];
      final lon = element['lon'] ?? center?['lon'];

      if (lat == null || lon == null) continue;

      final name = tags['name']?.toString().trim();

      final addressParts = [
        tags['addr:housenumber'],
        tags['addr:street'],
        tags['addr:suburb'],
        tags['addr:city'],
      ].where(
        (value) => value != null && value.toString().isNotEmpty,
      );

      places.add(
        PlaceResult(
          name: name != null && name.isNotEmpty
              ? name
              : fuel
                  ? 'SPBU tanpa nama'
                  : 'Bengkel tanpa nama',
          address: addressParts.join(', '),
          latitude: (lat as num).toDouble(),
          longitude: (lon as num).toDouble(),
        ),
      );
    }

    _sortPlacesByDistance(places, latitude, longitude);

    return places.take(20).toList();
  }

  // Mencari nama tempat atau alamat menggunakan Nominatim.
  Future<List<PlaceResult>> _searchByName(
    String query,
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': query,
        'format': 'jsonv2',
        'limit': '10',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'addressdetails': '1',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'DriveMate/1.0',
        'Accept-Language': 'id',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Layanan pencarian alamat tidak tersedia.');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    final places = <PlaceResult>[];

    for (final item in data) {
      final result = item as Map<String, dynamic>;

      places.add(
        PlaceResult(
          name: result['name']?.toString().trim().isNotEmpty == true
              ? result['name'].toString()
              : query,
          address: result['display_name']?.toString() ?? '',
          latitude: double.parse(result['lat'].toString()),
          longitude: double.parse(result['lon'].toString()),
        ),
      );
    }

    _sortPlacesByDistance(places, latitude, longitude);

    return places;
  }

  void _sortPlacesByDistance(
    List<PlaceResult> places,
    double latitude,
    double longitude,
  ) {
    final distance = Distance();

    places.sort((a, b) {
      final distanceA = distance.as(
        LengthUnit.Meter,
        LatLng(latitude, longitude),
        LatLng(a.latitude, a.longitude),
      );

      final distanceB = distance.as(
        LengthUnit.Meter,
        LatLng(latitude, longitude),
        LatLng(b.latitude, b.longitude),
      );

      return distanceA.compareTo(distanceB);
    });
  }

  // =========================================================
  // PILIH TUJUAN
  // =========================================================

  void _selectPlace(PlaceResult place) {
    final origin = _currentPosition != null
        ? LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          )
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

      // Perkiraan awal, bukan estimasi rute jalan sebenarnya.
      _durationMinutes = (distance / 30 * 60).ceil();
      if (_durationMinutes < 1) _durationMinutes = 1;

      _searchController.text = place.name;
      _searchResults = [];
    });

    if (_isMapReady) {
      _mapController.move(
        LatLng(place.latitude, place.longitude),
        16,
      );
    }
  }

  // =========================================================
  // GOOGLE MAPS
  // =========================================================

  Future<bool> _openGoogleMaps() async {
    final place = _selectedPlace;

    if (place == null) return false;

    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        if (_currentPosition != null)
          'origin':
              '${_currentPosition!.latitude},'
              '${_currentPosition!.longitude}',
        'destination': '${place.latitude},${place.longitude}',
        'destination_place_id': '',
        'travelmode': 'driving',
      }..remove('destination_place_id'),
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Maps tidak dapat dibuka.'),
          ),
        );
      }

      return opened;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka Google Maps: $e'),
          ),
        );
      }

      return false;
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
          content: Text(
            'Cari dan pilih tempat tujuan terlebih dahulu.',
          ),
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
          ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}, '
              'Lng: ${_currentPosition!.longitude.toStringAsFixed(5)}'
          : 'Lokasi GPS belum tersedia',
      notes: 'Perjalanan dipantau oleh sensor DriveMate',
    );

    try {
      await DatabaseHelper.instance.addTrip(trip);
      await _loadTrips();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Membuka navigasi ke ${place.name}.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _openGoogleMaps();
    } catch (e) {
      if (!mounted) return;

      setState(() => _isNavigating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan perjalanan: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  Future<void> _showWeather() async {
    if (_currentPosition == null) {
      await _fetchLocation();
    }

    if (!mounted) return;

    final position = _currentPosition;

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktifkan GPS untuk melihat cuaca lokasi kamu.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Memuat informasi cuaca...')),
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

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode != 200) {
        throw Exception('Layanan cuaca gagal (${response.statusCode}).');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>;

      final temperature = current['temperature_2m'];
      final feelsLike = current['apparent_temperature'];
      final humidity = current['relative_humidity_2m'];
      final wind = current['wind_speed_10m'];
      final rain = current['precipitation'];
      final code = (current['weather_code'] as num).toInt();

      String condition;
      IconData weatherIcon;

      if (code == 0) {
        condition = 'Cerah';
        weatherIcon = Icons.wb_sunny_rounded;
      } else if ([1, 2, 3].contains(code)) {
        condition = 'Cerah berawan / mendung';
        weatherIcon = Icons.cloud_rounded;
      } else if ([45, 48].contains(code)) {
        condition = 'Berkabut';
        weatherIcon = Icons.foggy;
      } else if ([51, 53, 55, 56, 57].contains(code)) {
        condition = 'Gerimis';
        weatherIcon = Icons.grain_rounded;
      } else if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) {
        condition = 'Hujan';
        weatherIcon = Icons.water_drop_rounded;
      } else if ([71, 73, 75, 77, 85, 86].contains(code)) {
        condition = 'Salju';
        weatherIcon = Icons.ac_unit_rounded;
      } else if ([95, 96, 99].contains(code)) {
        condition = 'Badai petir';
        weatherIcon = Icons.thunderstorm_rounded;
      } else {
        condition = 'Kondisi cuaca bervariasi';
        weatherIcon = Icons.cloud_outlined;
      }

      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cuaca Saat Ini'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(weatherIcon, size: 54, color: AppTheme.primary),
                const SizedBox(height: 8),
                Text(
                  '${(temperature as num).toStringAsFixed(1)} °C',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(condition),
                const Divider(height: 24),
                _weatherRow(
                  'Terasa seperti',
                  '${(feelsLike as num).toStringAsFixed(1)} °C',
                ),
                _weatherRow('Kelembapan', '$humidity%'),
                _weatherRow('Kecepatan angin', '$wind km/jam'),
                _weatherRow('Curah hujan', '$rain mm'),
                const SizedBox(height: 8),
                const Text(
                  'Data cuaca dari Open-Meteo. '
                  'Informasi berdasarkan koordinat GPS.',
                  style: TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  void _stopNavigation() {
    setState(() => _isNavigating = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Status navigasi DriveMate dihentikan. '
          'Jika Google Maps masih terbuka, tutup navigasinya di sana.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // TAMPILAN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header dan search bar.
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
                        tooltip: 'Sensor Kendaraan',
                        icon: Icon(
                          _showSensorPanel
                              ? Icons.sensors_rounded
                              : Icons.sensors_outlined,
                          color: AppTheme.primary,
                        ),
                        onPressed: () {
                          setState(() {
                            _showSensorPanel = !_showSensorPanel;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchPlaces(),
                    decoration: InputDecoration(
                      hintText: 'Cari lokasi, bengkel, SPBU...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Cari',
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                              ),
                              onPressed: () => _searchPlaces(),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Daftar hasil pencarian.
            if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 190),
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD6E2F0),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = _searchResults[index];

                    final km = Distance().as(
                      LengthUnit.Kilometer,
                      _mapCenter,
                      LatLng(place.latitude, place.longitude),
                    );

                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.primary,
                      ),
                      title: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${km.toStringAsFixed(1)} km'
                        '${place.address.isNotEmpty ? ' • ${place.address}' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => _selectPlace(place),
                    );
                  },
                ),
              ),

            if (_showSensorPanel) _buildSensorPanel(),

            // Peta OpenStreetMap.
            Expanded(
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEF5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFD6E2F0),
                      ),
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
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.drivemate',
                        ),

                        // Marker GPS pengguna.
                        if (_currentPosition != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _mapCenter,
                                width: 48,
                                height: 48,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.my_location_rounded,
                                    color: AppTheme.primary,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        // Marker tujuan yang dipilih.
                        if (_selectedPlace != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  _selectedPlace!.latitude,
                                  _selectedPlace!.longitude,
                                ),
                                width: 48,
                                height: 48,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.red,
                                  size: 42,
                                ),
                              ),
                            ],
                          ),

                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Data peta © OpenStreetMap contributors',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status GPS.
                  Positioned(
                    top: 60,
                    right: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.my_location_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _currentPosition != null
                                ? 'Lokasi GPS Aktif'
                                : 'Menunggu GPS',
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

                  // Refresh GPS.
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.gps_fixed_rounded,
                              size: 18,
                            ),
                    ),
                  ),

                  // Kartu tujuan.
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
                            color: AppTheme.navy.withValues(
                              alpha: 0.08,
                            ),
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
                                  color: AppTheme.cyan.withValues(
                                    alpha: 0.15,
                                  ),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tujuan: $_selectedDestination',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _selectedPlace == null
                                          ? 'Pilih tempat dari hasil pencarian'
                                          : '$_distanceKm km • '
                                              'perkiraan $_durationMinutes menit',
                                      maxLines: 2,
                                      style: const TextStyle(
                                        fontSize: 11,
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
                                backgroundColor: _isNavigating
                                    ? AppTheme.danger
                                    : AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _startNavigation,
                              child: Text(
                                _isNavigating
                                    ? 'Hentikan Status Navigasi'
                                    : 'Mulai Navigasi',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
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

            // Pintasan bawah.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _poiButton(
                      icon: Icons.car_repair_rounded,
                      label: 'Bengkel Terdekat',
                      onTap: () {
                        _searchController.text = 'bengkel terdekat';
                        _searchPlaces('bengkel terdekat');
                      },
                    ),
                  ),
                  Expanded(
                    child: _poiButton(
                      icon: Icons.local_gas_station_rounded,
                      label: 'SPBU Terdekat',
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
                      label: 'Info Lalu Lintas',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Informasi lalu lintas real-time '
                              'belum terhubung.',
                            ),
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

  // =========================================================
  // PANEL SENSOR
  // =========================================================

  Widget _buildSensorPanel() {
    return ValueListenableBuilder<SensorData>(
      valueListenable: _sensorService.sensorNotifier,
      builder: (context, data, _) {
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFD8E4F2),
            ),
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: data.isSupported
                          ? AppTheme.success.withValues(alpha: 0.12)
                          : AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data.isSupported
                          ? 'Hardware Aktif'
                          : 'Emulator Mode',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: data.isSupported
                            ? AppTheme.success
                            : AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _sensorStat(
                      label: 'Accelerometer',
                      value: '${data.gForce.toStringAsFixed(2)} G',
                      sub: 'X: ${data.accelX.toStringAsFixed(1)}  '
                          'Y: ${data.accelY.toStringAsFixed(1)}',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 45,
                    color: const Color(0xFFE2E9F3),
                  ),
                  Expanded(
                    child: _sensorStat(
                      label: 'Gyroscope',
                      value: '${data.gyroZ.toStringAsFixed(2)} rad/s',
                      sub: 'X: ${data.gyroX.toStringAsFixed(1)}  '
                          'Y: ${data.gyroY.toStringAsFixed(1)}',
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

  Widget _sensorStat({
    required String label,
    required String value,
    required String sub,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          Text(
            sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // TOMBOL PINTASAN
  // =========================================================

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
                border: Border.all(
                  color: const Color(0xFFE4EBF5),
                ),
              ),
              child: Icon(
                icon,
                color: AppTheme.primary,
                size: 22,
              ),
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
