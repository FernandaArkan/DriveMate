import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const background = Color(0xFFF4F7FD);
  static const surface = Color(0xFFFFFFFF);
  static const navy = Color(0xFF142B50);
  static const primary = Color(0xFF1683F8);
  static const cyan = Color(0xFF35C8F2);
  static const textPrimary = Color(0xFF17233B);
  static const textSecondary = Color(0xFF7D8AA3);
  static const success = Color(0xFF20B486);
  static const warning = Color(0xFFFFA53D);
  static const danger = Color(0xFFE65365);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        surface: surface,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.12),
        height: 72,
        labelTextStyle:
            WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? primary
                : textSecondary,
          );
        }),
        iconTheme:
            WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : textSecondary,
          );
        }),
      ),
    );
  }
}