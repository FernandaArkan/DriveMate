import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF07182D),
              Color(0xFF0B2948),
              Color(0xFF164B78),
              Color(0xFF071323),
            ],
            stops: [0.0, 0.42, 0.72, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 100,
                right: -50,
                child: _glow(180),
              ),
              Positioned(
                top: 300,
                left: -70,
                child: _glow(160),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 100,
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF020915)
                            .withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppTheme.cyan.withValues(alpha: 0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 35,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_car_filled_rounded,
                        color: AppTheme.cyan,
                        size: 58,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'DriveMate',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your Vehicle, Our Priority',
                      style: TextStyle(
                        color: Color(0xFFD0E5FF),
                        fontSize: 14,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(flex: 3),
                    const Icon(
                      Icons.directions_car_rounded,
                      color: Color(0xFF80C8FF),
                      size: 100,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Asisten pribadi untuk\nkendaraan Anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(
                            context,
                            '/login',
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glow(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.24),
            AppTheme.primary.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}