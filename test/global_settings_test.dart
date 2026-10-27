import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivemate/localization/app_localizations.dart';
import 'package:drivemate/models/service_record.dart';
import 'package:drivemate/pages/home_page.dart';
import 'package:drivemate/pages/profile_page.dart';
import 'package:drivemate/pages/settings_page.dart';
import 'package:drivemate/services/currency_service.dart';
import 'package:drivemate/services/language_service.dart';
import 'package:drivemate/services/timezone_service.dart';
import 'package:drivemate/theme/app_theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LanguageService.instance.init();
    await CurrencyService.instance.init();
    await TimeZoneService.instance.init();
  });

  group('1. Pengaturan Bahasa Global Tests', () {
    test('LanguageService berganti antara Bahasa Indonesia dan English secara persisten', () async {
      final lang = LanguageService.instance;

      await lang.setLanguage('Bahasa Indonesia');
      expect(lang.isEnglish, isFalse);
      expect(lang.currentLocale.languageCode, 'id');

      await lang.setLanguage('English');
      expect(lang.isEnglish, isTrue);
      expect(lang.currentLocale.languageCode, 'en');

      // Verifikasi tersimpan di SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LanguageService.keyLanguage), 'English');

      // Pulihkan state ke default
      await lang.setLanguage('Bahasa Indonesia');
    });

    test('Preferensi bahasa dipulihkan saat LanguageService.init()', () async {
      SharedPreferences.setMockInitialValues({
        LanguageService.keyLanguage: 'English',
      });

      final lang = LanguageService.instance;
      await lang.init();

      expect(lang.isEnglish, isTrue);
      expect(lang.currentLocale.languageCode, 'en');

      // Reset
      await lang.setLanguage('Bahasa Indonesia');
    });

    testWidgets('Perubahan bahasa diterapkan langsung secara global di Profile dan Home', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final lang = LanguageService.instance;
      await lang.setLanguage('Bahasa Indonesia');

      Widget buildApp() {
        return ListenableBuilder(
          listenable: Listenable.merge([
            lang,
            CurrencyService.instance,
            TimeZoneService.instance,
          ]),
          builder: (context, _) {
            return MaterialApp(
              theme: AppTheme.lightTheme,
              locale: lang.currentLocale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const Scaffold(
                body: ProfilePage(),
              ),
            );
          },
        );
      }

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Memastikan bahasa Indonesia aktif di Profile
      expect(find.text('Profil'), findsWidgets);
      expect(find.text('Data Pengguna'), findsOneWidget);

      // Ubah bahasa ke English secara global
      await lang.setLanguage('English');
      await tester.pumpAndSettle();

      // Memastikan Profile berubah ke bahasa Inggris
      expect(find.text('Profile'), findsWidgets);
      expect(find.text('User Profile Data'), findsOneWidget);

      // Kembalikan ke default
      await lang.setLanguage('Bahasa Indonesia');
    });
  });

  group('2. Pengaturan Mata Uang Global Tests', () {
    test('CurrencyService mendukung IDR, USD, dan MYR secara persisten', () async {
      final currency = CurrencyService.instance;

      // Default IDR
      await currency.setCurrency('IDR');
      expect(currency.currentCurrencyCode, 'IDR');
      expect(currency.currentSymbol, 'Rp');

      // Ganti ke USD
      await currency.setCurrency('USD');
      expect(currency.currentCurrencyCode, 'USD');
      expect(currency.currentSymbol, r'$');

      // Ganti ke MYR
      await currency.setCurrency('MYR');
      expect(currency.currentCurrencyCode, 'MYR');
      expect(currency.currentSymbol, 'RM');

      // Verifikasi tersimpan di SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CurrencyService.keyCurrency), 'MYR');

      // Reset
      await currency.setCurrency('IDR');
    });

    test('Preferensi mata uang dipulihkan saat CurrencyService.init()', () async {
      SharedPreferences.setMockInitialValues({
        CurrencyService.keyCurrency: 'USD',
      });

      final currency = CurrencyService.instance;
      await currency.init();

      expect(currency.currentCurrencyCode, 'USD');
      expect(currency.currentSymbol, r'$');

      // Reset
      await currency.setCurrency('IDR');
    });

    test('Format nominal mata uang melakukan konversi kurs yang valid', () async {
      final currency = CurrencyService.instance;
      const idrAmount = 1542000; // setara 100 USD

      // Dalam IDR
      await currency.setCurrency('IDR');
      expect(currency.format(idrAmount), 'Rp 1.542.000');

      // Dalam USD: 1542000 / 15420 = 100.00
      await currency.setCurrency('USD');
      expect(currency.format(idrAmount), r'$ 100.00');

      // Dalam MYR: 1542000 / 15420 * 4.72 = 472.00
      await currency.setCurrency('MYR');
      expect(currency.format(idrAmount), 'RM 472.00');

      // Reset
      await currency.setCurrency('IDR');
    });

    test('Perubahan preferensi mata uang TIDAK mengubah nominal asli pada model atau database', () {
      final rec = ServiceRecord(
        id: 1,
        vehicleId: 10,
        title: 'Ganti Oli Mesin',
        serviceType: 'Servis Berkala',
        date: '2026-10-25',
        mileage: 15000,
        workshop: 'Bengkel Resmi',
        cost: 350000,
        notes: 'Oli 0W-20',
        status: 'Selesai',
        prevHash: 'genesis',
        timestamp: '2026-10-25T10:00:00Z',
      );

      // Verifikasi hash awal
      expect(rec.cost, 350000);
      expect(rec.verifyHash(), isTrue);

      // Format ke USD
      CurrencyService.instance.setCurrency('USD');
      final formattedUsd = CurrencyService.instance.format(rec.cost);
      expect(formattedUsd, contains(r'$'));

      // Nilai integer asli rec.cost tetap 350000 IDR dan blockchain integrity tidak rusak
      expect(rec.cost, 350000);
      expect(rec.verifyHash(), isTrue);

      // Reset
      CurrencyService.instance.setCurrency('IDR');
    });
  });

  group('3. Pengaturan Zona Waktu Global Tests', () {
    test('TimeZoneService mendukung zona waktu valid WIB, WITA, WIT, UTC secara persisten', () async {
      final tzService = TimeZoneService.instance;

      await tzService.setTimeZone('Asia/Jakarta');
      expect(tzService.currentAbbreviation, 'WIB');

      await tzService.setTimeZone('Asia/Makassar');
      expect(tzService.currentAbbreviation, 'WITA');

      await tzService.setTimeZone('Asia/Jayapura');
      expect(tzService.currentAbbreviation, 'WIT');

      await tzService.setTimeZone('UTC');
      expect(tzService.currentAbbreviation, 'UTC');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(TimeZoneService.keyTimeZone), 'UTC');

      // Reset
      await tzService.setTimeZone('Asia/Jakarta');
    });

    test('Preferensi zona waktu dipulihkan saat TimeZoneService.init()', () async {
      SharedPreferences.setMockInitialValues({
        TimeZoneService.keyTimeZone: 'Asia/Makassar',
      });

      final tzService = TimeZoneService.instance;
      await tzService.init();

      expect(tzService.currentTimeZoneId, 'Asia/Makassar');
      expect(tzService.currentAbbreviation, 'WITA');

      // Reset
      await tzService.setTimeZone('Asia/Jakarta');
    });

    test('Format tampilan waktu mengikuti preferensi zona waktu tanpa mengubah timestamp asli', () {
      final tzService = TimeZoneService.instance;

      // Timestamp UTC: 2026-10-27 12:00:00 UTC
      final utcTime = DateTime.utc(2026, 10, 27, 12, 0, 0);

      // WIB (UTC+7): 12 + 7 = 19:00 WIB
      tzService.setTimeZone('Asia/Jakarta');
      final wibText = tzService.formatDateTime(utcTime);
      expect(wibText, contains('19:00 WIB'));

      // WITA (UTC+8): 12 + 8 = 20:00 WITA
      tzService.setTimeZone('Asia/Makassar');
      final witaText = tzService.formatDateTime(utcTime);
      expect(witaText, contains('20:00 WITA'));

      // WIT (UTC+9): 12 + 9 = 21:00 WIT
      tzService.setTimeZone('Asia/Jayapura');
      final witText = tzService.formatDateTime(utcTime);
      expect(witText, contains('21:00 WIT'));

      // Timestamp asli tetap tidak bermutasi
      expect(utcTime.hour, 12);
      expect(utcTime.isUtc, isTrue);

      // Reset
      tzService.setTimeZone('Asia/Jakarta');
    });
  });

  group('4. Navigasi & Menu Lainnya (...) Tests', () {
    testWidgets('Menu ... pada Home tidak menampilkan pintasan kalkulator yang dihapus', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id', 'ID'),
          home: const Scaffold(
            body: HomePage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Temukan tombol ... (Lainnya) pada Home
      final moreButton = find.byIcon(Icons.more_horiz_rounded);
      expect(moreButton, findsOneWidget);

      // Tekan tombol ... untuk membuka menu fitur lainnya
      await tester.tap(moreButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Memastikan kalkulator konversi mata uang & waktu TIDAK ADA
      expect(find.text('Konversi Mata Uang'), findsNothing);
      expect(find.text('Konversi Waktu'), findsNothing);
      expect(find.text('Kalkulator Konversi'), findsNothing);

      // Memastikan menu menyajikan akses ke Pengaturan, Riwayat Aktivitas, dsb.
      expect(find.text('Fitur Lainnya'), findsOneWidget);
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('Riwayat Aktivitas'), findsOneWidget);
    });

    testWidgets('Settings page menampilkan preferensi Bahasa, Mata Uang, dan Zona Waktu', (tester) async {
      tester.view.physicalSize = const Size(400, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id', 'ID'),
          home: const SettingsPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan ketiga pengaturan ada di halaman Settings
      expect(find.text('Bahasa'), findsOneWidget);
      expect(find.text('Mata Uang'), findsOneWidget);
      expect(find.text('Zona Waktu'), findsOneWidget);

      // Verifikasi ada 4 dropdown (Bahasa, Mata Uang, Zona Waktu, Satuan Jarak)
      final dropdowns = find.byType(DropdownButton<String>);
      expect(dropdowns, findsNWidgets(4));
    });
  });
}
