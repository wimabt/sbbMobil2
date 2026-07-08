/// Uygulama genelinde feature açma/kapama anahtarları.
///
/// ## Amaç
/// Büyük ya da çapraz-kesişen (cross-cutting) feature'ları kodu silmeden
/// gizlemek/aktif etmek için tek bir merkezi kontrol noktası sağlar.
/// Yorum satırına alma yöntemine göre avantajları:
///
/// * Kod canlı kalır — derlenir, test edilir, refactor edilebilir.
/// * Açma/kapama tek satır değişiklik ile yapılır.
/// * İlerleyen aşamada compile-time sabit yerine remote config
///   (Firebase Remote Config, kendi backend'iniz vb.) bağlanabilir;
///   tüketici tarafta tek bir değişiklik bile gerekmez.
///
/// ## Kullanım
/// ```dart
/// if (FeatureFlags.pointsEnabled) {
///   // puan UI'ı / API çağrısı / analytics event'i
/// }
/// ```
///
/// Repository / service katmanında erken `return` ile no-op davranış:
/// ```dart
/// Future<Points> getPoints() async {
///   if (!FeatureFlags.pointsEnabled) return Points.empty();
///   return _api.getPoints();
/// }
/// ```
///
/// ## Yeni flag eklerken
/// 1. Aşağıya `static const bool xxxEnabled = false;` satırını ekleyin.
/// 2. Tetikleyeceği UI/servis çağrılarını `if (FeatureFlags.xxxEnabled)` ile sarın.
/// 3. l10n string'leri, analytics event isimleri ve route tanımları
///    **silinmez**; sadece flag arkasına alınır.
/// 4. Flag'in `true` olduğu senaryo için en az 1 smoke test yazın.
///
/// ## Önemli
/// * Bu sınıf saf bir sabit konteyneridir — `const` constructor dışında
///   instance üretilmez. Test'lerde override etmek gerekirse `@visibleForTesting`
///   bir setter ya da Riverpod provider'a sarmayı tercih edin.
/// * Flag default değeri **kapalı (false)** olmalıdır. Bir feature
///   production'a hazır olduğunda flag açılır.
class FeatureFlags {
  const FeatureFlags._();

  // ---------------------------------------------------------------------------
  // Puan / Gamification sistemi
  // ---------------------------------------------------------------------------
  //
  // Kapsamı:
  //   * Home: points_card, nearby_points_banner, collect_points_card
  //   * Profile: stats_row, completed_routes_provider puan alanları
  //   * Campaigns: tüm ekran ve provider'lar
  //   * Routes: route_gamification_provider, route_stop_card puan rozetleri
  //   * AR: ar_points_repository, ar_service collect akışı
  //   * Services: daily_login_service, point_collection_service
  //   * Backend endpoint'leri: /api/v1/mobile/daily-login, /streak,
  //     /points, /campaigns, /ar/points, /collect ...
  //
  // false iken:
  //   * Hiçbir puan UI'ı render edilmez.
  //   * Puan ile ilgili HTTP çağrısı yapılmaz (repository katmanında no-op).
  //   * Analytics event'leri tetiklenmez.
  //   * Router'da campaigns rotası register edilmez.
  //
  // İleride remote config'e bağlanacak. Şimdilik build-time env üzerinden
  // kontrol ediliyor:
  //
  //   flutter build apk --dart-define=POINTS_ENABLED=true
  //   flutter run --dart-define=POINTS_ENABLED=true
  //
  // Default kapalı — env tanımlanmazsa veya farklı bir değer verilirse false.
  static const bool pointsEnabled =
      bool.fromEnvironment('POINTS_ENABLED', defaultValue: false);
}
