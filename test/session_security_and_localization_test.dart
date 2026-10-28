
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivemate/database/platform_init.dart';
import 'package:drivemate/localization/app_localizations.dart';
import 'package:drivemate/repositories/user_repository.dart';
import 'package:drivemate/services/currency_service.dart';
import 'package:drivemate/services/language_service.dart';
import 'package:drivemate/services/security_service.dart';
import 'package:drivemate/services/timezone_service.dart';
import 'package:drivemate/widgets/app_lock_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    initPlatformDatabase();

    const channels = [
      MethodChannel('plugins.flutter.io/local_auth'),
      MethodChannel('plugins.flutter.io/local_auth_android'),
      MethodChannel('plugins.flutter.io/local_auth_ios'),
      MethodChannel('plugins.flutter.io/local_auth_windows'),
    ];

    for (final channel in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'authenticate':
          case 'isDeviceSupported':
          case 'canCheckBiometrics':
          case 'stopAuthentication':
            return true;
          case 'getAvailableBiometrics':
            return <String>['fingerprint', 'face'];
          default:
            return true;
        }
      });
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    await LanguageService.instance.init();
    await CurrencyService.instance.init();
    await TimeZoneService.instance.init();
    await SecurityService.instance.init();
  });

  group('Pengaturan global', () {
    test('Bahasa dapat diganti dan disimpan', () async {
      final language = LanguageService.instance;

      await language.setLanguage('English');
      expect(language.isEnglish, isTrue);

      final prefs = await SharedPreferences.getInstance();

      expect(
        prefs.getString(LanguageService.keyLanguage),
        'English',
      );
    });

    test('Mata uang dapat diinisialisasi', () {
      expect(CurrencyService.instance, isNotNull);
    });

    test('Zona waktu dapat diinisialisasi', () {
      expect(TimeZoneService.instance, isNotNull);
    });
  });

  group('Keamanan PIN', () {
    test('PIN enam digit dapat diatur dan diverifikasi', () async {
      final security = SecurityService.instance;

      final saved = await security.setPin('123456');
      expect(saved, isTrue);

      final result = await security.verifyPin('123456');
      expect(result.isSuccess, isTrue);
    });

    test('PIN yang salah tidak lolos verifikasi', () async {
      final security = SecurityService.instance;

      final saved = await security.setPin('123456');
      expect(saved, isTrue);

      final result = await security.verifyPin('654321');
      expect(result.isSuccess, isFalse);
    });
  });

  group('AppLockOverlay', () {
    testWidgets(
      'AppLockOverlay menampilkan layar kunci dan membuka dengan PIN',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        debugPrint('[LOCK TEST] Mulai');

        final security = SecurityService.instance;
        final userRepo = UserRepository.instance;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_email', 'andi@email.com');
        await prefs.setBool(
          SecurityService.keyBiometricEnabled,
          false,
        );

        debugPrint('[LOCK TEST] Sebelum initSession');

        await tester.runAsync(() async {
          await userRepo.initSession().timeout(
                const Duration(seconds: 10),
              );
        });

        debugPrint('[LOCK TEST] Sesudah initSession');

        await tester.runAsync(() async {
          await userRepo.toggleBiometric(false).timeout(
                const Duration(seconds: 5),
              );
          await security.init().timeout(
                const Duration(seconds: 5),
              );
        });

        debugPrint('[LOCK TEST] Sesudah security.init');

        final pinSet = await tester.runAsync(
          () => security.setPin('123456').timeout(
                const Duration(seconds: 10),
              ),
        );

        debugPrint('[LOCK TEST] Sesudah setPin: $pinSet');
        expect(pinSet, isTrue);

        security.lockApp();
        expect(security.isLocked, isTrue);

        debugPrint('[LOCK TEST] Sebelum pumpWidget');

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('id', 'ID'),
            theme: ThemeData(
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
            ),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AppLockOverlay(
              child: Scaffold(
                body: Center(
                  child: Text('Konten Terlindungi'),
                ),
              ),
            ),
          ),
        );

        debugPrint('[LOCK TEST] Sesudah pumpWidget');

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        debugPrint('[LOCK TEST] Widget selesai ditampilkan');

        expect(find.text('Aplikasi Terkunci'), findsOneWidget);
        expect(find.text('Konten Terlindungi'), findsNothing);

        for (final digit in ['1', '2', '3', '4', '5', '6']) {
          final button = find.widgetWithText(InkWell, digit);

          expect(
            button,
            findsOneWidget,
            reason: 'Tombol PIN $digit harus ditemukan',
          );

          await tester.tap(button);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          debugPrint('[LOCK TEST] Digit $digit ditekan');
        }

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        debugPrint(
          '[LOCK TEST] Status terkunci setelah PIN: '
          '${security.isLocked}',
        );

        expect(security.isLocked, isFalse);
        expect(find.text('Konten Terlindungi'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();

        await security.disablePin('123456');
        await userRepo.logout();

        debugPrint('[LOCK TEST] Selesai');
      },
    );
  });
}
