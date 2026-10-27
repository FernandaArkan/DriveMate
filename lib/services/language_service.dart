import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  LanguageService._internal();

  static final LanguageService instance = LanguageService._internal();

  static const String keyLanguage = 'setting_language';

  Locale _currentLocale = const Locale('id', 'ID');
  bool _isInitialized = false;

  Locale get currentLocale => _currentLocale;
  bool get isInitialized => _isInitialized;
  bool get isEnglish => _currentLocale.languageCode == 'en';
  String get languageName => isEnglish ? 'English' : 'Bahasa Indonesia';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(keyLanguage);

      if (savedLang == 'English' || savedLang == 'en') {
        _currentLocale = const Locale('en', 'US');
        Intl.defaultLocale = 'en_US';
      } else {
        _currentLocale = const Locale('id', 'ID');
        Intl.defaultLocale = 'id_ID';
      }
    } catch (e) {
      debugPrint('Error initializing LanguageService: $e');
      _currentLocale = const Locale('id', 'ID');
      Intl.defaultLocale = 'id_ID';
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String languageNameOrCode) async {
    final bool wantEnglish = languageNameOrCode == 'English' ||
        languageNameOrCode.toLowerCase() == 'en' ||
        languageNameOrCode == 'en_US';

    final newLocale = wantEnglish
        ? const Locale('en', 'US')
        : const Locale('id', 'ID');
    final storedValue = wantEnglish ? 'English' : 'Bahasa Indonesia';

    if (_currentLocale.languageCode == newLocale.languageCode) {
      return;
    }

    _currentLocale = newLocale;
    Intl.defaultLocale = wantEnglish ? 'en_US' : 'id_ID';

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyLanguage, storedValue);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }

    notifyListeners();
  }
}
