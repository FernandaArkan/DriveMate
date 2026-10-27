
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivemate/localization/app_localizations.dart';
import 'package:drivemate/models/feedback_item.dart';
import 'package:drivemate/pages/feedback_page.dart';
import 'package:drivemate/pages/profile_page.dart';
import 'package:drivemate/pages/settings_page.dart';
import 'package:drivemate/services/feedback_service.dart';
import 'package:drivemate/services/language_service.dart';
import 'package:drivemate/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Feedback Model & Service Tests', () {
    test('FeedbackItem serialization and deserialization', () {
      final now = DateTime(2026, 10, 27, 19, 0, 0);

      final item = FeedbackItem(
        id: 'test_123',
        kesan: 'Aplikasi sangat responsif',
        pesan: 'Tolong tambahkan peta SPBU',
        rating: 5,
        createdAt: now,
        userName: 'Budi Santoso',
      );

      final map = item.toMap();

      expect(map['id'], 'test_123');
      expect(map['kesan'], 'Aplikasi sangat responsif');
      expect(map['pesan'], 'Tolong tambahkan peta SPBU');
      expect(map['rating'], 5);
      expect(map['userName'], 'Budi Santoso');

      final fromMap = FeedbackItem.fromMap(map);

      expect(fromMap.id, item.id);
      expect(fromMap.kesan, item.kesan);
      expect(fromMap.pesan, item.pesan);
      expect(fromMap.rating, item.rating);
      expect(fromMap.userName, item.userName);

      final jsonStr = item.toJson();
      final fromJson = FeedbackItem.fromJson(jsonStr);

      expect(fromJson.id, item.id);
      expect(fromJson.kesan, item.kesan);
    });

    test('FeedbackService saves and loads feedback locally', () async {
      final service = FeedbackService.instance;

      await service.clearAll();

      expect(service.feedbacks, isEmpty);

      final saved = await service.saveFeedback(
        kesan: 'Fitur reminder servis sangat berguna.',
        pesan: 'Perbanyak pilihan jenis servis berkala.',
        rating: 5,
        userName: 'Tester Driver',
      );

      expect(saved, isTrue);
      expect(service.feedbacks.length, 1);
      expect(
        service.feedbacks.first.kesan,
        'Fitur reminder servis sangat berguna.',
      );
      expect(service.feedbacks.first.userName, 'Tester Driver');

      await service.loadFeedbacks();

      expect(service.feedbacks.length, 1);

      final deleted = await service.deleteFeedback(
        service.feedbacks.first.id,
      );

      expect(deleted, isTrue);
      expect(service.feedbacks, isEmpty);
    });
  });

  group('Language Service & Localization Tests', () {
    test(
      'LanguageService switches between Indonesian and English and persists',
      () async {
        final langService = LanguageService.instance;

        await langService.init();

        expect(langService.currentLocale.languageCode, 'id');
        expect(langService.isEnglish, isFalse);

        await langService.setLanguage('English');

        expect(langService.currentLocale.languageCode, 'en');
        expect(langService.isEnglish, isTrue);
        expect(langService.languageName, 'English');

        final prefs = await SharedPreferences.getInstance();

        expect(
          prefs.getString(LanguageService.keyLanguage),
          'English',
        );

        await langService.setLanguage('Bahasa Indonesia');

        expect(langService.currentLocale.languageCode, 'id');
        expect(langService.isEnglish, isFalse);
        expect(
          prefs.getString(LanguageService.keyLanguage),
          'Bahasa Indonesia',
        );
      },
    );

    test(
      'AppLocalizations returns correct strings for Indonesian and English',
      () {
        final idL10n = AppLocalizations(const Locale('id', 'ID'));
        final enL10n = AppLocalizations(const Locale('en', 'US'));

        expect(idL10n.appName, 'DriveMate');
        expect(enL10n.appName, 'DriveMate');

        expect(idL10n.navVehicles, 'Kendaraan');
        expect(enL10n.navVehicles, 'Vehicles');

        expect(idL10n.profileTitle, 'Profil');
        expect(enL10n.profileTitle, 'Profile');
        expect(idL10n.menuFeedback, 'Kesan & Pesan');
        expect(enL10n.menuFeedback, 'Feedback & Suggestions');

        expect(idL10n.settingsTitle, 'Pengaturan');
        expect(enL10n.settingsTitle, 'Settings');
        expect(idL10n.language, 'Bahasa');
        expect(enL10n.language, 'Language');

        expect(idL10n.feedbackSubmitBtn, 'Simpan Kesan & Pesan');
        expect(enL10n.feedbackSubmitBtn, 'Save Feedback');
        expect(idL10n.feedbackKesanError, 'Kesan tidak boleh kosong');
        expect(
          enL10n.feedbackKesanError,
          'Please enter your impressions (cannot be empty)',
        );
      },
    );
  });

  group('FeedbackPage Widget Tests', () {
    testWidgets(
      'Renders FeedbackPage cleanly without overflow on small screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await FeedbackService.instance.clearAll();

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
            home: const FeedbackPage(),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Kesan & Pesan'), findsOneWidget);
        expect(find.text('Kesan Penggunaan'), findsOneWidget);
        expect(find.text('Pesan, Saran & Masukan'), findsOneWidget);
        expect(find.text('Simpan Kesan & Pesan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Feedback form validation rejects empty inputs and submits valid data',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await FeedbackService.instance.clearAll();

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
            home: const FeedbackPage(),
          ),
        );

        await tester.pumpAndSettle();

        final submitButton = find.byType(FilledButton);

        expect(submitButton, findsOneWidget);

        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.text('Kesan tidak boleh kosong'), findsOneWidget);

        final textFields = find.byType(TextFormField);

        expect(textFields, findsNWidgets(2));

        await tester.enterText(
          textFields.at(0),
          'Aplikasi sangat bagus dan responsif',
        );

        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Pesan & saran tidak boleh kosong'),
          findsOneWidget,
        );

        await tester.enterText(
          textFields.at(1),
          'Mohon ditambahkan fitur estimasi biaya bensin',
        );

        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text(
            'Kesan dan pesan Anda berhasil disimpan di perangkat.',
          ),
          findsOneWidget,
        );

        // The form clears its fields after saving, so locate the
        // saved feedback in the history using a unique text finder.
        final kesanHistory = find.text(
          'Aplikasi sangat bagus dan responsif',
          skipOffstage: false,
        );
        final pesanHistory = find.text(
          'Mohon ditambahkan fitur estimasi biaya bensin',
          skipOffstage: false,
        );

        expect(kesanHistory, findsWidgets);
        expect(pesanHistory, findsWidgets);

        // Confirm the saved data is present in the service as well.
        final savedFeedbacks = FeedbackService.instance.feedbacks;

        expect(
          savedFeedbacks.any(
            (item) => item.kesan == 'Aplikasi sangat bagus dan responsif',
          ),
          isTrue,
        );
        expect(
          savedFeedbacks.any(
            (item) =>
                item.pesan == 'Mohon ditambahkan fitur estimasi biaya bensin',
          ),
          isTrue,
        );
      },
    );
  });

  group('Profile & Settings Page Integration Tests', () {
    testWidgets(
      'Profile page shows Kesan & Pesan menu item and navigates to FeedbackPage',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
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
            home: const ProfilePage(),
          ),
        );

        await tester.pumpAndSettle();

        final feedbackMenu = find.text('Kesan & Pesan');

        await tester.scrollUntilVisible(feedbackMenu, 100);

        expect(feedbackMenu, findsOneWidget);

        await tester.tap(feedbackMenu);
        await tester.pumpAndSettle();

        expect(find.byType(FeedbackPage), findsOneWidget);
      },
    );

    testWidgets(
      'Settings page allows switching language dynamically',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await LanguageService.instance.init();

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

        expect(find.text('Pengaturan'), findsOneWidget);
        expect(find.text('Bahasa'), findsOneWidget);

        final dropdown = find.byType(DropdownButton<String>).first;

        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        final englishItem = find.text('English').last;

        await tester.tap(englishItem);
        await tester.pumpAndSettle();

        expect(LanguageService.instance.isEnglish, isTrue);
      },
    );
  });
}
