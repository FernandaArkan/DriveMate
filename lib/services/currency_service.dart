import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyOption {
  final String code;
  final String name;
  final String symbol;
  final double ratePerUSD; // Kurs per 1 USD
  final int decimalDigits;
  final String locale;

  const CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
    required this.ratePerUSD,
    required this.decimalDigits,
    this.locale = 'en_US',
  });

  /// Rasio konversi dari 1 IDR ke mata uang ini
  double get rateFromIDR => ratePerUSD / 15420.0;

  String get label => '$code ($symbol) - $name';
}

class CurrencyService extends ChangeNotifier {
  CurrencyService._internal();

  static final CurrencyService instance = CurrencyService._internal();

  static const String keyCurrency = 'setting_currency';

  // Daftar mata uang yang didukung (minimal IDR, USD, MYR)
  static const Map<String, CurrencyOption> supportedCurrencies = {
    'IDR': CurrencyOption(
      code: 'IDR',
      name: 'Rupiah Indonesia',
      symbol: 'Rp',
      ratePerUSD: 15420.0,
      decimalDigits: 0,
      locale: 'id_ID',
    ),
    'USD': CurrencyOption(
      code: 'USD',
      name: 'US Dollar',
      symbol: r'$',
      ratePerUSD: 1.0,
      decimalDigits: 2,
      locale: 'en_US',
    ),
    'MYR': CurrencyOption(
      code: 'MYR',
      name: 'Ringgit Malaysia',
      symbol: 'RM',
      ratePerUSD: 4.72,
      decimalDigits: 2,
      locale: 'en_US',
    ),
    'EUR': CurrencyOption(
      code: 'EUR',
      name: 'Euro',
      symbol: '€',
      ratePerUSD: 0.92,
      decimalDigits: 2,
      locale: 'en_US',
    ),
    'SGD': CurrencyOption(
      code: 'SGD',
      name: 'Singapore Dollar',
      symbol: r'S$',
      ratePerUSD: 1.34,
      decimalDigits: 2,
      locale: 'en_US',
    ),
    'JPY': CurrencyOption(
      code: 'JPY',
      name: 'Japanese Yen',
      symbol: '¥',
      ratePerUSD: 151.5,
      decimalDigits: 0,
      locale: 'ja_JP',
    ),
  };

  String _currentCurrencyCode = 'IDR';
  bool _isInitialized = false;

  String get currentCurrencyCode => _currentCurrencyCode;
  bool get isInitialized => _isInitialized;

  CurrencyOption get currentCurrency =>
      supportedCurrencies[_currentCurrencyCode] ?? supportedCurrencies['IDR']!;

  String get currentSymbol => currentCurrency.symbol;

  String get rateSourceDescription =>
      'Kurs Acuan Resmi: 1 USD = Rp 15.420 • 1 MYR = Rp 3.267';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCurrency = prefs.getString(keyCurrency);

      if (savedCurrency != null &&
          supportedCurrencies.containsKey(savedCurrency.toUpperCase())) {
        _currentCurrencyCode = savedCurrency.toUpperCase();
      } else {
        _currentCurrencyCode = 'IDR';
      }
    } catch (e) {
      debugPrint('Error initializing CurrencyService: $e');
      _currentCurrencyCode = 'IDR';
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setCurrency(String currencyCode) async {
    final code = currencyCode.toUpperCase();
    if (!supportedCurrencies.containsKey(code)) {
      debugPrint('Mata uang $currencyCode tidak didukung.');
      return;
    }

    if (_currentCurrencyCode == code) {
      return;
    }

    _currentCurrencyCode = code;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyCurrency, code);
    } catch (e) {
      debugPrint('Error saving currency preference: $e');
    }

    notifyListeners();
  }

  /// Mengonversi nilai nominal dari basis database IDR ke mata uang aktif
  double convertFromIDR(num amountInIDR) {
    if (_currentCurrencyCode == 'IDR') return amountInIDR.toDouble();
    final option = currentCurrency;
    return amountInIDR * option.rateFromIDR;
  }

  /// Mengonversi nilai nominal mata uang yang dipilih kembali ke IDR (untuk penyimpanan murni)
  int convertToIDR(num amountInSelectedCurrency) {
    if (_currentCurrencyCode == 'IDR') return amountInSelectedCurrency.round();
    final option = currentCurrency;
    if (option.rateFromIDR == 0) return 0;
    return (amountInSelectedCurrency / option.rateFromIDR).round();
  }

  /// Memformat nilai nominal integer IDR database ke teks mata uang aktif
  String format(num amountInIDR) {
    final option = currentCurrency;
    final converted = convertFromIDR(amountInIDR);

    if (option.code == 'IDR') {
      final formattedNum = converted.round().toString().replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (_) => '.',
          );
      return 'Rp $formattedNum';
    }

    // Untuk mata uang asing (USD, MYR, EUR, dsb.)
    final formatter = NumberFormat.currency(
      locale: option.locale,
      symbol: option.symbol.endsWith(' ') ? option.symbol : '${option.symbol} ',
      decimalDigits: option.decimalDigits,
    );
    return formatter.format(converted).trim();
  }
}
