/// Shared baseUrl configuration for both:
/// - Auth backend (citizen/mobile integration)
/// - Staff/backoffice backend (staff POS)
///
/// Run-time override (recommended):
///   --dart-define=AUTH_STAFF_API_BASE_URL=http://192.168.1.45
///
/// Backwards compatibility:
///   - If AUTH_STAFF_API_BASE_URL not set, we fall back to:
///     - AUTH_API_BASE_URL
///     - STAFF_API_BASE_URL
///   - If none are set, defaults to Android emulator:
///     - http://10.0.2.2
library;

import 'app_network_config.dart';

class AuthStaffApiConfig {
  AuthStaffApiConfig._();

  /// Auth + staff için tek base URL.
  ///
  /// Tek kaynak: `AppNetworkConfig.manualApiBaseUrl` (veya env override).
  static String get baseUrl => AppNetworkConfig.apiBaseUrl;
}

