import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'database/platform_init.dart';
import 'localization/app_localizations.dart';
import 'pages/ai_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/notifications_page.dart';
import 'pages/profile_page.dart';
import 'pages/splash_page.dart';
import 'pages/trips_page.dart';
import 'pages/vehicles_page.dart';
import 'services/currency_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/timezone_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await initializeDateFormatting('en_US', null);
  await LanguageService.instance.init();
  await CurrencyService.instance.init();
  await TimeZoneService.instance.init();
  initPlatformDatabase();
  await NotificationService.instance.init();
  NotificationService.instance.onNotificationClick = (payload) {
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  };
  unawaited(NotificationService.instance.restoreScheduledReminders());
  runApp(const DriveMateApp());
}

class DriveMateApp extends StatelessWidget {
  const DriveMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LanguageService.instance,
        CurrencyService.instance,
        TimeZoneService.instance,
      ]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          title: 'DriveMate',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: LanguageService.instance.currentLocale,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashPage(),
            '/login': (context) => const LoginPage(),
            '/home': (context) => const MainNavigation(),
          },
          builder: (context, child) {
            return ColoredBox(
              color: const Color(0xFFE5EAF2),
              child: Center(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 430),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int selectedIndex = 0;

  static const List<IconData> icons = [
    Icons.home_outlined,
    Icons.directions_car_outlined,
    Icons.map_outlined,
    Icons.smart_toy_outlined,
    Icons.person_outline_rounded,
  ];

  void _onTabChanged(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.navHome,
      l10n.navVehicles,
      l10n.navTrips,
      l10n.navAi,
      l10n.navProfile,
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomePage(onNavigateTab: _onTabChanged),
          const VehiclesPage(),
          const TripsPage(),
          const AiPage(),
          ProfilePage(onNavigateTab: _onTabChanged),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: AppTheme.navy.withValues(alpha: 0.07),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            backgroundColor: Colors.white,
            indicatorColor: AppTheme.primary.withValues(alpha: 0.12),
            height: 70,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: _onTabChanged,
            destinations: List.generate(
              labels.length,
              (index) => NavigationDestination(
                icon: Icon(icons[index]),
                selectedIcon: Icon(
                  icons[index],
                  color: AppTheme.primary,
                ),
                label: labels[index],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
