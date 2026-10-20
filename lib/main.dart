import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/splash_page.dart';
import 'pages/vehicles_page.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DriveMateApp());
}

class DriveMateApp extends StatelessWidget {
  const DriveMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int selectedIndex = 0;

  static const List<String> labels = [
    'Home',
    'Kendaraan',
    'Perjalanan',
    'AI',
    'Profil',
  ];

  static const List<IconData> icons = [
    Icons.home_outlined,
    Icons.directions_car_outlined,
    Icons.map_outlined,
    Icons.smart_toy_outlined,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: switch (selectedIndex) {
        0 => const HomePage(),
        1 => const VehiclesPage(),
        _ => _buildPlaceholderPage(),
      },
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
            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
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

  Widget _buildPlaceholderPage() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          labels[selectedIndex],
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(
                  icons[selectedIndex],
                  size: 42,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                labels[selectedIndex],
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Halaman ini sedang dikembangkan '
                'untuk melengkapi DriveMate.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    selectedIndex = 0;
                  });
                },
                icon: const Icon(Icons.home_rounded),
                label: const Text('Kembali ke Home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}