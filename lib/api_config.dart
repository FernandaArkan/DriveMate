class ApiConfig {
  /// Base URL backend DriveMate.
  /// Secara default mengarah ke server lokal http://127.0.0.1:8080.
  /// Dapat dioverride saat build/run menggunakan --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );
}
