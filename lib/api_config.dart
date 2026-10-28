class ApiConfig {
  /// Base URL backend DriveMate.
  /// Mengarah ke server API production DriveMate di SnapDeploy.
  /// Dapat dioverride saat build/run menggunakan --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://drivemate-3c397.containers.snapdeploy.app',
  );
}
