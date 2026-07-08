/// Tek noktadan ağ/base URL yönetimi.
///
/// İstediğin zaman buradaki `manualApiBaseUrl` değerini değiştirerek
/// tüm auth + staff isteklerinin aynı host'a gitmesini sağlayabilirsin.
///
/// Opsiyonel: Derleme sırasında env define göndermek istersen
/// `--dart-define=SBB_API_BASE_URL=http://192.168.1.49` ile bu değeri override edebilirsin.
class AppNetworkConfig {
  AppNetworkConfig._();

  /// Manuel base URL (tek kaynak).
  static const String manualApiBaseUrl = 'https://mobil.smartsamsun.com';

  /// Optional override: `--dart-define=SBB_API_BASE_URL=...`
  static const String _envApiBaseUrl =
      String.fromEnvironment('SBB_API_BASE_URL', defaultValue: '');

  static String get apiBaseUrl =>
      _envApiBaseUrl.isNotEmpty ? _envApiBaseUrl : manualApiBaseUrl;
}

