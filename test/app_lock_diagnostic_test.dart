
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivemate/database/platform_init.dart';
import 'package:drivemate/localization/app_localizations.dart';
import 'package:drivemate/services/currency_service.dart';
import 'package:drivemate/services/language_service.dart';
import 'package:drivemate/services/security_service.dart';
import 'package:drivemate/services/timezone_service.dart';

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

  testWidgets('Diagnostik pumpWidget dan lokalisasi', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    debugPrint('[DIAG TEST] Sebelum pumpWidget');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
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
        home: const Scaffold(
          body: Center(
            child: Text('Hello'),
          ),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);

    debugPrint('[DIAG TEST] Sesudah pumpWidget');
  });
}
