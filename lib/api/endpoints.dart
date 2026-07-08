/// API endpoint sabitleri
/// Tüm endpoint path'lerini tek noktada yönetir
library;

class ApiEndpoints {
  ApiEndpoints._();

  // Base paths
  static const String basePath = '/api/v1';

  // Health
  static const String health = '/health';

  // Places
  static const String places = '/places';
  static const String placesSummary = '/places/summary'; // Optimize edilmiş özet endpoint
  static String place(String id) => '/places/$id';
  static const String placesNearby = '/places/nearby';
  static const String placesSearch = '/places/search';
  static const String placesFeatured = '/places/featured';
  static const String placesCategories = '/places/categories';

  // Recipes
  static const String recipes = '/recipes';
  static String recipe(String id) => '/recipes/$id';
  static const String recipesSearch = '/recipes/search';
  static const String recipesQuick = '/recipes/quick';
  static const String recipesPopular = '/recipes/popular';

  // Categories
  static const String categories = '/categories';
  static String category(String id) => '/categories/$id';
  static String subcategories(String id) => '/categories/$id/subcategories';

  // Favorites (Auth required — `mobile_pending_changes.md` B15)
  // Backend yeni mobil prefix'i altında yayınlandı.
  static const String favorites = '/api/v1/mobile/favorites';
  static const String favoritesPlaces = '/api/v1/mobile/favorites/places';
  static const String favoritesRoutes = '/api/v1/mobile/favorites/routes';
  static const String favoritesRecipes = '/api/v1/mobile/favorites/recipes';
  static const String favoritesToggle = '/api/v1/mobile/favorites/toggle';
  static const String favoritesCheck = '/api/v1/mobile/favorites/check';

  // Şehir Rehberi & Blog — sbbMobilBackend (authApiClient). Tam path.
  static const String blog = '/api/v1/mobile/blog';
  static const String blogFeatured = '/api/v1/mobile/blog/featured';
  static const String blogCategories = '/api/v1/mobile/blog/categories';
  static const String blogTags = '/api/v1/mobile/blog/tags';
  static String blogPost(String slugOrId) => '/api/v1/mobile/blog/$slugOrId';
  static String blogView(String id) => '/api/v1/mobile/blog/$id/view';

  // Announcements - Duyurular API (sbbMobilBackend → authApiClient)
  // Not: Artık CMS değil, Docker backend'den okunur (memory: doğru backend kuralı).
  static const String announcements = '/api/v1/mobile/announcements';
  static String announcement(String id) => '/api/v1/mobile/announcements/$id';
  static const String announcementsLatest = '/api/v1/mobile/announcements/latest';
  static const String announcementsImportant = '/api/v1/mobile/announcements/important';
  static const String announcementsCategories = '/api/v1/mobile/announcements/categories';
  static const String announcementsSearch = '/api/v1/mobile/announcements/search';
  static String announcementsByCategory(String categoryId) => '/api/v1/mobile/announcements/category/$categoryId';
  static String announcementView(String id) => '/api/v1/mobile/announcements/$id/view';
  // Bildirimler sayfası — push olarak gönderilmiş duyurular.
  static const String announcementsNotifications = '/api/v1/mobile/announcements/notifications';
  static String announcementNotificationClick(String id) => '/api/v1/mobile/announcements/$id/notification-click';

  // Routes (not in API guide, local extension)
  /// Travel routes (rotalar) endpoint'i
  /// Backend'de ModSecurity nedeniyle `/routes` yerine `/travel-routes` kullanılıyor.
  static const String routes = '/travel-routes';
  static String route(String id) => '/travel-routes/$id';
  static const String routesSearch = '/travel-routes/search';
  static String routesDifficulty(String level) =>
      '/travel-routes/difficulty/$level';
  static const String routesDistance = '/travel-routes/distance';

  // Events – Etkinlikler API (EVENTS_API_MOBILE_KULLANIM.md)
  static const String events = '/events';
  static String event(String id) => '/events/$id';
  static const String eventsCategories = '/events/categories';
  static const String eventsFeatured = '/events/featured';
  static const String eventsUpcoming = '/events/upcoming';
  static const String eventsSearch = '/events/search';
  static String eventView(String id) => '/events/$id/view';

  // Culture (not in API guide, local extension)
  static const String culture = '/culture';
  static String culturePlace(String id) => '/culture/$id';
  static const String cultureEvents = '/culture/events';

  // Campaigns (not in API guide, local extension)
  static const String campaigns = '/campaigns';
  static String campaign(String id) => '/campaigns/$id';

  // ─── Mobile Endpoints (Auth backend – flutter-integration.md §8-10) ────────

  // Mobile Places (§8)
  static const String mobilePlaces = '/api/v1/mobile/places';
  static String mobilePlace(String id) => '/api/v1/mobile/places/$id';
  static String mobilePlaceVisit(String placeId) =>
      '/api/v1/mobile/places/$placeId/visit';

  // Mobile Routes (§9)
  static const String mobileRoutes = '/api/v1/mobile/routes';
  static String mobileRoute(String id) => '/api/v1/mobile/routes/$id';
  static String mobileRouteStopVisit(int routeId, String placeId) =>
      '/api/v1/mobile/routes/$routeId/places/$placeId/visit';
  static const String mobileRoutesProgress = '/api/v1/mobile/routes/progress';
  /// Bir rotayı tamamen "tamamlandı" işaretle/kaldır (POST/DELETE).
  static String mobileRouteComplete(String routeId) =>
      '/api/v1/mobile/routes/$routeId/complete';

  // Mobile User Activity — ziyaret + tamamlanan rota (kullanıcıya bağlı).
  // Profil "Ziyaret"/"Rota" sayaçları ve toggle durumları buradan beslenir.
  static const String mobileUserActivity = '/api/v1/mobile/user/activity';

  // Mobile Points (§10)
  static const String mobilePointsBalance = '/api/v1/mobile/points/balance';
  static const String mobilePointsHistory = '/api/v1/mobile/points/history';

  // Mobile Campaigns (mobile_integ.md §1)
  static const String mobileCampaigns = '/api/v1/mobile/campaigns';
  static const String mobileMyCampaigns = '/api/v1/mobile/campaigns/my';
  static String mobileCampaign(String id) =>
      '/api/v1/mobile/campaigns/$id';
  static String mobileCampaignEnroll(String id) =>
      '/api/v1/mobile/campaigns/$id/enroll';
  static const String mobileCampaignsHistory =
      '/api/v1/mobile/campaigns/history';

  // Mobile Achievements (mobile_integ.md §2)
  static const String mobileAchievements = '/api/v1/mobile/achievements';

  /// `mobile_pending_changes.md` B8 — Kalıcı (persistent) QR çözümleme
  /// (auth gerekmez). Sorgu: `?code=<8-12 char>`.
  static const String qrResolve = '/api/v1/qr/resolve';

  /// `mobile_pending_changes.md` B2 — Geofence bölgeleri (auth gerekmez,
  /// Cache-Control: max-age=300). Query `?lang=tr|en`.
  static const String geofenceZones = '/api/v1/geofence/zones';

  /// `mobile_pending_changes.md` B4 — Isı haritası (auth gerekmez, opsiyonel).
  /// Query: `?bbox=<minLat,minLng,maxLat,maxLng>&since=<iso8601>`.
  ///
  /// **Not:** `ApiConfig.baseUrl` zaten `/api/v1` ile bitiyor — bu yüzden
  /// endpoint sabitinde `/api/v1` tekrar edilmez. Aksi takdirde URL
  /// `…/api/v1/api/v1/map/heatmap` şeklinde duplikat olur.
  static const String mapHeatmap = '/map/heatmap';

  // Mobile QR Spending (§14 + staff_mobile.md §10)
  static const String mobileWalletGenerateQr = '/api/v1/mobile/wallet/generate-qr';
  static const String mobileQrStream = '/api/v1/mobile/qr/stream';
  static const String mobileQrGenerate = '/api/v1/mobile/qr/generate';
  static const String mobileQrSession = '/api/v1/mobile/qr/session';

  // Mobile Facilities (staff_mobile.md §4.7)
  static const String mobileFacilities = '/api/v1/mobile/facilities';
  static String mobileFacility(String id) => '/api/v1/mobile/facilities/$id';
  static String mobileFacilityMenu(String id) =>
      '/api/v1/mobile/facilities/$id/menu';

  // Mobile Daily Login & Streak (§16)
  static const String mobileDailyLogin = '/api/v1/mobile/daily-login';
  static const String mobileStreak = '/api/v1/mobile/streak';

  // Mobile AR (ar_bcknd.md)
  static String mobileArPlace(String id) => '/api/v1/mobile/ar/place/$id';
  static const String mobileArResolve = '/api/v1/mobile/ar/resolve';

  /// backend_ar_todo.md AR2 — geospatial AR noktaları (yakın çevre POI lookup).
  static const String mobileArPoints = '/api/v1/mobile/ar/points';

  // Staff QR & Transactions (§15)
  static const String staffQrRedeem = '/api/v1/staff/qr/redeem';
  static const String staffTransactions = '/api/v1/staff/transactions';
  static const String staffProfile = '/api/v1/staff/profile';

  // ─── mobile_integ.md A1-A5 (Auth backend) ─────────────────────────

  /// A1 §6.3.5 — Kullanıcı ilgi alanları (GET/PUT)
  static const String userInterests = '/api/v1/user/interests';

  /// A4 §7.4.2 — Bildirim tercihleri (GET/PUT)
  static const String userNotificationPrefs =
      '/api/v1/user/notification-prefs';

  /// A2 (KVKK §10.6.3, §14.2.3) — Açık rıza kaydı (POST) + durum (GET).
  /// Cihazda tutulan rızanın sunucu tarafında denetim izi (ip_hash +
  /// timestamp) ile kalıcılaştırılması için. Auth gerektirir.
  static const String userConsents = '/api/v1/user/consents';

  /// §5.3.2 / §14.2.3 — Yayımlanmış yasal metinler (public, OTA).
  /// `?lang=` ile dil; yalnız is_draft=false olanlar döner.
  static const String legalDocuments = '/api/v1/legal/documents';

  /// Ana sayfa görünümü (hero görseli) — panelden yönetilen config (public, OTA).
  /// `{ hero: { imageUrl, thumbnailUrl, focalX, focalY, fit } }`. imageUrl null
  /// ise mobil bundle'daki varsayılan asset kullanılır.
  static const String homeConfig = '/api/v1/mobile/home-config';

  /// A2 §6.3.6 — Analitik batch event endpoint (POST)
  static const String analyticsEvents = '/api/v1/analytics/events';

  /// A3 §6.4 — Discovery feed (Thin Feed: sıralı `{type, id}` listesi)
  static const String discoveryFeed = '/api/v1/discovery/feed';

  /// A3 §3.2/4 — Mobil kategori adı çözümü (`category_id` → display name).
  /// Açılışta bir kez çağrılır, sonuç bellekte cache'lenir. Legacy
  /// `place.category` free-text alanı yerine kullanılır ("Attraction" sapması
  /// bu yüzden ortaya çıkıyordu).
  static const String mobileCategories = '/api/v1/mobile/categories';

  /// A5 §6.5.2 — Itinerary CRUD endpoints
  static const String itineraries = '/api/v1/itineraries';
  static String itineraryById(String id) => '/api/v1/itineraries/$id';
  static String itineraryItems(String id) => '/api/v1/itineraries/$id/items';
  static String itineraryItem(String id, String itemId) =>
      '/api/v1/itineraries/$id/items/$itemId';
  static String itineraryOrder(String id) =>
      '/api/v1/itineraries/$id/items/order';
}
