import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'language_service.dart';

class TimeZoneOption {
  final String id; // IANA Timezone identifier
  final String name; // Nama zona waktu
  final String abbreviation; // WIB, WITA, WIT, dsb.
  final int offsetHours; // Selisih UTC

  const TimeZoneOption({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.offsetHours,
  });

  String get label =>
      '$abbreviation - $name (GMT${offsetHours >= 0 ? "+$offsetHours" : "$offsetHours"})';
}

class TimeZoneService extends ChangeNotifier {
  TimeZoneService._internal();

  static final TimeZoneService instance = TimeZoneService._internal();

  static const String keyTimeZone = 'setting_timezone';

  static const Map<String, TimeZoneOption> supportedTimeZones = {
    'Asia/Jakarta': TimeZoneOption(
      id: 'Asia/Jakarta',
      name: 'Waktu Indonesia Barat (Jakarta)',
      abbreviation: 'WIB',
      offsetHours: 7,
    ),
    'Asia/Makassar': TimeZoneOption(
      id: 'Asia/Makassar',
      name: 'Waktu Indonesia Tengah (Makassar)',
      abbreviation: 'WITA',
      offsetHours: 8,
    ),
    'Asia/Jayapura': TimeZoneOption(
      id: 'Asia/Jayapura',
      name: 'Waktu Indonesia Timur (Jayapura)',
      abbreviation: 'WIT',
      offsetHours: 9,
    ),
    'UTC': TimeZoneOption(
      id: 'UTC',
      name: 'Coordinated Universal Time',
      abbreviation: 'UTC',
      offsetHours: 0,
    ),
    'Asia/Singapore': TimeZoneOption(
      id: 'Asia/Singapore',
      name: 'Singapura & Malaysia',
      abbreviation: 'SGT',
      offsetHours: 8,
    ),
    'Asia/Tokyo': TimeZoneOption(
      id: 'Asia/Tokyo',
      name: 'Jepang (Tokyo)',
      abbreviation: 'JST',
      offsetHours: 9,
    ),
    'America/New_York': TimeZoneOption(
      id: 'America/New_York',
      name: 'Amerika Serikat (New York)',
      abbreviation: 'EST',
      offsetHours: -5,
    ),
  };

  String _currentTimeZoneId = 'Asia/Jakarta';
  bool _isInitialized = false;

  String get currentTimeZoneId => _currentTimeZoneId;
  bool get isInitialized => _isInitialized;

  TimeZoneOption get currentTimeZone =>
      supportedTimeZones[_currentTimeZoneId] ??
      supportedTimeZones['Asia/Jakarta']!;

  String get currentAbbreviation => currentTimeZone.abbreviation;
  String get currentLabel => currentTimeZone.label;

  tz.Location get _tzLocation {
    try {
      if (tz.timeZoneDatabase.locations.isEmpty) {
        tz.initializeTimeZones();
      }
      return tz.getLocation(_currentTimeZoneId);
    } catch (_) {
      try {
        tz.initializeTimeZones();
        return tz.getLocation('Asia/Jakarta');
      } catch (_) {
        return tz.getLocation('UTC');
      }
    }
  }

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      final prefs = await SharedPreferences.getInstance();
      final savedTz = prefs.getString(keyTimeZone);

      if (savedTz != null && supportedTimeZones.containsKey(savedTz)) {
        _currentTimeZoneId = savedTz;
      } else {
        _currentTimeZoneId = 'Asia/Jakarta';
      }
    } catch (e) {
      debugPrint('Error initializing TimeZoneService: $e');
      _currentTimeZoneId = 'Asia/Jakarta';
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setTimeZone(String timeZoneId) async {
    if (!supportedTimeZones.containsKey(timeZoneId)) {
      debugPrint('Zona waktu $timeZoneId tidak didukung.');
      return;
    }

    if (_currentTimeZoneId == timeZoneId) {
      return;
    }

    _currentTimeZoneId = timeZoneId;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyTimeZone, timeZoneId);
    } catch (e) {
      debugPrint('Error saving timezone preference: $e');
    }

    notifyListeners();
  }

  /// Mengonversi DateTime ke TZDateTime zona waktu aktif
  tz.TZDateTime toTargetZone(DateTime dt) {
    try {
      final loc = _tzLocation;
      if (dt.isUtc) {
        return tz.TZDateTime.from(dt, loc);
      } else {
        // Konversi waktu lokal ke UTC terlebih dahulu agar pergeseran zona waktu akurat
        return tz.TZDateTime.from(dt.toUtc(), loc);
      }
    } catch (_) {
      try {
        tz.initializeTimeZones();
        final loc = tz.getLocation('Asia/Jakarta');
        return tz.TZDateTime.from(dt.toUtc(), loc);
      } catch (_) {
        return tz.TZDateTime.utc(
          dt.year,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
        );
      }
    }
  }

  /// Mendapatkan singkatan zona waktu yang dinamis (memperhitungkan Daylight Saving Time jika berlaku)
  String getDynamicAbbreviation(tz.TZDateTime inZone) {
    final tzName = inZone.timeZoneName;
    // Jika tzName berupa nama resmi (bukan offset +07 / +08) gunakan tzName
    if (tzName.isNotEmpty &&
        !tzName.startsWith('+') &&
        !tzName.startsWith('-')) {
      return tzName;
    }
    return currentTimeZone.abbreviation;
  }

  /// Memformat DateTime untuk tampilan antarmuka sesuai zona waktu yang dipilih
  String formatDateTime(
    DateTime dt, {
    String pattern = 'dd MMM yyyy, HH:mm',
    String? locale,
    bool includeAbbreviation = true,
  }) {
    final effectiveLocale = locale ??
        (LanguageService.instance.isEnglish ? 'en_US' : 'id_ID');

    final inZone = toTargetZone(dt);
    final abbreviation = getDynamicAbbreviation(inZone);

    DateFormat formatter;
    try {
      formatter = DateFormat(pattern, effectiveLocale);
    } catch (_) {
      try {
        formatter = DateFormat(pattern);
      } catch (_) {
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $abbreviation';
      }
    }

    final formatted = formatter.format(inZone);

    if (includeAbbreviation) {
      return '$formatted $abbreviation';
    }
    return formatted;
  }

  /// Membantu parsing string tanggal fleksibel dari database / input form
  DateTime? parseFlexible(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Bersihkan akhiran zona waktu seperti ' WIB', ' WITA', ' WIT', ' UTC', ' JST', ' EST', ' EDT'
    final cleanInput = trimmed.replaceAll(
      RegExp(r'\s+(WIB|WITA|WIT|UTC|JST|SGT|EST|EDT)$', caseSensitive: false),
      '',
    );

    final parsedIso = DateTime.tryParse(cleanInput);
    if (parsedIso != null) return parsedIso;

    final formats = [
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd HH:mm:ss',
      'dd MMM yyyy, HH:mm',
      'dd MMMM yyyy, HH:mm',
      'dd MMM yyyy',
      'dd MMMM yyyy',
      'yyyy-MM-dd',
    ];

    for (final pattern in formats) {
      for (final loc in ['id_ID', 'en_US']) {
        try {
          return DateFormat(pattern, loc).parse(cleanInput);
        } catch (_) {}
      }
      try {
        return DateFormat(pattern).parse(cleanInput);
      } catch (_) {}
    }

    return null;
  }

  /// Memformat string tanggal tersimpan ke tampilan zona waktu aktif
  String formatFlexibleString(
    String dateStr, {
    String pattern = 'dd MMM yyyy, HH:mm',
    bool includeAbbreviation = true,
  }) {
    final parsed = parseFlexible(dateStr);
    if (parsed == null) return dateStr;
    return formatDateTime(
      parsed,
      pattern: pattern,
      includeAbbreviation: includeAbbreviation,
    );
  }
}
