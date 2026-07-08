import 'dart:io' show Platform;

/// Product User-Agent for backend analytics / WAF (P2-2). OS reflects the real device.
String buildSbbMobileUserAgent() {
  if (Platform.isIOS) {
    return 'SBBMobile/1.0 (iOS)';
  }
  final os = Platform.operatingSystem;
  if (os.isEmpty) {
    return 'SBBMobile/1.0 (Unknown)';
  }
  final osName = os.replaceFirst(os[0], os[0].toUpperCase());
  return 'SBBMobile/1.0 ($osName)';
}
