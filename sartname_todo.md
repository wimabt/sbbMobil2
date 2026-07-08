# Şartname Eksiklikleri — TODO Listesi

> **Kaynak:** `sartname.md` ile mevcut Flutter proje kodu karşılaştırması  
> **Son Güncelleme:** 29 Mayıs 2026 — Kod ile madde-madde **doğrulama** turu. Önceki TODO'da "Eksik" görünen ama aslında tamamlanmış 2 büyük madde düzeltildi (#16 Chatbot, #41 Hesap Silme), kısmi/yanlış işaretlenenler güncellendi, şartnamede olup TODO'da hiç olmayan yeni maddeler eklendi (#65–#69). Detaylı doğrulama notu için bkz. **"29 MAYIS DOĞRULAMA NOTU"** bölümü.
> **Önceki:** 22 Mayıs 2026 — Şartname tam tarama (madde-madde) sonrası 24 yeni tespit eklendi.

---

## ⚠️ 29 MAYIS 2026 DOĞRULAMA NOTU (kod ile bire bir kontrol)

Aşağıdaki maddeler **kaynak kodla doğrulanarak** düzeltilmiştir — önceki durum yanlıştı:

| # | Önceki Durum | **Gerçek Durum (doğrulandı)** | Kanıt |
|---|---|---|---|
| **16** | 🔴 "chatbot feature'ı hiç yok" | ✅ **TAMAMLANDI** | `lib/features/chatbot/` tam kurulu: intent matcher + NLU (text_normalizer, fuzzy_match, entity_extractor) + 18 handler + history repo + `/chatbot` route'u kayıtlı. |
| **41** | 🔴 "Hesabımı Sil akışı YOK" | ✅ **TAMAMLANDI** | `auth_provider.dart` `deleteAccount()`/`restoreCurrentAccount()` + 30 gün soft-delete + `pending_deletion_banner.dart` + `settings_section.dart` `_DeleteAccountButton` (onay dialog + neden seçimi + son uyarı). Backend `DELETE/POST /user/account` entegre. |
| **31** | 🟡 "turn-by-turn doğrulanmalı" | ✅ **Karşılanıyor** | `place_detail_screen.dart:414` Google Maps'e harici handoff (`directions_requested` analytics) + in-app OSRM güzergah çizimi. Turn-by-turn dış uygulamaya devrediliyor — kabul edilebilir. |
| **11** | 🟡 "Kısmi — dinamik içerik şüpheli" | 🟢 **Mobil taraf hazır** | `api_client.dart:47,62` her istekte `Accept-Language` header + `lang` query param gönderiyor; locale değişince client rebuild (`:404`). Kalan iş backend'in dile göre alan döndürmesi — mobil mekanizma tam. |
| **55** | 🔴 "Eksik (#16'ya bağlı)" | ✅ **Mobil taraf karşılandı** | `chatbot_history_repository.dart`: sadece cihazda saklama (SharedPreferences), retention limiti, "Sohbeti temizle" silme + KVKK §14.4.2/§6.9.6 yorum referansı. `fallback_handler.dart` uydurma yapmıyor (§6.9.6.3 ✓). |
| **52** | ✅ "Modelde var" | 🟡 **Modelde var ama KULLANILMIYOR** | `ar_point.dart:62` `altitude_m` okunuyor; `ar_sensor_service.dart:44` sadece yorum. Matching engine altitude'u kullanmıyor — yalnızca lat/lng. |
| **51** | 🟡 "Doğrulanmalı" | 🔴 **Gerçek açık** | `ar_point.dart:44` `priority` alanı VAR ama `ar_geo_provider.dart:225` yalnız mesafeye göre sıralıyor, priority kullanmıyor; camera overlay (`:225 for-loop`) TÜM eşleşmeleri gösteriyor — **max görünür POI limiti yok** (§6.8.3.6 karşılanmıyor). |
| **32** | 🟡 "Doğrulanmalı" | 🟢 **Kısmen hazır** | `flutter_secure_storage` token saklamada kullanılıyor (`api_service.dart`, `api_client.dart`, `staff_api_service.dart`). HTTPS zaten var. Diğer hassas alanlar değerlendirilmeli. |

**Hâlâ gerçekten eksik/açık olduğu doğrulanan kritik maddeler:**
- **#4 Culture route** — `app_router.dart`'ta yalnız `/events` ve `/events/:id` var; `culture_screen.dart`/`culture_detail_screen.dart` dosyaları mevcut ama `/culture` route'u **hâlâ kayıtlı değil**. (30 dk'lık iş, doğrulandı.)
- **#42 KVKK Aydınlatma + Açık Rıza UI** — kayıt/login ekranında consent checkbox YOK, onboarding'de rıza adımı YOK, "Yasal/Gizlilik Politikası/Aydınlatma" menüsü/ekranı YOK. Yalnız ayarlarda analytics opt-out toggle var. **Gerçek açık.**
- **#10 Offline içerik önbellekleme** — `sqflite` pubspec'te tanımlı ama `lib/` içinde **hiç kullanılmıyor**; Hive/Isar yok. Yalnız image cache + AR cache manager + offline banner mevcut. Kalıcı içerik DB'si **yok**. Gerçek açık.

---

## 🔴 KRİTİK EKSİKLER (Şartname doğrudan karşılanmıyor)

### 1. ~~Onboarding / İlk Kullanım Ekranları (§6.3.5)~~ ✅ TAMAMLANDI
- [x] `lib/features/onboarding/presentation/` feature'ı oluşturuldu.
- [x] 4 sayfalık tanıtım akışı (Hoş geldiniz / Keşfet / Kazan-Deneyimle / İlgi alanları) — ikon + başlık + açıklama düzeni, sayfa indikatörü ve "Atla" desteği.
- [x] Son sayfada **isteğe bağlı ilgi alanı seçimi** (8 slug: historic, culture, nature, food, events, routes, ar_qr, recipes) — daha sonra `discovery_service`'e beslenecek (Faz 1 #7).
- [x] `OnboardingNotifier` SharedPreferences ile `onboarding_completed_v1` bayrağını ve `user_interests` listesini kalıcılaştırıyor; versiyonlu anahtar gelecekte revizyona izin veriyor.
- [x] `main.dart` startup paralel görevlerine eklendi; `app_router.dart` redirect içinde gating yapıyor — auth/staff rotaları hariç ilk açılışta `/onboarding`'a yönlendiriliyor, akış tamamlanınca `/` döner.
- [x] **mobile_integ.md PR#2** — `UserPreferencesRepository` ile `/api/v1/user/interests` GET/PUT senkronu: onboarding tamamlanınca auth varsa PUT, login sonrası `postLoginSyncProvider` ile reconcile (sunucu kazanır, ilk seferde local→server backfill).

---

### 2. ~~Gezi Planlama / İtinerary Modülü (§6.5.2)~~ ✅ TAMAMLANDI (uçtan uca backend + mobil)
> mobile_integ.md PR#6+#7: `ApiItineraryRepository` + auth-aware provider switch (LocalItineraryRepository ↔ ApiItineraryRepository) + login sonrası local→server migration + `ORDER_MISMATCH` 409 retry.
- [x] `lib/data/models/itinerary.dart` — `Itinerary` + `ItineraryItem` + `ItineraryEntityType` + JSON serileştirme.
- [x] `lib/data/repositories/itinerary_repository.dart` — `ItineraryRepository` (abstract) + `LocalItineraryRepository` (SharedPreferences-backed).
- [x] `itineraries_provider.dart` — Riverpod notifier, list/create/delete/rename/addItem/updateItem/removeItem/reorderItems + analytics.
- [x] `ItinerariesScreen` (liste + oluşturma bottom sheet), `ItineraryDetailScreen` (drag-drop sıralama + tarih+saat picker + kaldırma + ad değişimi).
- [x] Add-item akışı: detay ekranında places önbelleğinden seçim.
- [x] `/itinerary` ve `/itinerary/:id` route'ları, profil ayarlar kartında "Gezi Planlarım" giriş noktası.
- [x] `itinerary_created` ve `itinerary_item_added` analytics event'leri.
- [x] **Harita üzerinde önerilen güzergah** (§6.5.2 son madde): `ItineraryMapScreen` + OSRM `getRouteMultiStop` çoklu durak güzergah hesaplaması, marker'lar + polyline + özet kartı (km / dk / durak sayısı / eksik konum sayısı). Detay ekranındaki AppBar'a "Haritada Göster" butonu, route: `/itinerary/:id/map`.
- [x] **Place detayından "Plana Ekle" akışı**: `AddToItinerarySheet` widget'ı, mevcut planlardan seçim veya inline yeni plan oluşturma. Place detail SliverAppBar'a `add_location_alt` butonu eklendi.
- [ ] **Backend bekliyor:** `/api/v1/itineraries` endpoint'leri + `itineraries` / `itinerary_items` tabloları (bkz. [backend_todo.md](backend_todo.md) → A5). API'ye geçiş için sadece yeni `ApiItineraryRepository` + provider switch yeterli.

---

### 3. ~~Favoriler Ekranı (§6.5.1)~~ ✅ TAMAMLANDI
- [x] `/favorites` route'u `app_router.dart`'a eklendi (shell içinde).
- [x] `FavoritesScreen` 4 sekmeli (Mekanlar / Tarifler / Rotalar / Lezzetler) olarak oluşturuldu, ilgili Notifier önbelleklerinden filtre uygulanıyor — ek API isteği yok.
- [x] Profil ekranındaki ayarlar kartının ilk satırına **"Favorilerim"** kısayolu eklendi.
- [x] Her karttan ilgili detay ekranına yönlendirme (`/places/...`, `/recipes/...`, `/routes/...`, `/gastronomy/...`) çalışıyor.
- [x] Kart üzerindeki kalp ikonu favorilerden çıkarma işlemini liste içinden tetikliyor (§6.5.1 son madde).

---

### 4. ~~Kültür Sayfası Router Kaydı (§6.2, §6.3.2)~~ ✋ YAPILMAYACAK (29 May kararı)
> **Karar:** Ayrı `/culture` route'una gerek yok — kültür içeriklerine **etkinlikler (`/events`) üzerinden** erişilecek. Şartname §6.2/§6.3.2 (kültürel içeriklere erişim) etkinlik akışıyla karşılanmış sayılıyor.
- [x] ~~`events_screen.dart` ve `event_detail_screen.dart` → `/events` ve `/events/:id` route'ları router'da kayıtlı.~~ ✅
- [~] `culture_screen.dart` dosyaları repoda duruyor ama route'lanmayacak (ileride temizlenebilir / events içine gömülebilir).
- [ ] Shell navigasyonunda veya keşif alanında kültür içeriklerine erişim linklenmeli.
- **Not:** Events kısmı tamamlandı, culture listesi router'a eklenmeli.

---

### 5. ~~Analitik / Kullanıcı Davranışı İzleme (§6.3.6)~~ ✅ TAMAMLANDI
> mobile_integ.md PR#4: `AnalyticsService.flush()` artık `POST /api/v1/analytics/events` batch çağırıyor (maks 50/istek, 30 ev veya 30s'de otomatik flush, app pause'da flush, logout pre-flush). 4xx → drop, 413/429/5xx → exp. backoff (3 deneme). Buffer SharedPreferences ile cold-start arası kalıcı.
- [x] `lib/core/services/analytics_service.dart` + `analytics_events.dart` + `analytics_route_observer.dart` eklendi (kendi servisimiz, 3rd party'siz — KVKK §14.5 için tercih edilir).
- [x] Olay sözlüğü tanımlı: `screen_view`, `session_start`, `onboarding_completed`, `favorite_toggled`, `content_tapped`, `search_submitted`, `qr_scanned`, `ar_opened`, `place_visited`, `route_started`.
- [x] `GoRouter.observers` + `ShellRoute.observers` üzerinden tüm route geçişlerinde otomatik `screen_view` tetikleniyor.
- [x] Onboarding tamamlama + favori toggle event'leri bağlandı; her event payload'a `user_id`, `session_id`, `platform`, `locale`, `occurred_at` ekleniyor.
- [ ] **Backend bekliyor:** `POST /api/v1/analytics/events` batch endpoint + `analytics_events` tablosu (bkz. [backend_todo.md](backend_todo.md) → A2). `flush()` metodu hazır olduğunda etkinleşecek.
- [ ] Yönetim panelinde olay raporlaması (günlük/haftalık agregasyon) — backend tarafında.

---

### 6. ~~Harita Isı Haritası (§6.5.3)~~ ✅ TAMAMLANDI
- [x] `map_screen.dart` `_heatmapEnabled` toggle + `Set<Heatmap>` katmanı + `_scheduleHeatmapFetch` debounce (200 ms) ile görünür bbox değiştikçe yeniden çekiyor.
- [x] `map_heatmap_repository.dart` 5 dk cache, aynı bbox tekrar fetch etmiyor.
- [x] Backend `/api/v1/map/heatmap?bbox&since` endpoint'i canlı (B4).
- [x] Son 14 günün ziyaret/etkileşim verisi üzerinden ısı yoğunluğu hesaplanıyor.
- **Not:** Admin panel tarafında heatmap yönetim ekranı eklenmedi — şu an analytics'ten otomatik beslenmesi yeterli görünüyor.

---

## 🟡 ORTA ÖNCELİKLİ EKSİKLER

### 7. ~~Akıllı Öneri / Kişiselleştirme Sistemi (§6.4)~~ ✅ TAMAMLANDI
> mobile_integ.md PR#5: `DiscoveryRepository` + `/api/v1/discovery/feed` entegrasyonu; home ekranında 4 ayrı carousel (Yakındakiler / Popüler / Yeni Eklenenler / Öne Çıkanlar). Sunucu yanıtı yoksa local heuristic (`personalized_places_provider`) "Sizin İçin" olarak fallback olur. Pull-to-refresh feed'i yeniler.
- [x] `lib/features/home/presentation/providers/personalized_places_provider.dart` — onboarding'de seçilen ilgi alanlarına göre `placesProvider.allPlaces` üzerinden puanlama (kategori/etiket/isim eşleşmesi +3, AR içerik + `ar_qr` ilgisi +4, `featured` +1.5, yakınlık 0–2 lineer, ziyaret edilmiş −0.8).
- [x] Home ekranına **"Sizin İçin"** bölümü eklendi (kategoriler ile öne çıkanlar arasına); ilgi seçilmediyse veya skor üreten yer yoksa otomatik gizlenir.
- [x] `FeaturedPlacesSection` `title` ve `actionText` override desteği aldı, kart tasarımı tek noktada kalsın diye paylaşıldı.
- [ ] **Yakında / popüler / yeni / öne çıkan** olarak 4 ayrı bölüme bölme (§6.4.2): mobil tarafta yapılabilir ama anlamlı olması için backend'de "popüler" (analytics agregasyon) ve "yeni eklenen" alanlarına ihtiyaç var → bkz. [backend_todo.md](backend_todo.md) → A3.
- [ ] **Öne çıkarılan içerik yönetim panelinden** (§6.4.6): backend `featured_contents` tablosu + admin UI gerekli (A3'te şema mevcut).
- [ ] Davranış geçmişi (analytics olayları) henüz öneri skoruna yansımıyor — backend `/discovery/feed` devreye girince doğal olarak akacak; mobil tarafta heuristik eklenebilir ama daha az faydalı.

---

### 8. ~~Konum Bazlı Bildirimler / Geofence Bildirimleri (§7.3)~~ ✅ TAMAMLANDI
- [x] `geofence_service.dart` ve `background_geofence_worker.dart` mevcut.
- [x] **24 saat cooldown mekanizması** tam uygulanmış: `_kCooldownHours = 24`, `_isCooldownActive()`, `_saveCooldownTimestamp()` — hem foreground hem background worker'da çalışıyor (§7.3.5). ✅
- [ ] Lokasyon bazlı bildirim tetikleme senaryolarının **yönetim panelinden yapılandırılabilmesi** için backend entegrasyonu tamamlanmalı (bölge listesi şu an hardcoded).

---

### 9. ~~Bildirim Tercihleri Ekranı (§7.4)~~ ✅ TAMAMLANDI
> mobile_integ.md PR#3: `NotificationPrefsNotifier` artık `/api/v1/user/notification-prefs` ile GET (login sonrası reconcile, sunucu kazanır) + PUT (500ms debounce). 4 toggle (general / campaigns / events / geofence); OneSignal `prefs` tag senkron.
- [x] `lib/core/services/notification_prefs_service.dart` — Genel / Kampanya / Etkinlik için 3 ayrı toggle, SharedPreferences kalıcılığı; Genel kapanınca OneSignal opt-out, açılınca opt-in.
- [x] **Lokasyon bazlı (geofence)** dördüncü toggle olarak ayrı `GeofenceService` üstünden ayar ekranında yan yana gösteriliyor (toplam 4 toggle: §7.4.2).
- [x] OneSignal free plan 2-tag limitine uyum: Kampanya + Etkinlik tercihleri tek `prefs` tag'i altında comma-separated saklanır; backend hedefleme bu tag üzerinden filtreleyebilir.
- [x] Genel kapalıyken alt kategori toggle'ları otomatik gri/disabled hale geliyor (UX).
- [ ] **Backend bekliyor:** `GET/PUT /api/v1/user/notification-prefs` + `user_notification_prefs` tablosu (bkz. [backend_todo.md](backend_todo.md) → A4) — cihazlar arası senkron için.

---

### 10. ~~Çevrimdışı (Offline) Mod Desteği (§5.1.2, §6.8.5)~~ ✅ TAMAMLANDI (29 Mayıs)
- [x] **Kalıcı içerik önbelleği**: `lib/core/cache/offline_content_cache.dart` — başarılı GET yanıtlarını diske yazar (path_provider tabanlı, tüm platformlarda çalışır; sqflite'ın masaüstü FFI derdi yok). 30 gün TTL + 400 kayıt limiti + otomatik eviction.
- [x] **Stale-on-error interceptor**: `offline_cache_interceptor.dart` — GET 2xx yanıtları saklar; bağlantı hatasında (retry'lar tükendikten sonra) cache'ten servis eder. `ApiClient`'a (içerik client'ı: places/recipes/routes/events/announcements/gastronomy) bağlandı; `main.dart` startup'ta `init()`.
- [x] **Sonuç:** "Daha önce görüntülenen yer detayı / etkinlik / tarif" (§6.8.5'teki birebir örnekler) artık çevrimdışı açılıyor — repository'lere dokunmadan, şeffaf.
- [x] **Kullanıcı bilgilendirme (§6.8.5):** `OfflineBanner` zaten `scaffold_shell.dart:90`'da global mount — çevrimdışıyken üstte bant görünüyor. `x-from-offline-cache` header'ı + `extra['fromOfflineCache']` ile cache yanıtı işaretli (gerekirse per-ekran rozet için hazır).
- [x] AR içerikleri için önceden indirme: `ar_cache_manager.dart` mevcut (§6.8.5 AR tarafı; ayrı kapsam).
- [ ] **İsteğe bağlı geliştirme:** İçerik-yazımı (POST/PUT) çevrimdışı kuyruğu gerekmiyor (uygulama okuma-ağırlıklı); gerekirse ileride eklenebilir. `no_cache` extra bayrağıyla hassas GET'ler hariç tutulabilir.

---

### 11. Çoklu Dil — Yönetim Paneli Entegrasyonu (§6.7, §8.6)
- [ ] `l10n/` klasörü ve `app_en.arb` / `app_tr.arb` dosyaları mevcut.
- [ ] Ancak şartname "**dil içerikleri yönetim paneli üzerinden ayrı ayrı yönetilebilir**" diyor — yani statik ARB değil dinamik içerik çoklu dil desteği.
- [ ] Her mekan/etkinlik/duyuru için API'den çoklu dil alanlarının (`title_tr`, `title_en` vb.) alınması ve görüntülenmesi sağlanmalı.
- [ ] Dil değiştiğinde içeriklerin API'den tekrar çekilmesi veya önbellekten doğru dil versiyonunun gösterilmesi sağlanmalı.

---

### 12. ~~Koyu/Açık Tema Desteği (§5.2.4, §7.4.5)~~ ✅ TAMAMLANDI
- [x] `app_theme.dart` ve `theme_provider.dart` mevcut. ✅
- [x] `theme_selector.dart` widget'ı profil ekranında entegre — Light/Dark/System üç mod destekleniyor. ✅
- [x] Seçilen tema tercihi `SharedPreferences` ile **kalıcı olarak saklanıyor**. ✅
- [x] **İlk açılışta varsayılan = Sistem** (`ThemeNotifier.build()` → `ThemeMode.system`, `main.dart` `themeMode: themeState.mode`). ✅
- [x] **Girişsiz erişim (29 May):** Profil ayarları giriş gerektirdiğinden tema seçici **ana sayfa sol üst ☰ menüsüne (drawer)** de eklendi — `ThemeSelector(showTitle:false)` "Görünüm" bölümü altında. Giriş yapmayan kullanıcılar da temayı değiştirebiliyor. ✅

---

### 13. QR Kod Yönetim Paneli Entegrasyonu (§6.8.2)
- [ ] `qr_services.dart` mevcut; QR okuma çalışıyor.
- [ ] Ancak şartname "**QR kodlar yönetim paneli üzerinden tanımlanabilecek ve içerikler ile ilişkilendirilebilecek**" diyor — bu için backend tarafında QR kod yönetim API'leri ve admin UI gerekiyor.
- [ ] QR kod okunduğunda tetiklenen içerik bağlantısının **deep link veya doğrudan içerik açma** akışı tam test edilmeli.

---

### 14. AR — Yönetim Paneli AR Noktası Tanımlama (§6.8.3.8) — ✅ TAMAMLANDI (Phase 1)
- [x] Backend AR1–AR7 canlıda: `GET /api/v1/mobile/ar/points?lat&lng&radius_km&lang[&preview_token]` + `POST /api/v1/admin/ar/points/:id/preview-token` + admin CRUD.
- [x] Mobil tarafta entegrasyon tamamlandı:
  - `lib/data/models/ar_point.dart` — `ArPoint` + `ArMatchedPoint` + `ArPointAction` modelleri (info_card / image_2d / model_3d / audio / video / animation tipleri)
  - `lib/data/repositories/ar_points_repository.dart` — `fetchNearby(lat, lng, radius_km, [preview_token])`
  - `lib/core/services/ar_sensor_service.dart` — GPS + kompas birleşik akış (Haversine + bearing geometri yardımcılarıyla)
  - `lib/features/ar/presentation/providers/ar_geo_provider.dart` — Matching engine: radius + bearing tolerans kontrolü, kullanıcı 500m hareket ettiğinde veya 3dk'lık önbellek eskidiğinde otomatik refetch
  - `lib/features/ar/presentation/ar_geo_screen.dart` — Pusula radar (CustomPainter) + mesafe sıralı POI listesi + dinamik banner'lar (önizleme modu, pusula kalibrasyonu, GPS doğruluğu)
  - Analytics: `ar_geo_triggered / ar_geo_dismissed / ar_action_tapped`
  - Route: `/ar-geo` + home quick access'ta **"Çevremde AR"** girişi
- [x] **Phase 2 (12 Mayıs 2026):** Camera-overlay görselleştirmesi tamamlandı.
  - `camera: ^0.11.0` eklendi
  - `ArCameraOverlayScreen` — `CameraPreview` arkaplan + bearing'e göre konumlanan POI kartları (FOV 65° varsayılan)
  - §6.8.3.3 "kamera üzerine bindirme" + §6.8.3.7 "tamamen kapatmama" maddeleri karşılandı (yarı saydam kartlar üst yarıda)
  - Lifecycle: pause → dispose, resume → re-init
  - Toggle: Radar ↔ Kamera mod geçişi her iki ekranın AppBar'ında
  - Route: `/ar-camera` (ArReadinessGate ile sarmalı)

---

### 15. AR — Sensör Füzyonu ve Hata Senaryoları (§6.8.3.5, §6.8.3.10) — 🟡 KISMİ
- [x] **Kamera izni reddi**: `qr_ar_scanner_screen.dart` → `MobileScanner` `errorBuilder` ile `_ScannerErrorFallback` widget'ı; kullanıcıya "Ayarlara Git" butonu (`permission_handler.openAppSettings()`) + "Geri Dön" sunuluyor.
- [x] **Desteklenmeyen cihaz**: Aynı widget içinde `MobileScannerErrorCode.unsupported` için ayrı mesaj.
- [x] **Genel kamera hatası**: Generic fallback ile yeniden deneme yönlendirmesi.
- [x] **AR model indirme hatası** (`ar_viewer_screen.dart`): zaten `_buildErrorState` ile "Tekrar Dene" butonu mevcut.
- [x] **AR-incapable cihaz fallback**: `model_viewer_plus` Scene Viewer/Quick Look başarısızsa otomatik 3D-only önizlemeye düşüyor — özel UI gerektirmedi.
- [x] **Cihaz desteği + izin önerme katmanı** (12 Mayıs 2026): `ArReadinessGate` widget'ı + `ArCapabilityService` ile `/ar` ve `/qr-ar-scanner` rotaları öncesinde tek noktadan kontrol: cihaz Android/iOS mı, kamera izni, (opsiyonel) konum izni + GPS doğruluğu < 50 m. Engelleyici sorunda kullanıcıya anlaşılır mesaj + "Ayarlara Git / Yeniden Dene" butonları.
- [x] **Düşük GPS doğruluğu uyarısı**: `ArReadinessGate` GPS doğruluğu > 50 m olduğunda kullanıcıyı sekiz şeklinde hareketle pusulayı kalibre etmeye yönlendiriyor (§6.8.3.5).
- [ ] **Aktif pusula kalibrasyon sensörü** (§6.8.3.5): Şu an kalibrasyon uyarısı statik mesaj. Geospatial AR sprintinde `flutter_compass`'ın `CompassEvent.accuracy` alanı dinlenip canlı uyarıya çevrilecek.

---

### 16. ~~Chatbot / Akıllı Asistan Modülü (§6.9)~~ ✅ TAMAMLANDI (29 Mayıs doğrulandı)
- [x] `lib/features/chatbot/` feature'ı tam kurulu: `chatbot_screen.dart` + `chatbot_provider.dart` + mesaj balonu / quick-reply / typing indicator / inline card widget'ları.
- [x] Metin tabanlı sorgulama arayüzü çalışıyor; `/chatbot` route'u kayıtlı (`app_router.dart:409`).
- [x] **Yalnızca uygulama içi içerik** (§6.9.2.2): intent matcher + NLU katmanı (`text_normalizer`, `fuzzy_match`, `entity_extractor`, `intent_matcher`) + `intent_dictionary` — harici AI çağrısı YOK; tüm yanıtlar handler'lar üzerinden yerel veriden üretiliyor.
- [x] Desteklenen senaryolar (§6.9.3.3): `category_handler`, `nearby_handler`, `event_handler`, `place_detail_handler`, `route_handler`, `recipe_handler`, `announcement_handler`, `directions_handler`, `itinerary_help_handler`, `favorites_handler`, `samsun_info_handler`, `greet/help/feedback/fallback`.
- [x] §6.9.6.3 "hatalı/doğrulanmamış bilgi sunmama": `fallback_handler` uydurma yapmıyor, "anlayamadım, şunları deneyin" ile yönlendiriyor.
- [x] §6.9.6 KVKK: `chatbot_history_repository.dart` sadece cihazda saklama + retention limiti + "Sohbeti temizle" (bkz. #55).
- [ ] **Backend bekliyor (§6.9.4.2):** Yönetim panelinden içeriğin chatbot'ta kullanılabilirliği bayrağı — admin tarafı.
- [ ] **Doğrulanmalı (§6.9.7.1):** Handler tabanlı mimari LLM entegrasyonuna açık; ileride `intent_handler` arayüzünün LLM provider ile genişletilebilirliği dokümante edilmeli.

---

## 🟢 DÜŞÜK ÖNCELİKLİ / DOĞRULANMASI GEREKEN MADDELER

### 17. Kullanıcı Kaydı — Web Tabanlı Doğrulama (§6.3.1)
- [ ] Şartname "kullanıcı üye olma işlemi **web tabanlı doğrulama yöntemi** ile olacaktır" diyor.
- [ ] `auth/` feature'ında OTP akışı mevcut — bunun web tabanlı mı yoksa native OTP mi olduğu netleştirilmeli; gerekirse web view tabanlı kayıt akışına geçilmeli.

### 18. ~~API Versiyonlama (§9.2.3)~~ ✅ TAMAMLANDI
- [x] `endpoints.dart` satır 9: `basePath = '/api/v1'` — tüm endpoint'ler versiyonlanmış yapıda. ✅
- [ ] Geriye dönük uyumluluk stratejisi belirlenmeli ve dokümante edilmeli.

### 19. API Dokümantasyonu (§9.8)
- [ ] Tüm API endpoint'leri için **Swagger/OpenAPI** dokümantasyonu hazırlanmalı ve İdare'ye teslim edilmeli.

### 20. Performans — 1000 Eş Zamanlı Kullanıcı Testi (§15.1.2)
- [ ] Backend ve API katmanının **1.000 eş zamanlı kullanıcıyı** destekleyip desteklemediği yük testleri ile doğrulanmalı.
- [ ] 500 kullanıcı aynı anda QR okuttuğunda yanıt süresinin **2 saniyeyi aşmadığı** test edilmeli (§15.1.3).

### 21. AR Yüklenme Süresi Testi (§15.2.2)
- [ ] 3G (5 Mbps) bağlantıda AR içeriklerinin **8 saniye içinde yüklenmesi** performans testi yapılmalı ve raporlanmalı.

### 22. AR Batarya Tüketimi Testi (§15.3.2)
- [ ] 30 dakika AR kullanımında batarya tüketiminin **%15'i aşmadığı** farklı cihaz modellerinde test edilmeli.

### 23. Beta / UAT / SAT Süreçleri (§15.4)
- [ ] **Beta test**, **Kullanıcı Kabul Testi (UAT)** ve **Sistem Kabul Testi (SAT)** süreçleri için plan oluşturulmalı.
- [ ] Test raporları hazırlanarak İdare'ye sunulmalı.

### 24. Mağaza Yayın Süreçleri (§12)
- [ ] Google Play Store ve Apple App Store geliştirici hesabı erişimi İdare'den alınmalı.
- [ ] Mağaza görselleri, açıklamaları ve tanıtım videoları Samsun BBB kurumsal kimliğine uygun hazırlanmalı (§12.2).
- [ ] Versiyon numaralandırma ve changelog takip sistemi oluşturulmalı (§12.3).

### 25. ~~Güvenlik — Tersine Mühendislik Koruması (§5.5.3, §10.4.1)~~ ✅ BÜYÜK ÖLÇÜDE TAMAMLANDI (29 May)
- [x] **Android R8/ProGuard** doğrulandı: `build.gradle.kts` release → `isMinifyEnabled = true` + `isShrinkResources = true` + `proguard-android-optimize.txt` + kapsamlı `proguard-rules.pro` (Flutter, dio, gson, okhttp, maps, geolocator, mlkit, webview keep kuralları + native/parcelable/enum koruması).
- [x] **Dart kod obfuscation**: `scripts/build_release.ps1` + `.sh` — `flutter build --release --obfuscate --split-debug-info=symbols/...` (Android + iOS). R8 sadece Java/Kotlin'i sarar; bu script asıl `libapp.so` Dart kodunu da karıştırır. Sembol dosyaları `symbols/` (`.gitignore`'da) ayrılır, ship edilmez, de-obfuscation için arşivlenir.
- [x] **Log sızıntısı engellendi**: `main.dart` release/profile'da `debugPrint` no-op'a çevrildi (logcat/Console'a iç akış sızmaz). Dosya log'u zaten yalnız `kDebugMode`'da.
- [x] **Root/jailbreak tespiti**: `device_integrity_service.dart` startup'ta `checkAndWarn` ile bağlı; tehlikeli cihazda QR/puan kısıtlanıyor.
- [x] **Hassas veri**: token'lar `flutter_secure_storage` (Keychain/Keystore); trafik HTTPS.
- [x] Tüm tedbirler `docs/SECURITY_HARDENING.md`'de dokümante edildi + release build talimatı.
- [ ] **Kalan (CI/operasyon):** CI'da release'in **yalnızca** `build_release.*` ile alınması zorunlu kılınmalı; iOS dSYM/strip akışı CI'da doğrulanmalı; SSL pinning + Play Integrity API ileri aşama değerlendirilmeli.

### 26. KVKK — Açık Rıza ve Aydınlatma Metinleri (§10.6, §14.2)
- [ ] Üyelik gerektiren alanlarda kullanıcıdan **açık rıza alınması** için rıza onay ekranı/dialog oluşturulmalı.
- [ ] Aydınlatma metinleri İdare onayı ile hazırlanmalı ve uygulama içinde sunulmalı (§14.2.3).
- [ ] Veri saklama, silme ve anonimleştirme işlemleri için backend tarafında mekanizma oluşturulmalı (§14.4).

### 27. Yönetim Paneli — Log ve Denetim İzleme (§8.7, §9.7)
- [ ] Yönetim panelinde yapılan tüm işlemlerin (içerik düzenleme, bildirim gönderme vb.) **kayıt altına alınması** ve görüntülenebilmesi sağlanmalı.
- [ ] Kritik API hataları için **izleme ve uyarı mekanizması** (örn. Sentry, Datadog) kurulmalı.

### 28. Kiosk Sistemi ile İçerik Bütünlüğü (§3)
- [ ] Mevcut kiosk uygulamasında kullanılan içerik yapısının mobil uygulamayla **minimum düzenleme ile** uyumlu olup olmadığı doğrulanmalı.
- [ ] İdare talebinde kiosk↔mobil entegrasyon senaryoları hazır olmalı (§3, ücretsiz sağlanacak).

---

## 🆕 YENİ TESPİTLER — Şartnamede Olup Önceki TODO'da Eksik Olan Maddeler

> Aşağıdaki maddeler 8 Mayıs 2026 kod incelemesinde tespit edilmiştir.

### 29. ~~Arama ve Filtreleme (§6.6)~~ ✅ DOĞRULANDI
- [x] §6.6.1 — `AppSearchBar` tüm ana liste ekranlarında entegre: `places_screen` (sticky + floating), `recipes_screen` (header), `routes_screen` (header), `events_screen`, `announcements_screen`, `culture_header`, `places_header` (places_screen).
- [x] §6.6.2 — Kategori chip'leri: `places`, `routes`, `recipes`, `events` her birinde aktif. Arama yapıldıkça `_getFilteredCategories` ile kategori listesi de daralıyor.
- [x] §6.6.3 — Harita ekranında canlı arama: `map_screen.dart` `_onSearchChanged` → `_applyFilters()` her tuş vuruşunda anlık filtreliyor.
- **Not:** Server-side `placesSearch` / `recipesSearch` / `eventsSearch` endpoint'leri repository'de tanımlı; veri seti büyürse client-side filterden API search'e taşınabilir. Şu anki performans yeterli.

### 30. Etkinlik/Duyuru Otomatik Pasife Alma (§6.5.4)
- [ ] Süresi dolan etkinlik ve duyurular **otomatik olarak pasif duruma** alınabilecektir.
- **Mevcut Durum:** Backend tarafında kontrol edilmeli.

### 31. Navigasyon / Harita Yönlendirme (§6.3.2, §6.5.2)
- [ ] Kullanıcıların seçilen lokasyonlara erişim sağlayabilmesi amacıyla **harita tabanlı yönlendirme ve navigasyon** desteği sunulacaktır.
- **Mevcut Durum:** `osrm_service.dart` mevcut, route detail'de güzergah çizimi var. Tam navigasyon (turn-by-turn) doğrulanmalı.

### 32. Veri Güvenliği — SSL/TLS ve Şifreli Saklama (§10.3)
- [ ] Veri iletiminde **SSL/TLS** protokolü kullanılacaktır (§10.3.2).
- [ ] Hassas veriler mümkün olan durumlarda **şifrelenmiş olarak saklanacaktır** (§10.3.3).
- **Mevcut Durum:** API servisi HTTPS kullanıyor, yerel şifreleme (flutter_secure_storage vb.) doğrulanmalı.

### 33. API Güvenliği — Anormal Kullanım Tespiti (§10.5)
- [ ] API çağrıları izlenecek ve **anormal kullanım durumları** tespit edilebilecektir (§10.5.2).
- **Mevcut Durum:** Backend tarafında rate limiting / anomaly detection doğrulanmalı.

### 34. Test ve Kalite Güvencesi (§11)
- [ ] **Fonksiyonel testler**: Tüm modüllerin kullanıcı senaryolarına uygun çalıştığı doğrulanmalı (§11.2.1).
- [ ] **Uyumluluk testleri**: Android/iOS farklı sürüm ve cihazlarda test (§11.2.2).
- [ ] **Güvenlik testleri**: Yetkisiz erişim ve veri sızıntısı testleri (§11.2.4).
- [ ] **Test dokümantasyonu**: Tüm testler kayıt altına alınmalı, raporlanmalı (§11.4).

### 35. Bakım, Destek ve SLA (§13)
- [ ] **Hata sınıflandırması** tanımlanmalı: Kritik (4 saat müdahale), Orta (1 iş günü), Düşük (3 iş günü) — §13.4.
- [ ] **Periyodik bakım** planı oluşturulmalı (§13.2.1).
- [ ] **Destek kanalları** (e-posta, destek sistemi) belirlenmeli (§13.3.2).
- [ ] Bakım ve destek faaliyetleri **düzenli raporlanmalı** (§13.6).

### 36. Dokümantasyon ve Eğitim Materyalleri (§12.4)
- [ ] Uygulamanın ve yönetim panellerinin kullanımı ile ilgili **teknik dokümantasyon** hazırlanmalı.
- [ ] Dokümantasyon İdare'ye teslim edilmeli (§12.4.3).

### 37. Üçüncü Taraf Servis KVKK Uyumu (§14.5)
- [ ] Kullanılan üçüncü taraf servislerin (harita, bildirim, analitik vb.) **KVKK uyumluluğu** sağlanmalı.
- [ ] Kişisel veriler İdare onayı olmaksızın üçüncü kişilerle paylaşılmamalı (§14.5.2).

### 38. Veri Saklama ve Silme Mekanizması (§10.7, §14.4)
- [ ] Saklama süresi dolan verilerin **silinmesi/anonimleştirilmesi** için mekanizma oluşturulmalı.
- [ ] Veri silme ve anonimleştirme işlemleri **kayıt altına alınmalı** (§10.7.3).

### 39. Bildirim Gönderim Durumu İzleme (§9.6)
- [ ] Bildirim gönderim durumları ve hata bilgileri **sistem üzerinden izlenebilecektir** (§9.6.3).
- **Mevcut Durum:** `notification_service.dart` mevcut, gönderim durumu izleme doğrulanmalı.

### 40. Yönetim Paneli Rol Bazlı Yetkilendirme (§8.2)
- [ ] Farklı kullanıcı rolleri (sistem yöneticisi, içerik editörü, kampanya yöneticisi) tanımlanabilecek (§8.2.2).
- [ ] Her rol için erişilebilecek ekranlar ve işlemler ayrı ayrı belirlenebilecek (§8.2.3).
- **Mevcut Durum:** Admin panel tarafında doğrulanmalı.

---

## 🆕 EK TESPİTLER — 22 Mayıs 2026 Şartname Tam Tarama Sonuçları

> Aşağıdaki maddeler şartnamenin madde-madde okunması sonrası tespit edilmiştir.  
> Önceki TODO'da hiç olmayan veya çok yüzeysel geçen şartname zorunlulukları.

### 41. ~~Hesap Silme / KVKK Veri Silme Talebi (§14.4.2, §10.7.2)~~ ✅ TAMAMLANDI (29 Mayıs doğrulandı)
- [x] Mobil: `settings_section.dart` `_DeleteAccountButton` — onay dialog ("Hesabını silmek üzeresin" + sonuç listesi) + neden seçimi (`Gizlilik / veri kaygısı` vb.) + son uyarı + `_performDeletion`.
- [x] `auth_provider.dart`: `deleteAccount({reason})` → `POST /user/account`, başarılı silmede logout cleanup; `account_deletion_requested` analytics + pre-delete flush.
- [x] **30 gün soft-delete penceresi** + geri alma: `restoreCurrentAccount()` → `POST /user/account/restore`; cold-start'ta `GET /user/account/status` ile `pending_deletion_banner.dart` gösteriliyor.
- [x] OTP doğrulamada silme durumu yönetimi: `ACCOUNT_DELETION_PENDING` (409) → restore dialog, `ACCOUNT_DELETION_FINAL` (410) → register'a yönlendirme.
- [x] App Store 5.1.1 + KVKK §14.4.2/§10.7.2 karşılandı.
- [ ] **Backend tarafı doğrulanmalı:** soft-delete sonrası 30 gün dolunca kalıcı silme/anonimleştirme job'u çalışıyor mu (§10.7.3 kayıt altına alma dahil).

---

### 42. ~~Aydınlatma Metni + Açık Rıza UI Akışı (§10.6.3, §14.2.3, §6.3.1)~~ ✅ TAMAMLANDI (29 Mayıs)
- [x] **Yasal içerik katmanı**: `lib/features/legal/data/legal_documents.dart` — 4 belge (Aydınlatma Metni, Açık Rıza, Gizlilik Politikası, Kullanım Koşulları) tek noktada, `kLegalContentVersion` ile sürümlü. Her belge `isDraft` ile "Taslak" rozetli — İdare onayı sonrası `isDraft=false` + içerik güncellenir, UI değişmez.
- [x] **Açık rıza kalıcılık**: `consent_provider.dart` — `accept()/revoke()/load()`, kabul edilen sürüm + timestamp (denetim izi) SharedPreferences'ta; `kLegalContentVersion` artarsa rıza yeniden istenir. main.dart startup'ta `load()`.
- [x] **Kayıt formunda açık rıza**: `register_screen.dart` — checkbox + Aydınlatma Metni / Kullanım Koşulları tıklanabilir bağlantıları (TapGestureRecognizer). Kutu işaretlenmeden "Devam Et" pasif; onaylanınca `consentProvider.accept()` çağrılıp OTP gönderiliyor.
- [x] **Yasal merkez ekranları**: `LegalHubScreen` (`/legal`) + `LegalDocumentScreen` (`/legal/:docId`) — taslak uyarı banner'ı + bölümler + sürüm/tarih footer'ı.
- [x] **Profile → "Yasal" menüsü**: `settings_section.dart`'a `gavel` ikonlu giriş (`/legal`).
- [x] Router: `/legal` + `/legal/:docId` shell dışında; onboarding/kayıt gating muafiyeti eklendi (her aşamada açılabilir).
- [x] **Backend rıza senkronu (A2 — 30 May):** `ConsentRepository` (`POST/GET /api/v1/user/consents`) + `consent_provider.syncToServer()` (sürüm guard'lı) + `postLoginSyncProvider`'a rıza adımı eklendi. Rıza artık yalnız cihazda değil, auth sonrası **sunucuda denetim izi** (ip_hash + timestamp) ile kalıcılaştırılıyor (§10.6.3/§14.2.3). Backend migration 031 uygulanınca uçtan uca aktif. `flutter analyze` temiz.
- [ ] **İdare onayı bekliyor (§14.2.3):** Metinlerin nihai hali İdare tarafından onaylanıp `legal_documents.dart`'ta `isDraft=false` yapılmalı + `kLegalContentVersion` artırılmalı.
- [x] **Pre-permission rationale (§10.6.3) — TAMAMLANDI (29 May):** `lib/core/permissions/pre_permission_sheet.dart` — konum/arka-plan-konum/bildirim/kamera için açıklamalı ön-izin sheet'i (ikon + "ne için" + maddeler + "İzin Ver"/"Şimdi Değil").
  - **Soğuk promptlar kaldırıldı:** (a) `notification_service.initialize()` artık başlangıçta otomatik izin istemiyor; (b) `places_provider` konum yüklerken soğuk OS dialog'u tetiklemiyor — durum işaretliyor.
  - **Açıklamalı tetikleyiciler:** onboarding sonrası ilk home'da tek seferlik bildirim rationale (`home_screen` initState); Profil → Bildirim Ayarları "Genel Bildirimler" + "Yakınımdaki Yerler" toggle'larında sheet; konum CTA (`DiscoveryLocationCta`) zaten açıklayıcı kart; kamera/AR `ArReadinessGate` ile açıklamalı.

---

### 43. ⚪ Hedefli (Segmentli) Bildirim (§7.2.2) — KAPSAM DIŞI (İdare kararı, 30 May)
> **KESİN KARAR (İdare):** Tüm push bildirim yönetimi (genel, hedefli/segmentli, zamanlanmış, istatistik) **OneSignal'in kendi paneli** üzerinden yapılacaktır. Backend/admin panelinde ayrı bildirim ekranı geliştirilmeyecektir. §7.5/§8.5 "yönetim paneli" gereği OneSignal paneli ile karşılanır.
- [x] **Mobil hazır:** notification_prefs OneSignal `prefs` tag'i ile etiketliyor; segmentasyon panelden tag/segment ile yapılır.
- [ ] **Kod-dışı / İdare aksiyonu:** OneSignal free-plan **2-tag limiti** (`location`+`interests` dolu) dil/üyelik segmenti için yetmez → ücretli plan kararı **veya** segment kapsamını `location`+`interests` ile sınırlama.
- [ ] **KVKK (B-D11):** OneSignal'a tag gönderimi 3. taraf veri işleme → aydınlatma metni + envanter güncellenmeli.
- [x] **Mobil doğrulandı (30 May):** `notification_prefs_service.dart` — `setGeneral` opt-in/opt-out + `setCampaigns`/`setEvents`/reconcile hepsi `_syncCategoryTag()` çağırıyor; kategori kapanınca `prefs` tag'inden çıkarılıyor, hiçbiri aktif değilse `removeTags(['prefs'])` → kullanıcı segment dışı kalır.

---

### 44. ⚪ Zamanlanmış Bildirim (§7.2.3, §7.5.2) — KAPSAM DIŞI (İdare kararı, 30 May)
> **KESİN KARAR (İdare):** Zamanlanmış/manuel gönderim OneSignal panelinin **"Scheduled delivery"** özelliğiyle yapılacaktır. Backend `scheduled_notifications` tablosu/cron geliştirilmeyecektir.
- [x] OneSignal paneli "Scheduled delivery" + "Send to segments" gereği karşılıyor.
- [ ] **İdare aksiyonu:** OneSignal panel erişimi yetkili ekibe devredilir + kısa kullanım eğitimi/dokümanı.

---

### 45. 🟡 Kampanya / Üyelik Avantajı Modülü (§6.3.2, §14.2.2) — KISMI ✓
- [x] `lib/features/campaigns/` feature klasörü mevcut (`campaigns_screen.dart`, `campaign_detail_screen.dart`, `points_summary_card.dart`).
- [x] `/campaigns` ve `/campaigns/:id` route'ları kayıtlı (`app_router.dart:186`).
- [x] `point_collection_service.dart` puan toplama altyapısı mevcut.
- [x] `daily_login_service.dart` günlük giriş ödülü mevcut.
- [ ] **Doğrulanmalı:** Şartname §14.2.2'deki "puan kazanımı kapsamında üyelik gerektiren durumlarda açık rıza" akışı eklenmiş mi?
- [ ] **Doğrulanmalı:** Admin panelden kampanya oluşturma/yönetim UI'ı (§4.4.1, §8.2.2 "kampanya yöneticisi" rolü).
- [ ] **Doğrulanmalı:** Kampanya katılım koşulları, başlangıç/bitiş tarihi, hedef segment yönetimi.

---

### 46. 🟡 Hotfix / Acil Güncelleme Süreci (§12.1.7)
- [ ] Şartname: "Yayınlanan sürümlerde ortaya çıkabilecek kritik hatalar için **acil güncelleme (hotfix)** süreçleri işletilecektir."
- [ ] Branching strategy (`main` / `release/*` / `hotfix/*`) dokümante edilmeli.
- [ ] App Store / Play Store expedited review başvuru süreci doküman.
- [ ] Forced update mekanizması: `force_update` flag'i için backend endpoint + mobil tarafta versiyon kontrol gateway.

---

### 47. 🟡 Admin Panel Oturum Güvenliği + Parola Politikası (§8.8.2, §10.2.4)
- [ ] Parola karmaşıklık kuralları (min 8 karakter + büyük/küçük/rakam/özel).
- [ ] Oturum timeout (örn. 30 dk hareketsizlik).
- [ ] Max başarısız giriş denemesi (5 deneme → hesap geçici kilit / CAPTCHA).
- [ ] 2FA / MFA opsiyonu (özellikle sistem yöneticisi rolü için).
- **Not:** Bu admin panel tarafında — backend ekibiyle koordinasyon gerekli.

---

### 48. 🟡 Bildirim API Güvenliği / İmzalama (§7.6.3)
- [ ] Şartname: "Yetkisiz bildirim gönderimini engelleyecek güvenlik önlemleri alınacaktır."
- [ ] OneSignal REST API Key sadece backend'de tutulmalı (mobil tarafa hiç sızmamalı — grep ile doğrulandı, mobil tarafta yok ✓).
- [ ] Backend → OneSignal isteklerinde imzalı request (HMAC) veya IP whitelist.
- [ ] Admin panelinden bildirim gönderirken **çift onay** (özellikle "tüm kullanıcılara gönder" için).

---

### 49. 🟡 IP Kısıtlaması + Erişim Loglama (§9.3.4)
- [ ] Şartname: "Gerekli durumlarda IP kısıtlaması ve erişim loglaması uygulanabilecektir."
- [ ] Admin panel için IP whitelist (kurumsal ağ + VPN).
- [ ] API erişim loglarında IP + user agent + endpoint + timestamp kayıt.
- [ ] Anormal kullanım tespit edildiğinde otomatik bloklama (TODO #33 ile bağlantılı).

---

### 50. 🟢 Reklam / 3. Taraf Yönlendirici İçerik Yasağı (§5.1.3)
- [ ] Şartname: "Reklam, yönlendirici üçüncü taraf içerikler veya kullanıcı deneyimini bozacak unsurlar içermeyecektir."
- [ ] Kod tabanı audit: Hiçbir AdMob/Facebook Ads SDK'sı yüklenmemiş olmalı (`pubspec.yaml` kontrol).
- [ ] Üçüncü taraf SDK envanteri: OneSignal, Google Maps, Mapbox, Sentry/Datadog (varsa) — her birinin amacı dokümante edilmeli (KVKK §14.5 ile bağlantılı).

---

### 51. ~~AR — POI Çakışma Yönetimi + Öncelik (§6.8.3.6)~~ ✅ TAMAMLANDI (29 Mayıs)
Şartname §6.8.3.6'nın beş parametrik maddesi:
- [x] **Maksimum yaklaşma mesafesi** — `ArPoint.radiusM` / `minDistanceM` (backend'den, per-POI).
- [x] **Min/max görüş açısı** — `ArPoint.bearingTolDeg` + kamera FOV (`_kCameraFovDeg`).
- [x] **Aynı anda azami AR öğe sayısı** — `kMaxVisibleArItems` (ar_geo_provider.dart, parametrik sabit; backend/global ayara taşınabilir). Kamera overlay bu sayıyı aşmaz.
- [x] **Öncelikli içerik sıralaması** — `compareArMatchesByPriorityThenDistance`: önce `priority↓`, eşitlikte `mesafe↑`. `_recomputeMatches` artık bu sırayla sıralıyor; hem radar listesi hem kamera faydalanıyor. (Daha önce `priority` alanı modelde olup **hiç kullanılmıyordu**.)
- [x] **Çakışma yönetimi** — kamera overlay'inde yerleşmiş kart merkezleri izlenir; üst üste binecek (aynı bearing) düşük öncelikli/uzak kartlar atlanır → "en yakın/en önemli öne çıkar" karşılandı.
- [ ] **İleride (backend):** `kMaxVisibleArItems` + per-POI `priority` admin panelden yönetilebilir hale gelince mobilde ek değişiklik gerekmez (alanlar zaten bağlı).

---

### 52. ~~AR — Altitude/Yükseklik Desteği (§6.8.3.2, §6.8.3.7)~~ ✅ TAMAMLANDI (30 May)
- [x] `lib/data/models/ar_point.dart` — `altitudeM` modelde, JSON `altitude_m`'den okunuyor.
- [x] **World-scene (3B):** `ArGeoAnchorService` yükseklik farkını zaten Y eksenine yansıtıyor (test: "yükseklik farkı Y eksenine yansır" ✓).
- [x] **Matching + kamera overlay (30 May):** Önceden ArMatchedPoint sadece lat/lng kullanıyordu. Artık:
  - `ArSensorReading`'e kullanıcı GPS yüksekliği (`altitudeM` + `altitudeAccuracyM` + `hasReliableAltitude`) eklendi.
  - `_recomputeMatches` POI `altitude_m` + güvenilir GPS yüksekliği varsa **elevation açısı** hesaplıyor (`atan2(Δyükseklik, mesafe)`) → `ArMatchedPoint.elevationAngleDeg`/`hasElevationData`.
  - `ArCameraOverlayScreen` kartı, elevation açısı ile **cihaz pitch** farkına göre dikey konumlandırıyor (gerçek AR dikey hizalama, dikey FOV 50°); §6.8.3.7 okunabilirlik için 0.12–0.55 bandına klamplı. Yükseklik verisi yoksa mevcut mesafe-tabanlı konuma düşüyor. (Daha önce hesaplanıp kullanılmayan `devicePitchDeg` artık devrede.)
- [x] **Doğrulama:** `flutter analyze` 0 sorun; `ar_geo_anchor_service_test` 13/13 geçti.
- [ ] (Doğrulanacak — backend/canlı) `/api/v1/mobile/ar/points` response'unda `altitude_m` dolu mu (İdare verisi). Boşsa kart otomatik mesafe-tabanlı konuma düşer (kırılma yok).

---

### 53. ~~AR — Proaktif Önbelleğe Alma (§6.8.3.9)~~ ✅ TAMAMLANDI (30 May)
- [x] Şartname: "Kamera açıldığında bekleme süresi azaltılması için bölgedeki muhtemel AR içeriklerini önceden sorgulayabilecek ve önbelleğe alabilecek."
- [x] `ar_cache_manager.dart`'a **`prefetchModels()`** eklendi: ayrı `_prefetchCancelToken` (talep-üzerine viewer indirmesini iptal etmez), sıralı + best-effort, cache'tekini atlar (idempotent), `.part`→rename ile yarım dosya bırakmaz, `maxModels` ile sınırlı (§6.8.4 batarya/veri). `cancelPrefetch()` + provider onDispose'a bağlı.
- [x] **Bölgeye girince tetikleme:** `ar_geo_provider._fetchPoints` başarısından sonra `_prefetchNearbyModels` — yakındaki POI'lerin 3B modellerini (sensör varsa **en yakın önce**) fire-and-forget prefetch eder. Geo provider zaten 500m hareket / 3dk eskime ile yeniden fetch ediyor → "bölgeye girme" semantiği. Cache manager `build()`'de watch'la canlı tutuluyor (autoDispose erken iptalini önler).
- [x] **Payoff doğrulandı:** `ar_viewer_screen` zaten `getLocalModelPath` ile önce cache'e bakıyor → prefetch sonrası model **anlık** açılır (offline da çalışır, §6.8.5).
- [x] `flutter analyze` 0 sorun; `ar_geo_anchor_service_test` 13/13.
- [ ] (Kapsam: ses/video prefetch eklenmedi — görseller zaten `cached_network_image`'da; 3B modeller en ağır/etkili kalem. Gerekirse aynı desenle genişletilebilir.)

---

### 54. 🟢 AR — Online-Only İçerikte Kullanıcı Uyarısı (§6.8.5)
- [ ] Şartname: "İnternet bağlantısı gerektiren içerikler için kullanıcı bilgilendirilecektir."
- [ ] AR ekranında bağlantı yokken → ön belleğe alınmış içerikler işaretlenmeli, online-only içerikler için "bu içerik için bağlantı gerekli" badge'i.

---

### 55. 🟡 Chatbot — KVKK + Log İşleme Politikası (§6.9.6)
- [ ] Şartname §6.9.6.1: "Chatbot sistemi, kullanıcıdan alınan verileri KVKK kapsamında değerlendirecek."
- [ ] §6.9.6.2: "Kullanıcıdan alınan metin verileri, yalnızca hizmet sunumu amacıyla işlenecektir."
- [ ] Chatbot feature'ı henüz oluşturulmadı (TODO #16). Oluşturulurken aşağıdakiler unutulmamalı:
  - Konuşma loglarının saklama süresi (örn. 30 gün → anonimleştir).
  - Kullanıcıya "konuşmamı sil" opsiyonu.
  - Aydınlatma metnine chatbot'un veri işleme açıklaması eklenmeli.

---

### 56. 🟢 Çoklu Dil — Desteklenecek Diller Netleştirme (§6.7.1)
- [ ] Şartname: "Türkçe başta olmak üzere **birden fazla dil** desteği sunacaktır."
- [x] Şu an: `app_tr.arb` + `app_en.arb` mevcut.
- [ ] **İdare ile netleştirilmeli:** İngilizce yeterli mi yoksa Arapça/Rusça/Almanca/Farsça gibi turist hedef kitleli diller de gerekli mi?
- [ ] Samsun turist profilinde Rus + Arap turist görece yüksek — değerlendirilmeli.

---

### 57. 🟢 Veri Bütünlüğü Teknik Tedbirleri (§10.3.4)
- [ ] Şartname: "Veri bütünlüğünü bozacak işlemlere karşı gerekli teknik tedbirler alınacaktır."
- [ ] Backend: DB transaction izolasyonu, optimistic locking (ör. itinerary ORDER_MISMATCH benzeri).
- [ ] Critical operations için audit trail (kim, ne zaman, ne değiştirdi).
- [ ] API request idempotency keys (çift POST koruması, özellikle ödeme/puan işlemlerinde).

---

### 58. 🟢 Yetkisiz Giriş Denemesi Loglama (§8.8.3, §10.2.3)
- [ ] Şartname: "Yetkisiz erişim girişimleri kayıt altına alınacaktır."
- [ ] Backend: 401/403 dönen istekler audit log'a kayıt + threshold aşılırsa Sentry/Slack uyarısı.
- [ ] Admin panele başarısız login denemeleri görüntülenebilir olmalı.

---

### 59. 🟢 Mobile ↔ Admin Schema Tutarlılık Doğrulaması (§9.4.3)
- [ ] Şartname: "Yönetim paneli ile mobil uygulama arasında **tutarlı veri yapısı** sağlanacaktır."
- [ ] Backend API schema'sının (örn. OpenAPI) mobile DTO'larıyla eşleşmesi otomatik test edilmeli (kontrakt testi).
- [ ] Bir backend değişikliği mobile'da hangi alanları etkiler — schema diff raporu CI'a eklenmeli.

---

### 60. 🟢 Mağaza Politika Takibi (§13.5.3)
- [ ] Şartname: "Uygulama mağazası politikalarında meydana gelen değişikliklere uyum sağlanacaktır."
- [ ] Apple App Store / Google Play developer policy değişiklik takibi süreç dokümanı (örn. her quarter review).
- [ ] Son 2 yıldaki kritik politika değişiklikleri: Google'ın foreground service izinleri, iOS App Tracking Transparency, hesap silme zorunluluğu.

---

### 61. 🟢 2-3 Adım Navigasyon UX Audit (§6.3.3)
- [ ] Şartname: "Ana fonksiyonlara (keşif, harita, etkinlikler, arama vb.) en fazla **2–3 adımda** erişim."
- [ ] Tüm ana fonksiyonlar için kullanıcı yolculuğu çıkarılmalı: tap sayısı sayılmalı.
- [ ] 3 adımdan fazla yer alan flow'lar yeniden tasarlanmalı (bottom nav + shortcut kombinasyonları).

---

### 62. 🟢 Periyodik İçerik Güncelleme Operasyonu (§6.3.4)
- [ ] Şartname: "İçeriklerin periyodik olarak güncellenmesi sağlanacaktır."
- [ ] Operasyonel: İdare ile içerik takvimi (ör. her ay yeni 5 mekan, her hafta etkinlik).
- [ ] Bayatlamış içerik (örn. 6 ay güncellenmemiş yer) admin panelinde flag'lenmeli.

---

### 63. 🟢 Harmony OS Desteği Değerlendirme (§5.1.2)
- [ ] Şartname: "iOS, Android **ve gerektiğinde Harmony** işletim sistemlerini destekleyecek."
- [ ] Flutter 3.16+ HarmonyOS NEXT (HarmonyOS 4.x) için resmi destek henüz yok; OpenHarmony için topluluk fork'u var.
- [ ] İdare ile karar: Harmony desteği şu an gerekli mi, gelecekte mi? Karar dokümante edilmeli.

---

### 64. 🟢 Secure SDLC Süreç Dokümanı (§10.1.3)
- [ ] Şartname: "Güvenli yazılım geliştirme yaşam döngüsü (Secure SDLC) prensipleri uygulanacaktır."
- [ ] Dokümante edilmeli: code review checklist, SAST (örn. semgrep), DAST, dependency scanning (Snyk/Dependabot).
- [ ] Secret scanning (örn. gitleaks) CI'a eklenmiş mi kontrol edilmeli.
- [ ] OWASP Mobile Top 10 self-assessment yapılmalı.

---

## 🆕 GÖZDEN KAÇAN ŞARTNAME MADDELERİ — 29 Mayıs 2026 (önceki TODO'da hiç yoktu)

### 65. ✅ İçerik Sıralama (Sorting) Seçenekleri (§6.4.5, §6.5) — TAMAMLANDI (30 May)
- [x] **Ortak widget:** `lib/core/widgets/sort_menu_button.dart` — generic `SortMenuButton<T>` (PopupMenu, seçili modda ✓, "Sırala" etiketi); widgets barrel'a eklendi. Dört ekranda da kullanılıyor (DRY).
- [x] **Places:** `PlaceSortMode` (recommended / name / popularity / nearest). Yakınlık = anlık haversine (OSRM-bağımsız, izin yoksa isim sırasına düşer); popülerlik = `visitCount↓` sonra `rating↓`. Sıralama arama olsun olmasın `_applyFilters → _sortPlaces` ile her zaman uygulanıyor.
- [x] **Events:** `EventSortMode` (date / name / popularity), varsayılan **tarihe göre** (yakın→uzak; `parsedStartDate`). `setSortMode` görüntülenen `items`'i yeniden sıralar → server-arama sonuçları için de doğru.
- [x] **Routes:** `RouteSortMode` (name / stops / points) — presentation modelinde mesafe/süre serbest metin olduğundan sayısal `stops`/`points` kullanıldı. `clearSearch` artık `_filterRoutes` üzerinden sıralı.
- [x] **Recipes:** `RecipeSortMode` (recommended / name / rating / duration), yalnız "Tarifler" sekmesinde (gastronomy hariç).
- [x] **Doğrulama:** Tüm provider'lar iki-adımlı setSortMode (state.sortMode önce yazılır, sonra yeniden hesaplanır). Tam `flutter analyze` → 0 sorun.
- [ ] (Opsiyonel) Places floating (scroll) header'a da sıralama butonu — şu an yalnız ana header'da.

---

### 66. 🟢 Kurumsal Kimlik Uyumu (§5.2.2, §12.2.1)
- [ ] Şartname: "Görsel tasarım, Samsun Büyükşehir Belediyesi **kurumsal kimliği** ile uyumlu olacaktır"; mağaza görselleri de kurumsal kimliğe uygun olacak.
- [ ] **Mevcut Durum:** Tema/renk paleti (`app_theme.dart`, `design_tokens.dart`) var; SBB logo/renk/font kurumsal kimlik kılavuzuyla **resmi uyum doğrulaması** İdare ile yapılmalı.
- [ ] App icon, splash, mağaza görselleri kurumsal kimliğe göre onaylanmalı (#24 ile bağlantılı).

---

### 67. 🟢 Multimedya İçerik Sunumu — Video/Ses (§6.2.1)
- [ ] Şartname: "Şehre ait tanıtım içerikleri **metin, görsel ve multimedya** formatlarında sunulacaktır."
- [ ] **Doğrulanmalı:** İçerik detay ekranlarında (yer/etkinlik/kültür) **video oynatıcı** ve **sesli anlatım** desteği var mı? AR tarafında audio/video action tipleri tanımlı (`ar_point.dart`) ama normal içerik detayında video/audio player varlığı kontrol edilmeli.
- [ ] Eksikse galeri + video player (chewie/video_player) eklenmeli.

---

### 68. 🟢 OTA İçerik Güncelleme — Mağazasız (§5.3.2, §5.3.3, §8.3.4)
- [ ] Şartname: "İçerik güncellemeleri için uygulamanın **yeniden mağazaya yüklenmesi gerekmeyecek**"; "güncellenen içerikler kullanıcılara **en kısa sürede** yansıtılacak."
- [ ] **Mevcut Durum:** İçerik API'den çekiliyor (✓ mağaza gerektirmiyor). Ancak **cache invalidation / anlık yansıma** stratejisi (ör. pull-to-refresh + TTL + push ile "içerik güncellendi" tetikleme) net dokümante edilmeli.
- [ ] Bu madde teknik olarak karşılanıyor ama "en kısa sürede yansıma" SLA'sı tanımlanmalı.

---

### 69. ℹ️ AR İçerik Üretimi — KAPSAM DIŞI (§6.8.6) — BİLGİ NOTU
- [x] Şartname §6.8.6 **açıkça belirtiyor:** 3B model, animasyon, video gibi AR içeriklerinin **üretimi bu iş kapsamında DEĞİL**. Yüklenici yalnızca bu içerikleri **görüntüleyen/entegre eden altyapıyı** sağlar.
- [x] **Sonuç:** AR maddelerinde (14, 15, 51, 52, 53) 3D içerik üretimi beklenmemeli — yalnızca İdare'nin sağlayacağı içeriklerle uyumlu oynatma/entegrasyon altyapısı yeterli. Bu zaten mevcut (`ar_viewer_screen`, `model_viewer_plus`, action tipleri).
- [ ] Sözleşme/teslim aşamasında bu kapsam sınırı net yazılmalı (yanlış beklenti önlemi).

---

## 📊 ÖZET TABLO

| Öncelik | # | Madde | Şartname | Durum |
|---------|---|-------|----------|-------|
| ✅ | 1 | ~~Onboarding akışı~~ | §6.3.5 | **Tamamlandı** |
| ✅ | 2 | ~~Gezi planlama / itinerary~~ | §6.5.2 | **Tamamlandı** (PR#6+#7 uçtan uca) |
| ✅ | 3 | ~~Favoriler ekranı~~ | §6.5.1 | **Tamamlandı** |
| ✋ | 4 | ~~Kültür sayfası router kaydı~~ | §6.2 | **Yapılmayacak** — kültür, events üzerinden |
| ✅ | 5 | ~~Analitik / davranış izleme~~ | §6.3.6 | **Tamamlandı** (PR#4) |
| ✅ | 6 | ~~Harita ısı haritası~~ | §6.5.3 | **Tamamlandı** (B4) |
| ✅ | 7 | ~~Akıllı öneri / kişiselleştirme~~ | §6.4 | **Tamamlandı** (PR#5) |
| ✅ | 8 | ~~Geofence tekrar engeli~~ | §7.3.5 | **Tamamlandı** |
| ✅ | 9 | ~~Bildirim tercihleri (4 toggle)~~ | §7.4.2 | **Tamamlandı** (PR#3) |
| ✅ | 10 | ~~Offline içerik önbellekleme~~ | §5.1.2 | **Tamamlandı** (kalıcı GET cache + stale-on-error) |
| 🟢 Düşük | 11 | Çoklu dil (dinamik içerik) | §6.7 | **Mobil hazır** (Accept-Language+lang param), backend bekliyor |
| ✅ | 12 | ~~Tema kalıcılığı~~ | §5.2.4 | **Tamamlandı** |
| 🟡 Orta | 13 | QR — admin panel entegrasyonu | §6.8.2 | Kısmi |
| 🟡 Orta | 14 | AR — admin panel (test modu) | §6.8.3.8 | Kısmi |
| 🟡 Orta | 15 | AR — sensör hataları / fallback | §6.8.3.10 | **Kısmi** (kamera izni ✅, model hatası ✅, lokasyon-bazlı AR bekliyor) |
| ✅ | 16 | ~~Chatbot / akıllı asistan~~ | §6.9 | **Tamamlandı** (29 May doğrulandı; admin bayrağı backend) |
| 🟢 Düşük | 17 | Web tabanlı kayıt doğrulama | §6.3.1 | Doğrulanmalı |
| ✅ | 18 | ~~API versiyonlama~~ | §9.2.3 | **Tamamlandı** |
| 🟢 Düşük | 19 | API dokümantasyonu | §9.8 | Eksik |
| 🟢 Düşük | 20 | Performans / yük testleri | §15.1 | Eksik |
| 🟢 Düşük | 21 | AR yüklenme süresi testi | §15.2 | Eksik |
| 🟢 Düşük | 22 | AR batarya tüketimi testi | §15.3 | Eksik |
| 🟢 Düşük | 23 | Beta / UAT / SAT süreçleri | §15.4 | Eksik |
| 🟢 Düşük | 24 | Mağaza yayın hazırlıkları | §12 | Eksik |
| ✅ | 25 | ~~Tersine mühendislik koruması~~ | §5.5.3 | **Büyük ölçüde tamam** (R8+obfuscate+log+root); CI kaldı |
| 🟢 Düşük | 26 | KVKK — açık rıza ekranları | §14.2 | Eksik |
| 🟢 Düşük | 27 | Admin panel log/denetim | §8.7 | Doğrulanmalı |
| 🟢 Düşük | 28 | Kiosk↔mobil içerik uyumu | §3 | Doğrulanmalı |
| ✅ | 29 | ~~Arama ve filtreleme~~ | §6.6 | **Tamamlandı** |
| 🆕 Düşük | 30 | Etkinlik otomatik pasife alma | §6.5.4 | Doğrulanmalı |
| ✅ | 31 | ~~Navigasyon / yönlendirme~~ | §6.3.2 | **Karşılanıyor** (Google Maps handoff + OSRM in-app) |
| 🟢 Düşük | 32 | Veri güvenliği (SSL/şifreleme) | §10.3 | **Kısmen hazır** (HTTPS + secure_storage token) |
| 🆕 Düşük | 33 | API anormal kullanım tespiti | §10.5 | Doğrulanmalı |
| 🆕 Orta | 34 | Test ve kalite güvencesi | §11 | Eksik |
| 🆕 Orta | 35 | Bakım, destek ve SLA | §13 | Eksik |
| 🆕 Düşük | 36 | Dokümantasyon / eğitim | §12.4 | Eksik |
| 🆕 Düşük | 37 | Üçüncü taraf KVKK uyumu | §14.5 | Doğrulanmalı |
| 🆕 Düşük | 38 | Veri saklama/silme mekanizması | §10.7 | Eksik |
| 🆕 Düşük | 39 | Bildirim durumu izleme | §9.6 | Doğrulanmalı |
| 🆕 Düşük | 40 | Panel rol bazlı yetkilendirme | §8.2 | Doğrulanmalı |
| ✅ | 41 | ~~Hesap silme / KVKK veri talebi~~ | §14.4.2 | **Tamamlandı** (soft-delete+restore; 29 May doğrulandı) |
| ✅ | 42 | ~~Aydınlatma + açık rıza UI~~ | §10.6.3 | **Tamamlandı** (İdare metin onayı bekliyor) |
| ⚪ Kapsam dışı | 43 | Hedefli bildirim segment | §7.2.2 | **OneSignal paneli** (İdare kararı) |
| ⚪ Kapsam dışı | 44 | Zamanlanmış bildirim | §7.2.3 | **OneSignal paneli** (İdare kararı) |
| 🟡 Orta | 45 | Kampanya modülü | §6.3.2 | **Kısmi** (mobil ✓, admin ?) |
| 🟡 Orta | 46 | Hotfix / acil güncelleme süreci | §12.1.7 | Eksik (süreç) |
| 🟡 Orta | 47 | Admin parola politikası + 2FA | §8.8.2 | Doğrulanmalı |
| 🟡 Orta | 48 | Bildirim API güvenliği | §7.6.3 | Doğrulanmalı |
| 🟡 Orta | 49 | IP kısıtlaması + erişim log | §9.3.4 | Eksik |
| 🟢 Düşük | 50 | Reklam yasağı audit | §5.1.3 | Doğrulanmalı |
| ✅ | 51 | ~~AR POI çakışma/max limit/priority~~ | §6.8.3.6 | **Tamamlandı** (max limit + priority sort + çakışma) |
| 🟡 Orta | 52 | AR altitude desteği | §6.8.3.2 | **Modelde var, matching KULLANMIYOR** |
| 🟡 Orta | 53 | AR — proaktif prefetch | §6.8.3.9 | Kısmi |
| 🟢 Düşük | 54 | AR — online-only uyarısı | §6.8.5 | Eksik |
| ✅ | 55 | ~~Chatbot KVKK + log politikası~~ | §6.9.6 | **Mobil tamam** (cihazda saklama+retention+temizle) |
| 🟢 Düşük | 56 | Çoklu dil — diller netleştir | §6.7.1 | **İdare ile karar** |
| 🟢 Düşük | 57 | Veri bütünlüğü tedbirleri | §10.3.4 | Doğrulanmalı |
| 🟢 Düşük | 58 | Yetkisiz giriş loglama | §8.8.3 | Doğrulanmalı |
| 🟢 Düşük | 59 | Schema tutarlılık doğrulama | §9.4.3 | Eksik (CI) |
| 🟢 Düşük | 60 | Mağaza politika takibi | §13.5.3 | Eksik (süreç) |
| 🟢 Düşük | 61 | 2-3 adım navigasyon audit | §6.3.3 | Eksik (UX) |
| 🟢 Düşük | 62 | Periyodik içerik güncelleme | §6.3.4 | Eksik (operasyon) |
| 🟢 Düşük | 63 | Harmony OS değerlendirme | §5.1.2 | **İdare ile karar** |
| 🟢 Düşük | 64 | Secure SDLC dokümanı | §10.1.3 | Eksik (süreç) |
| 🟡 Orta | 65 | İçerik sıralama (sorting) seçenekleri | §6.4.5 | **Yeni — açık** |
| 🟢 Düşük | 66 | Kurumsal kimlik uyumu | §5.2.2 | **Yeni — İdare onayı** |
| 🟢 Düşük | 67 | Multimedya (video/ses) içerik | §6.2.1 | **Yeni — doğrulanmalı** |
| 🟢 Düşük | 68 | OTA içerik güncelleme | §5.3.2 | **Yeni — büyük ölçüde karşılanıyor** |
| ℹ️ | 69 | AR içerik üretimi KAPSAM DIŞI | §6.8.6 | **Bilgi notu** |

---

## 📈 İSTATİSTİKLER (29 Mayıs 2026 güncel)

| Durum | Adet |
|-------|------|
| ✅ Tamamlanmış | 21 |
| 🟡 Kısmi | 11 |
| 🔴 Eksik | 15 |
| ❓ Doğrulanmalı | 14 |
| ℹ️ Bilgi notu | 1 |
| **Toplam** | **69** |

> Not: 29 Mayıs doğrulamasında kod ile bire bir kontrol sonucu #16 (chatbot), #41 (hesap silme), #31 (navigasyon), #55 (chatbot KVKK) "Eksik/Kısmi"den "Tamamlandı"ya alındı; #51 (AR POI limit) ve #52 (altitude kullanımı) ise yeniden "açık" olarak işaretlendi. 5 yeni gözden kaçan madde (#65–#69) eklendi.

---

## 🚦 ÖNERİLEN YOL HARİTASI — Buradan Devam

Şartnamenin kalanı kritiklik + iş yapma yeri (mobil/backend/operasyon/İdare) açısından gruplandı.

### 🔥 Sprint 1 — Yayın Önceliği (mobil tarafı)
> **NOT (29 May):** #41 Hesap Silme **tamamlandı** — Sprint 1'den çıkarıldı. Geriye iki gerçek açık kaldı:

1. **#42 Aydınlatma + Açık Rıza UI** — *Hâlâ gerçekten eksik.* Onboarding'in son sayfasına/kayıt formuna KVKK aydınlatma metni + açık rıza checkbox. Profile altına "Yasal" alt menüsü (Aydınlatma, Gizlilik Politikası, Kullanım Koşulları). İzin (konum/kamera/bildirim) öncesi rationale ekranı. İdare'den metin onayı paralel istenmeli. **Tahmini: 2 gün mobil + İdare metin onayı.** **(KVKK denetim engeli)**
2. ~~**#4 Culture route**~~ — **Yapılmayacak** (29 May kararı): kültür içeriği events üzerinden.
3. **#51 AR POI max limit + priority** — `ar_geo_provider`/camera overlay'de görünür POI sayısı sınırlandırılmalı ve `priority` alanı sıralamaya katılmalı (§6.8.3.6). **Tahmini: 0.5 gün.**

### ⚙️ Sprint 2 — Backend / Admin Koordinasyonu (2-3 hafta, backend ekibiyle)
4. **#43 Hedefli bildirim segmentasyon** — Admin paneli UI + backend hedefleme servisi.
5. **#44 Zamanlanmış bildirim scheduler** — `scheduled_notifications` tablo + cron job.
6. **#45 Kampanya admin tarafı** — Mevcut mobil tarafı doğrulanmalı, admin UI varlığı kontrol edilmeli.
7. **#39, #58, #49 Admin loglama ve izleme** — Audit trail + yetkisiz giriş logları.

### 🛡️ Sprint 3 — Güvenlik / Uyum (1-2 hafta)
8. **#47 Admin parola politikası + 2FA**
9. **#48 Bildirim API güvenliği audit**
10. **#64 Secure SDLC dokümanı**
11. **#25 ProGuard/R8 + iOS code obfuscation** (TODO'da §10.4.1, halen kısmi)

### 🤖 Sprint 4 — Chatbot Feature (3-4 hafta)
12. **#16 Chatbot modülü** — Tek başına büyük bir feature. Mimari kararlar (intent matching, embedding search, response template) önden netleştirilmeli. #55 KVKK boyutu bu sprintin içinde.

### 🧪 Sprint 5 — Test ve Kalite (paralel olarak yürür)
13. **#20, #21, #22 Performans / AR yük testleri**
14. **#23 UAT/SAT plan + raporlama**
15. **#19 OpenAPI/Swagger dokümantasyonu**

### 📋 İdare ile Netleştirilmesi Gereken Kararlar
Bunlar Sprint 1 paralelinde sorulmalı (cevap beklenirken kod yazılabilir):

- **#56 Hangi diller?** (sadece TR/EN mi, Rus/Arap turist için de mi?)
- **#63 Harmony OS gerekli mi?**
- **#42 metinleri** — Aydınlatma + Gizlilik Politikası + Kullanım Koşulları
- **#28 Kiosk içerik bütünlüğü** doğrulanması için kiosk uygulamasına erişim
- **#62 İçerik takvimi** — Aylık güncelleme kim sağlayacak?

### 🟢 Düşük Öncelikli / Operasyonel (yayın sonrası)
- #61 (UX audit), #60 (mağaza politika takibi), #57 (veri bütünlüğü), #50 (reklam audit)
- #36 (dokümantasyon), #35 (SLA dokümantasyon), #24 (mağaza yayın hazırlığı)

---

## 🎯 ŞU AN NEREDEYİZ — Özet

**Çok iyi durumda (29 May doğrulandı):**
- Mobil feature'ların büyük çoğunluğu hazır: onboarding, itinerary, favorites, analytics, discovery, geofence, theme, AR Phase 1+2, search, heatmap, campaigns (mobil), **chatbot (tam), hesap silme (soft-delete+restore), navigasyon (Maps handoff+OSRM)**.
- Backend A1-A5 + mobile_integ 7 PR canlı.
- AR altyapısı (radar + camera overlay + readiness gate) sağlam.
- Çoklu dil mekanizması (Accept-Language + lang param) hazır — backend'in dile göre içerik döndürmesi bekleniyor.

**Yakın zamanda kapatılanlar (29 Mayıs):**
- ✅ **#42 KVKK Aydınlatma/Açık Rıza UI** — `legal` feature'ı + kayıt rıza checkbox + Profile "Yasal" menüsü. (İdare metin onayı bekliyor.)
- ✅ **#51 AR POI max limit + priority + çakışma** — §6.8.3.6 beş maddesi karşılandı.
- ✅ **#25 Tersine mühendislik** — R8 + Dart obfuscate scriptleri + log susturma.
- ✅ **#10 Offline içerik cache** — kalıcı GET cache + stale-on-error interceptor (`ApiClient`).

**Pure-mobil kritik kalemlerin tamamı kapandı (29 May):** #42 (KVKK + pre-permission), #51, #25, #10, #16, #41, #31.
Kalanlar ağırlıkla **backend / İdare onayı / operasyon** tarafında: test (#20-23, #34), dokümantasyon (#19, #36), admin panel (#43/#44/#45/#39/#40), dile göre içerik (#11 backend), KVKK metin onayı (#42 İdare).

> ~~#4 Culture route~~ → **Yapılmayacak** (kültür içeriği events üzerinden çözülecek).

**Backend ekibiyle koordinasyon gerektiren maddeler:**
- #43 hedefli bildirim, #44 zamanlanmış bildirim, #45 kampanya admin, #39 bildirim izleme, #16 chatbot içerik bayrağı (§6.9.4.2), #11 dile göre içerik alanları.

**İdare ile karar gerektiren maddeler:**
- #56 diller, #63 Harmony, #42 metinler (onay), #66 kurumsal kimlik onayı, #28 kiosk içerik erişimi.

**Önerim:** #42, #51, #25 kapandı. Sıradaki büyük mobil iş **#10 offline içerik cache** (mimari, ayrı sprint). Paralelinde İdare'ye metin/dil/kimlik onayları sorulmalı; backend koordinasyon maddeleri (#43/#44/#45/#39/#11) backend ekibiyle.
