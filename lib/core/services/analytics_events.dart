/// Şartname §6.3.6 + `mobile_analytics_todo.md` §2 — Mobil tarafından üretilen
/// analitik olay sözlüğü.
///
/// Backend tarafındaki şema ile **birebir senkron** olmalıdır. Yeni event
/// eklendiğinde panel dropdown'ı (DISTINCT query ile) otomatik tanır; Türkçe
/// etiket için backend tarafında `src/public/admin/app.js` içindeki
/// `EVENT_DICT` map'ine slug eklemek yeterli.
class AnalyticsEvents {
  AnalyticsEvents._();

  // ── §2.1 Yaşam döngüsü / oturum ─────────────────────────────────────
  static const sessionStart = 'session_start';
  static const sessionEnd = 'session_end';
  static const screenView = 'screen_view';
  static const onboardingCompleted = 'onboarding_completed';

  // ── §2.2 İçerik açılışları ──────────────────────────────────────────
  static const placeDetailOpened = 'place_detail_opened';
  static const routeDetailOpened = 'route_detail_opened';
  static const eventDetailOpened = 'event_detail_opened';

  // ── §2.3 Medya tüketimi ─────────────────────────────────────────────
  static const galleryOpened = 'gallery_opened';
  static const imageViewed = 'image_viewed';
  static const videoPlayStarted = 'video_play_started';
  static const videoPlayCompleted = 'video_play_completed';
  static const audioPlayStarted = 'audio_play_started';

  // ── §2.4 Aksiyon butonları ──────────────────────────────────────────
  static const favoriteToggled = 'favorite_toggled';
  static const shareTapped = 'share_tapped';
  static const directionsRequested = 'directions_requested';
  static const phoneTapped = 'phone_tapped';
  static const websiteTapped = 'website_tapped';
  static const contentTapped = 'content_tapped';

  // ── §2.5 Engagement ─────────────────────────────────────────────────
  static const descriptionExpanded = 'description_expanded';
  static const scroll75 = 'scroll_75';

  // ── §2.6 Arama ve keşif ─────────────────────────────────────────────
  static const searchSubmitted = 'search_submitted';
  static const searchResultTapped = 'search_result_tapped';
  static const discoveryCardTapped = 'discovery_card_tapped';
  static const filterApplied = 'filter_applied';

  // §6.4 — Kişiselleştirme: "Sizin İçin" bölümü ilk render edildiğinde.
  static const personalizedSectionShown = 'personalized_section_shown';

  // ── §2.7 Harita ─────────────────────────────────────────────────────
  static const mapOpened = 'map_opened';
  static const mapMarkerTapped = 'map_marker_tapped';

  // ── §2.8 QR / AR ────────────────────────────────────────────────────
  static const qrScanned = 'qr_scanned';
  static const arOpened = 'ar_opened';

  // Geospatial AR (backend_ar_todo.md AR5)
  static const arGeoTriggered = 'ar_geo_triggered';
  static const arGeoDismissed = 'ar_geo_dismissed';
  static const arActionTapped = 'ar_action_tapped';

  // World-anchored AR (şartname §6.8.3.4)
  static const arWorldSessionStarted = 'ar_world_session_started';
  static const arWorldAnchorPlaced = 'ar_world_anchor_placed';
  static const arWorldModelLoaded = 'ar_world_model_loaded';
  static const arWorldModelTapped = 'ar_world_model_tapped';
  static const arWorldDriftResync = 'ar_world_drift_resync';
  static const arWorldSessionEnded = 'ar_world_session_ended';
  static const arWorldFallback = 'ar_world_fallback';

  // 3D model loading perf
  static const arModelLoaded = 'ar_model_loaded';

  // ── §2.9 Rotalar ────────────────────────────────────────────────────
  static const routeStarted = 'route_started';
  static const routeStopTapped = 'route_stop_tapped';
  static const placeVisited = 'place_visited';

  // ── §2.10 Itinerary (gezi planlama) ─────────────────────────────────
  static const itineraryCreated = 'itinerary_created';
  static const itineraryItemAdded = 'itinerary_item_added';
  static const itineraryItemRemoved = 'itinerary_item_removed';
  static const itineraryRenamed = 'itinerary_renamed';
  static const itineraryDeleted = 'itinerary_deleted';
  static const itineraryReordered = 'itinerary_reordered';

  // ── §2.11 Bildirimler ───────────────────────────────────────────────
  static const notificationReceived = 'notification_received';
  static const notificationOpened = 'notification_opened';

  // ── §2.12 Geofence ──────────────────────────────────────────────────
  static const geofenceEntered = 'geofence_entered';
  static const geofenceExited = 'geofence_exited';

  // ── §2.13 Ayarlar / kimlik ──────────────────────────────────────────
  static const preferenceChanged = 'preference_changed';
  static const languageChanged = 'language_changed';
  static const authLogin = 'auth_login';
  static const authLogout = 'auth_logout';
  static const authRegister = 'auth_register';
  static const errorOccurred = 'error_occurred';

  // ── §2.14 Chatbot / Akıllı Asistan (§6.9) ───────────────────────────
  // KVKK uyumu: ASLA kullanıcı metni veya bot cevabı loglanmaz.
  // Sadece intent_type + success flag + (varsa) eşleşen kart sayısı.
  static const chatbotOpened = 'chatbot_opened';
  static const chatbotMessageSent = 'chatbot_message_sent';
  static const chatbotIntentResolved = 'chatbot_intent_resolved';
  static const chatbotQuickReplyTapped = 'chatbot_quick_reply_tapped';
  static const chatbotCardTapped = 'chatbot_card_tapped';
  static const chatbotCleared = 'chatbot_cleared';
}

/// `mobile_analytics_todo.md` §4 — İçerik açılışı kaynağı enum'ı.
/// String sabitler — backend'in `place_detail_opened.source` için beklediği
/// kanonik değerler. Yeni source eklenmek istenirse backend `EVENT_DICT`
/// içine de Türkçe etiket eklenmeli.
class AnalyticsSource {
  AnalyticsSource._();

  static const list = 'list';
  static const search = 'search';
  static const map = 'map';
  static const qr = 'qr';
  static const routeStop = 'route_stop';
  static const deeplink = 'deeplink';
  static const discovery = 'discovery';
  static const favorite = 'favorite';
  static const itinerary = 'itinerary';
  static const notification = 'notification';
}
