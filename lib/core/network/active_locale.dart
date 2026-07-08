import 'package:shared_preferences/shared_preferences.dart';

/// Aktif uygulama dilini SharedPreferences'tan okuyan yardımcı.
///
/// Riverpod'a erişimi olmayan uzun-ömürlü HTTP istemcileri (`ApiService`,
/// `StaffApiService`) ve arka plan isolate'leri için tek kaynak. Dil tercihi:
///   * `app_locale`     — `LocaleNotifier.setLocale` tarafından yazılır (kanonik)
///   * `app_locale_v1`  — `apiClientProvider` tarafından aynalanır (yedek)
/// Hiçbiri yoksa Türkçe ('tr') varsayılır.
class ActiveLocale {
  ActiveLocale._();

  static const List<String> _supported = ['tr', 'en'];

  /// Senkron erişim için son okunan dilin in-memory cache'i. İlk istekte
  /// boş olabilir → 'tr' kullanılır, sonraki istekler güncel değeri yakalar.
  static String _cached = 'tr';

  static String get cachedLanguageCode => _cached;

  /// Kaydedilmiş aktif dili oku (örn. 'tr' | 'en'). Desteklenmeyen değer 'tr'.
  static Future<String> languageCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString('app_locale') ??
              prefs.getString('app_locale_v1') ??
              'tr')
          .toLowerCase()
          .split(RegExp(r'[_-]'))
          .first;
      final lang = _supported.contains(raw) ? raw : 'tr';
      _cached = lang;
      return lang;
    } catch (_) {
      return _cached;
    }
  }
}
