import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api.dart';
import '../../data/repositories/geofence_zones_repository.dart';
import '../../l10n/l10n.dart';
import '../routing/deep_link_validator.dart';
import 'analytics_events.dart';
import 'analytics_service.dart';
import 'background_geofence_worker.dart';
import 'log_service.dart';
import 'native_geofence_service.dart';

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  GEOFENCE SERVICE - Zero-Cost Hybrid Geofencing                         ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  OneSignal geofence ÜCRETLİ olduğu için kullanılmaz.                    ║
// ║  Geofencing tamamen LOCAL olarak çalışır:                                ║
// ║  • Geolocator ile konum alınır                                          ║
// ║  • Mesafe hesaplanır (Geolocator.distanceBetween)                       ║
// ║  • Enter/Exit + histerezis: yalnız DISARIDAN girişte bildirir           ║
// ║  • Min süre güvenlik ağı (hızlı çıkış-giriş spam'ine karşı)              ║
// ║  • FlutterLocalNotifications ile bildirim gösterilir                     ║
// ║  • Lifecycle-based: Sadece app açılınca/resume olunca kontrol            ║
// ╚══════════════════════════════════════════════════════════════════════════╝

// ═══════════════════════════════════════════════════════════════════════════════
// GEOFENCE BİLDİRİM METİNLERİ (dil bazlı, BuildContext'siz)
// ═══════════════════════════════════════════════════════════════════════════════

/// Geofence bildirim metinleri. Hem foreground servis hem WorkManager arka plan
/// isolate'inden çağrılır; bu bağlamlarda `BuildContext`/`AppLocalizations`
/// olmadığı için dil bazlı küçük bir sözlük tutulur. Karşılıkları ARB'deki
/// `geofenceNotif*` anahtarlarıyla eşdeğer kalmalıdır.
class GeofenceNotificationStrings {
  GeofenceNotificationStrings._();

  static bool _isEn(String lang) => lang.toLowerCase().startsWith('en');

  /// Android bildirim kanalı adı (sistem ayarlarında görünür).
  static String channelName(String lang) =>
      _isEn(lang) ? 'Location Alerts' : 'Konum Bildirimleri';

  static String channelDescription(String lang) => _isEn(lang)
      ? 'Notifications about districts near you'
      : 'Yakınlarınızdaki bölgeler hakkında bildirimler';

  /// Bildirim başlığı: "{name}'a Hoş Geldiniz" / "Welcome to {name}".
  static String welcomeTitle(String lang, String name) =>
      _isEn(lang) ? 'Welcome to $name' : "$name'a Hoş Geldiniz";

  /// Genişletilmiş (big picture) başlık: sınır mesajı.
  static String boundaryTitle(String lang, String name) =>
      _isEn(lang) ? "You're within $name" : '$name Sınırlarındasınız';
}

// ═══════════════════════════════════════════════════════════════════════════════
// GEOFENCE ZONE MODEL
// ═══════════════════════════════════════════════════════════════════════════════

/// Geofence bölgesi tanımı.
///
/// `mobile_pending_changes.md` B2: backend artık zone listesini JSON olarak
/// döndürüyor (`message_tr` + `message_en`). Eski hardcoded liste ile
/// geriye uyumluluk için:
///   * [message] zorunlu (TR / varsayılan dil)
///   * [messageEn] opsiyonel (backend dönerse kullanılır)
///   * [deeplinkId] opsiyonel — backend zone'larında null
@immutable
class GeofenceZone {
  /// Benzersiz id (slug ya da numerik string)
  final String id;

  /// Görüntülenecek isim
  final String name;

  /// Enlem
  final double lat;

  /// Boylam
  final double lng;

  /// Yarıçap (metre cinsinden)
  final double radius;

  /// Birincil bildirim mesajı (genellikle TR).
  final String message;

  /// İkincil dil (genellikle EN). [messageFor] tarafından seçilir.
  final String? messageEn;

  /// Bildirim payload'ına yerleştirilecek deep-link id. Hardcoded
  /// (district) zone'lar için doludur; backend zone'larında null olabilir.
  final String? deeplinkId;

  /// Backend `active=false` döndürürse istemci tarafında gizlemek için.
  final bool active;

  const GeofenceZone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.message,
    this.messageEn,
    this.deeplinkId,
    this.active = true,
  });

  /// Verilen dil koduna göre uygun mesaj.
  String messageFor(String langCode) {
    final lc = langCode.toLowerCase();
    if (lc.startsWith('en') && (messageEn?.isNotEmpty ?? false)) {
      return messageEn!;
    }
    return message;
  }

  /// Backend response → GeofenceZone.
  /// Beklenen şema (`mobile_pending_changes.md` B2):
  /// ```json
  /// { "id":"1", "name":"...", "lat":41.28, "lng":36.33,
  ///   "radius_m":200, "message_tr":"...", "message_en":"...",
  ///   "active":true }
  /// ```
  factory GeofenceZone.fromJson(Map<String, dynamic> json) {
    return GeofenceZone(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      radius: (json['radius_m'] as num?)?.toDouble() ??
          (json['radius'] as num?)?.toDouble() ??
          0.0,
      message: (json['message_tr'] ?? json['message'] ?? '').toString(),
      messageEn: json['message_en']?.toString(),
      // Backend opsiyonel olarak deeplink hint verirse yakala.
      deeplinkId: (json['deeplink_id'] ?? json['target_id'])?.toString(),
      active: json['active'] as bool? ?? true,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HARDCODED ZONES – Samsun İlçeleri
// ═══════════════════════════════════════════════════════════════════════════════

/// Samsun ilçeleri geofence bölgeleri
/// Bu liste backend hazır olduğunda API'den çekilebilir.
class SamsunGeofenceZones {
  SamsunGeofenceZones._();

  static const List<GeofenceZone> zones = [
    GeofenceZone(
      id: 'kavak',
      name: 'Kavak',
      lat: 41.075,
      lng: 36.039,
      radius: 3000,
      message: "Kavak'a Hoş Geldiniz! Meşhur Kaz Tiridi'ni denediniz mi?",
      messageEn: "Welcome to Kavak! Have you tried the famous Goose Tirit?",
      deeplinkId: 'kavak',
    ),
    GeofenceZone(
      id: 'atakum',
      name: 'Atakum',
      lat: 41.325,
      lng: 36.335,
      radius: 10000,
      message: "Atakum Sahili'nde yürüyüş zamanı!",
      messageEn: "Time for a walk along Atakum Beach!",
      deeplinkId: 'atakum',
    ),
    GeofenceZone(
      id: 'ilkadim',
      name: 'İlkadım',
      lat: 41.2867,
      lng: 36.3361,
      radius: 3000,
      message: "Samsun'un kalbi İlkadım'a hoş geldiniz! Tarihi merkezleri keşfedin.",
      messageEn: "Welcome to İlkadım, the heart of Samsun! Explore its historic centers.",
      deeplinkId: 'ilkadim',
    ),
    GeofenceZone(
      id: 'canik',
      name: 'Canik',
      lat: 41.2589,
      lng: 36.4250,
      radius: 3000,
      message: "Canik'e hoş geldiniz! Amazonlar'ın şehrinde doğa ve tarih bir arada.",
      messageEn: "Welcome to Canik! Nature and history together in the city of the Amazons.",
      deeplinkId: 'canik',
    ),
    GeofenceZone(
      id: 'tekkekoy',
      name: 'Tekkeköy',
      lat: 41.2156,
      lng: 36.4731,
      radius: 3000,
      message: "Tekkeköy'e hoş geldiniz! Antik kentlerin izlerini sürmek için harika bir yer.",
      messageEn: "Welcome to Tekkeköy! A great place to trace the remains of ancient cities.",
      deeplinkId: 'tekkekoy',
    ),
    GeofenceZone(
      id: 'bafra',
      name: 'Bafra',
      lat: 41.5680,
      lng: 35.9060,
      radius: 5000,
      message: "Bafra'ya hoş geldiniz! Kızılırmak Deltası'nın eşsiz kuş cennetini keşfedin.",
      messageEn: "Welcome to Bafra! Discover the unique bird paradise of the Kızılırmak Delta.",
      deeplinkId: 'bafra',
    ),
    GeofenceZone(
      id: 'carsamba',
      name: 'Çarşamba',
      lat: 41.2017,
      lng: 36.7283,
      radius: 4000,
      message: "Çarşamba'ya hoş geldiniz! Yeşilırmak Ovası'nın bereketli topraklarındasınız.",
      messageEn: "Welcome to Çarşamba! You're in the fertile lands of the Yeşilırmak Plain.",
      deeplinkId: 'carsamba',
    ),
    GeofenceZone(
      id: 'terme',
      name: 'Terme',
      lat: 41.2078,
      lng: 36.9750,
      radius: 3000,
      message: "Terme'ye hoş geldiniz! Amazonların anavatanında tarih yolculuğuna çıkın.",
      messageEn: "Welcome to Terme! Take a journey through history in the homeland of the Amazons.",
      deeplinkId: 'terme',
    ),
    GeofenceZone(
      id: 'havza',
      name: 'Havza',
      lat: 40.9700,
      lng: 35.6817,
      radius: 3000,
      message: "Havza'ya hoş geldiniz! Şifalı kaplıcalarıyla ünlü Havza sizi bekliyor.",
      messageEn: "Welcome to Havza! Famed for its healing hot springs, Havza awaits you.",
      deeplinkId: 'havza',
    ),
    GeofenceZone(
      id: 'vezirkopru',
      name: 'Vezirköprü',
      lat: 41.1378,
      lng: 35.4653,
      radius: 3000,
      message: "Vezirköprü'ye hoş geldiniz! Osmanlı köprülerinin izinde tarih yolculuğu.",
      messageEn: "Welcome to Vezirköprü! A journey through history along Ottoman bridges.",
      deeplinkId: 'vezirkopru',
    ),
    GeofenceZone(
      id: 'ladik',
      name: 'Ladik',
      lat: 40.9342,
      lng: 35.9000,
      radius: 3000,
      message: "Ladik'e hoş geldiniz! Ladik Gölü'nün muhteşem manzarasını kaçırmayın.",
      messageEn: "Welcome to Ladik! Don't miss the magnificent view of Lake Ladik.",
      deeplinkId: 'ladik',
    ),
  ];

  /// ID'ye göre bölge bul
  static GeofenceZone? findById(String id) {
    try {
      return zones.firstWhere((z) => z.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GEOFENCE STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Geofence servisi state'i
@immutable
class GeofenceState {
  /// Servis etkin mi (kullanıcı izin verdi mi)
  final bool isEnabled;

  /// Son kontrol zamanı
  final DateTime? lastCheckTime;

  /// Şu an içinde olunan bölge (varsa)
  final String? currentZoneId;

  /// Son kontrol sonucu mesajı (debug amaçlı)
  final String? lastCheckResult;

  const GeofenceState({
    this.isEnabled = false,
    this.lastCheckTime,
    this.currentZoneId,
    this.lastCheckResult,
  });

  GeofenceState copyWith({
    bool? isEnabled,
    DateTime? lastCheckTime,
    String? currentZoneId,
    String? lastCheckResult,
  }) {
    return GeofenceState(
      isEnabled: isEnabled ?? this.isEnabled,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      currentZoneId: currentZoneId ?? this.currentZoneId,
      lastCheckResult: lastCheckResult ?? this.lastCheckResult,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GEOFENCE EVENT CALLBACK
// ═══════════════════════════════════════════════════════════════════════════════

/// Geofence olayı tetiklendiğinde çağrılacak callback
/// [zone] → tetiklenen bölge, [payload] → deep link data
typedef GeofenceTriggeredCallback = void Function(
  GeofenceZone zone,
  Map<String, dynamic> payload,
);

// ═══════════════════════════════════════════════════════════════════════════════
// GEOFENCE SERVICE (THE CORE)
// ═══════════════════════════════════════════════════════════════════════════════

/// Min yeniden-bildirim aralığı (saat): aynı bölgeden ÇIKIP yeniden girişte
/// en az bu kadar süre geçmeden tekrar bildirilmez. Asıl spam'i enter/exit
/// (histerezis) önler; bu yalnızca hızlı çıkış-giriş için güvenlik ağıdır.
const int _kCooldownHours = 6;

/// SharedPreferences key prefix — son bildirim zamanı
const String _kCooldownKeyPrefix = 'geofence_last_trigger_';

/// SharedPreferences key prefix — bölge başına "içeride mi" durumu (enter/exit).
const String _kInsideKeyPrefix = 'geofence_inside_';

/// Notification channel
const String _kNotificationChannelId = 'location_alerts';
const String _kNotificationChannelName = 'Konum Bildirimleri';
const String _kNotificationChannelDesc = 'Yakınlarınızdaki bölgeler hakkında bildirimler';

/// GeofenceService - Lifecycle tabanlı, sıfır maliyetli geofencing
///
/// Kullanım:
/// 1. `enable()` ile servisi etkinleştir (konum izni alınır)
/// 2. `checkLocation()` ile mevcut konumu kontrol et
/// 3. `checkLocation()` otomatik olarak app resume'da çağrılır
class GeofenceNotifier extends AsyncNotifier<GeofenceState> {
  /// Local notifications plugin instance
  late final FlutterLocalNotificationsPlugin _localNotifications;

  /// İsteğe bağlı: Foreground'da dialog göstermek için callback
  GeofenceTriggeredCallback? _onGeofenceTriggered;

  /// Son fetch edilmiş zone listesi (notification tap çözümlemesi için).
  List<GeofenceZone> _activeZones = const [];

  // SharedPreferences Key (background_geofence_worker.dart ile uyumlu olmalı)
  static const String _kEnabledKey = 'geofence_bg_enabled';

  /// Helper: güvenli state güncelleme (AsyncNotifier uyumlu).
  /// Eğer state henüz yüklenmemişse (AsyncLoading/AsyncError) güncelleme yapılmaz.
  void _updateState(GeofenceState Function(GeofenceState prev) updater) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(updater(current));
    }
  }

  /// Helper: mevcut GeofenceState'e güvenli erişim (varsayılan: const GeofenceState())
  GeofenceState get _currentState => state.value ?? const GeofenceState();

  /// Servis bağlamında (BuildContext yok) aktif dile göre yerelleştirme.
  AppLocalizations get _l10n => lookupAppLocalizations(
      Locale(ref.read(apiClientProvider).languageCode));

  /// Önce son fetch edilmiş listede ara; bulunmazsa hardcoded fallback.
  GeofenceZone? _findZoneById(String id) {
    for (final z in _activeZones) {
      if (z.id == id) return z;
    }
    return SamsunGeofenceZones.findById(id);
  }

  @override
  Future<GeofenceState> build() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    _initializeNotifications();
    
    // State'i SharedPreferences'tan yükle (artık await ile — race condition yok)
    return _loadPersistedState();
  }

  /// Kaydedilmiş ayarları yükle ve başlangıç state'ini döndür
  Future<GeofenceState> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_kEnabledKey) ?? false;
    
    var initialState = const GeofenceState();
    
    if (isEnabled) {
      initialState = initialState.copyWith(isEnabled: true);
      LogService.d('Geofence state restored: ENABLED', tag: 'Geofence');
      // Hemen bir kontrol yap — başarısız olsa bile state korunur
      // checkLocation artık state'i build sonrası update eder
      Future.microtask(() async {
        try {
          await checkLocation();
        } catch (e) {
          LogService.w(
            'Startup location check failed (will retry on resume): $e',
            tag: 'Geofence',
          );
        }
      });
    }
    
    return initialState;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Local notifications plugin'ini başlat
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Android notification channel oluştur
    const androidChannel = AndroidNotificationChannel(
      _kNotificationChannelId,
      _kNotificationChannelName,
      description: _kNotificationChannelDesc,
      importance: Importance.high,
      playSound: true,
    );

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(androidChannel);

    // Android 13+ (API 33): sistem bildirim izni runtime'da istenmeli; aksi
    // halde flutter_local_notifications .show() sessizce hiçbir şey göstermez.
    try {
      await androidImpl?.requestNotificationsPermission();
    } catch (e) {
      LogService.w('requestNotificationsPermission failed: $e', tag: 'Geofence');
    }

    LogService.d('Local notifications initialized', tag: 'Geofence');
  }

  /// Local notification'a tıklandığında
  void _onLocalNotificationTap(NotificationResponse response) {
    LogService.i(
      'Local notification tapped, payload: ${response.payload}',
      tag: 'Geofence',
    );

    // Payload'ı parse et ve geofence triggered callback'e ilet.
    // Backend zone'lar deeplinkId döndürmeyebilir → bu durumda payload boş
    // gelir; sadece uygulama açılır, navigate edilmez.
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        final target = data['target']?.toString().trim();
        final rawId = data['id'];
        final zoneId = rawId?.toString().trim();
        if (target == null ||
            zoneId == null ||
            zoneId.isEmpty ||
            !DeepLinkValidator.isGeofenceTargetAllowed(target) ||
            !DeepLinkValidator.isValidRouteSegmentId(zoneId)) {
          return;
        }
        final zone = _findZoneById(zoneId);
        if (zone != null) {
          _onGeofenceTriggered?.call(zone, data);
        }
      } catch (e) {
        LogService.e('Failed to parse notification payload', tag: 'Geofence', error: e);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  /// Geofence triggered callback ayarla
  ///
  /// Bu callback, bir bölgeye girildiğinde hem foreground hem de
  /// notification tap durumunda çağrılır.
  void setOnGeofenceTriggered(GeofenceTriggeredCallback callback) {
    _onGeofenceTriggered = callback;
    LogService.d('Geofence triggered callback set', tag: 'Geofence');
  }

  /// Geofence servisini etkinleştir
  ///
  /// Konum iznini ister ve servisi aktif hale getirir.
  /// Başarılıysa `true`, izin reddedildiyse `false` döner.
  Future<bool> enable() async {
    try {
      LogService.i('Enabling geofence service...', tag: 'Geofence');

      // Konum servisi etkin mi?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        LogService.e('Location services disabled', tag: 'Geofence');
        _updateState((s) => s.copyWith(
          lastCheckResult: _l10n.geoLocationServicesOff,
        ));
        return false;
      }

      // Konum izni var mı?
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          LogService.w('Location permission denied', tag: 'Geofence');
          _updateState((s) => s.copyWith(
            lastCheckResult: _l10n.geoPermissionDenied,
          ));
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        LogService.e('Location permission permanently denied', tag: 'Geofence');
        _updateState((s) => s.copyWith(
          lastCheckResult: _l10n.geoPermissionDeniedForever,
        ));
        return false;
      }

      // SharedPreferences'a kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, true);

      _updateState((s) => s.copyWith(isEnabled: true));
      LogService.s('Geofence service enabled', tag: 'Geofence');

      // Arka plan ("Her zaman") konum izni — native geofencing için ŞART.
      // permission_handler iki platformda da çalışır (Android 11+'da sistem
      // ayarına yönlendirir; iOS'ta always authorization ister).
      // Verilmese bile servis açık kalır; foreground kontrolü yine çalışır.
      try {
        final bg = await ph.Permission.locationAlways.request();
        LogService.i('Background location permission: $bg', tag: 'Geofence');
      } catch (e) {
        LogService.w('Background permission request failed: $e', tag: 'Geofence');
      }

      // Native (event-tabanlı OS) geofencing BİRİNCİL — bölgeye girince app
      // kapalıyken bile anında tetiklenir. Eski WorkManager periyodik görevini
      // (varsa, eski kurulumlardan) iptal et: çift bildirim + pil israfı önle.
      // Not: pref'e dokunmayan iptal kullanılır (stopPeriodicGeofenceCheck
      // `geofence_bg_enabled`'ı false yapardı → etkin durum bozulurdu).
      await cancelLegacyPeriodicGeofenceTask();
      await syncNativeGeofences();

      // İlk konumu kontrol et — başarısız olsa bile enable iptal edilmez
      try {
        await checkLocation();
      } catch (e) {
        LogService.w(
          'Initial location check failed (service still enabled): $e',
          tag: 'Geofence',
        );
        _updateState((s) => s.copyWith(
          lastCheckResult: _l10n.geoLocationNotYet,
        ));
      }

      return true;
    } catch (e, stack) {
      LogService.e(
        'Failed to enable geofence service',
        tag: 'Geofence',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Admin-tanımlı bölgeleri backend'den çekip native OS geofence olarak kaydeder.
  ///
  /// Açılış/resume'de + dil değişiminde + enable'da çağrılır. Admin panelden
  /// bölge eklenince/düzenlenince mobil bu yolla otomatik senkron olur.
  /// Native taraf, app kapalı olsa bile tetiklenince bildirimi kendi gösterir.
  Future<void> syncNativeGeofences() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final lang = apiClient.languageCode;
      final zones = await ref
          .read(geofenceZonesRepositoryProvider)
          .getZones(lang: lang);
      _activeZones = zones;
      await NativeGeofenceService.instance.registerZones(zones, lang);
      LogService.s(
        'Native geofences synced: ${zones.length} zone(s)',
        tag: 'Geofence',
      );
    } catch (e) {
      LogService.w('syncNativeGeofences failed: $e', tag: 'Geofence');
    }
  }

  /// Geofence servisini devre dışı bırak
  Future<void> disable() async {
    // Native OS geofence'leri kaldır + eski WorkManager görevini (varsa) iptal et.
    await NativeGeofenceService.instance.clearZones();
    await stopPeriodicGeofenceCheck();

    // SharedPreferences'a kaydet
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, false);

    // Enter/exit "içeride" durumunu temizle → yeniden açılınca temiz başlangıç
    // (kullanıcı bir bölgedeyken kapatıp tekrar açarsa girişte yeniden bildirilebilir).
    final insideKeys = prefs.getKeys().where((k) => k.startsWith(_kInsideKeyPrefix)).toList();
    for (final k in insideKeys) {
      await prefs.remove(k);
    }

    _updateState((s) => s.copyWith(
      isEnabled: false,
      currentZoneId: null,
      lastCheckResult: _l10n.geoServiceDisabled,
    ));
    LogService.i('Geofence service disabled', tag: 'Geofence');
  }

  /// Mevcut konumu kontrol et ve geofence tetikleme yap
  ///
  /// Bu metod şu durumlarda çağrılır:
  /// 1. Servis ilk etkinleştirildiğinde
  /// 2. AppLifecycleState.resumed olduğunda (app ön plana geldiğinde)
  /// 3. WorkManager tarafından arka planda (~15 dk aralıklarla)
  ///
  /// Her zone için:
  /// - Mesafe hesapla (Geolocator.distanceBetween)
  /// - Zone içindeyse ve 24 saat cooldown geçtiyse → bildirim göster
  Future<void> checkLocation() async {
    if (!_currentState.isEnabled) {
      LogService.d('Geofence check skipped: service disabled', tag: 'Geofence');
      return;
    }

    try {
      LogService.i('Checking location for geofence triggers...', tag: 'Geofence');

      // Önce son bilinen konumu dene (anında, GPS bekleme yok)
      Position? position = await Geolocator.getLastKnownPosition();

      if (position != null) {
        LogService.d('Using last known position (fast path)', tag: 'Geofence');
      } else {
        // Son bilinen konum yoksa GPS'ten al (ilk açılış vb.)
        LogService.d('No cached position, requesting GPS fix...', tag: 'Geofence');
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
      }

      LogService.d(
        '📍 Current position: ${position.latitude.toStringAsFixed(4)}, '
        '${position.longitude.toStringAsFixed(4)}',
        tag: 'Geofence',
      );

      // SharedPreferences'ı al (cooldown kontrolü için)
      final prefs = await SharedPreferences.getInstance();
      String? triggeredZoneId;

      // `mobile_pending_changes.md` B2 — zone listesini backend'den al.
      // Hata durumunda repository hardcoded SamsunGeofenceZones.zones'a
      // fallback eder; davranış kırılmaz.
      final apiClient = ref.read(apiClientProvider);
      final zones = await ref
          .read(geofenceZonesRepositoryProvider)
          .getZones(lang: apiClient.languageCode);
      _activeZones = zones;

      // Tüm bölgeleri kontrol et
      for (final zone in zones) {
        // Mesafe hesapla (metre cinsinden)
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          zone.lat,
          zone.lng,
        );

        LogService.d(
          '  → ${zone.name}: ${distance.toStringAsFixed(0)}m '
          '(radius: ${zone.radius.toStringAsFixed(0)}m) '
          '${distance < zone.radius ? "✅ İÇİNDE" : "❌ DIŞINDA"}',
          tag: 'Geofence',
        );

        // ── Enter/Exit (histerezis) — yalnız DIŞARIDAN içeri GİRİŞTE bildir ──
        final isInside = distance < zone.radius;
        final insideKey = '$_kInsideKeyPrefix${zone.id}';
        final wasInside = prefs.getBool(insideKey) ?? false;
        final exitThreshold = zone.radius + _exitBuffer(zone.radius);

        if (isInside) {
          triggeredZoneId = zone.id;

          // Zaten içerideydi (örn. otelde kalan kullanıcı) → tekrar bildirme.
          if (wasInside) {
            continue;
          }

          // Yeni giriş: içeride olarak işaretle (tekrar tetiklenmesin).
          await prefs.setBool(insideKey, true);

          // Min süre güvenlik ağı (hızlı çıkış-giriş spam'ine karşı).
          if (_isCooldownActive(prefs, zone.id)) {
            LogService.d(
              '  → ${zone.name}: Giriş algılandı ama min süre dolmadı, bildirim atlanıyor',
              tag: 'Geofence',
            );
            continue;
          }

          // TEK BİLDİRİM KAYNAĞI = NATIVE (OS) GEOFENCE.
          // Bu enter'ı native taraf zaten bildiriyor: app kapalıyken anında
          // (Android GeofencingClient / iOS region monitoring) ve Android'de
          // app açılınca register sırasında zaten içerideyse INITIAL_TRIGGER_ENTER
          // ile — her ikisi de 24s native cooldown ile tekilleştirilir.
          // Bu yüzden Dart tarafı burada ARTIK ne sistem bildirimi gösterir ne de
          // hoş-geldin dialog'u açar; yalnız cooldown/state + analitik günceller.
          // (Aksi halde aynı girişte "Hoş Geldiniz" [native] + "Sınırlarındasınız"
          // [Dart] olmak üzere ÇİFT bildirim oluşuyordu.) Manuel "Şimdi kontrol et"
          // testi hâlâ forceCheckAndNotify üzerinden bildirim üretir.
          LogService.s(
            '🚪 GEOFENCE ENTER (state-only; native notifies): '
            '${zone.name} (${distance.toStringAsFixed(0)}m)',
            tag: 'Geofence',
          );

          await _saveCooldownTimestamp(prefs, zone.id);

          // `mobile_pending_changes.md` B2 — geofence_entered analytics event.
          try {
            ref.read(analyticsServiceProvider).track(
              AnalyticsEvents.geofenceEntered,
              properties: {
                'zone_id': zone.id,
                'zone_name': zone.name,
                'distance_m': distance.round(),
              },
            );
          } catch (e) {
            LogService.w('geofence_entered analytics failed: $e', tag: 'Geofence');
          }
        } else if (distance > exitThreshold && wasInside) {
          // Histerezis: yarıçap + tampon DIŞINA çıktı → "dışarıda" işaretle.
          // Kullanıcı yeniden girince tekrar bildirilebilir hale gelir.
          await prefs.setBool(insideKey, false);
          LogService.d(
            '  → ${zone.name}: Bölgeden çıkıldı '
            '(${distance.toStringAsFixed(0)}m > ${exitThreshold.toStringAsFixed(0)}m), yeniden kuruldu',
            tag: 'Geofence',
          );
        }
        // Arada (yarıçap .. yarıçap+tampon): histerezis ölü bölgesi — durum değişmez,
        // sınırda GPS gürültüsüyle flip-flop / spam engellenir.
      }

      final triggeredZone = triggeredZoneId == null
          ? null
          : _findZoneById(triggeredZoneId);
      _updateState((s) => s.copyWith(
        lastCheckTime: DateTime.now(),
        currentZoneId: triggeredZoneId,
        lastCheckResult: triggeredZone != null
            ? _l10n.geoInsideZone(triggeredZone.name)
            : (triggeredZoneId != null
                ? _l10n.geoInsideZone(triggeredZoneId)
                : _l10n.geoNoZone),
      ));
    } catch (e, stack) {
      LogService.e(
        'Failed to check location',
        tag: 'Geofence',
        error: e,
        stackTrace: stack,
      );
      _updateState((s) => s.copyWith(
        lastCheckResult: _l10n.geoLocationFailedWith('$e'),
      ));
    }
  }

  /// Manuel/test: ŞU AN içinde olunan bölge için bildirimi ZORLA gösterir.
  /// Enter/exit ("içeride") ve cooldown atlanır — "Şimdi kontrol et" butonu
  /// bununla, bölgedeyken her zaman gerçek sistem bildirimi üretir. Otomatik
  /// (resume/arka plan) akış [checkLocation] ile production mantığında kalır.
  Future<void> forceCheckAndNotify() async {
    if (!_currentState.isEnabled) return;
    try {
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final apiClient = ref.read(apiClientProvider);
      final zones = await ref
          .read(geofenceZonesRepositoryProvider)
          .getZones(lang: apiClient.languageCode);
      _activeZones = zones;

      GeofenceZone? insideZone;
      for (final zone in zones) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          zone.lat,
          zone.lng,
        );
        if (distance < zone.radius) {
          insideZone = zone;
          break;
        }
      }

      final zone = insideZone;
      if (zone != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('$_kInsideKeyPrefix${zone.id}', true);
        await _saveCooldownTimestamp(prefs, zone.id);
        await _showLocalNotification(zone);
        LogService.s('Force test notification: ${zone.name}', tag: 'Geofence');
        _updateState((s) => s.copyWith(
              lastCheckTime: DateTime.now(),
              currentZoneId: zone.id,
              lastCheckResult: _l10n.geoInsideZone(zone.name),
            ));
      } else {
        _updateState((s) => s.copyWith(
              lastCheckTime: DateTime.now(),
              currentZoneId: null,
              lastCheckResult: _l10n.geoNoZone,
            ));
      }
    } catch (e, stack) {
      LogService.e('Force check failed', tag: 'Geofence', error: e, stackTrace: stack);
      _updateState((s) => s.copyWith(
            lastCheckResult: _l10n.geoLocationFailedWith('$e'),
          ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 24-HOUR COOLDOWN LOGIC
  // ─────────────────────────────────────────────────────────────────────────

  /// Belirli bir bölge için cooldown'un aktif olup olmadığını kontrol et
  bool _isCooldownActive(SharedPreferences prefs, String zoneId) {
    final key = '$_kCooldownKeyPrefix$zoneId';
    final lastTriggerMs = prefs.getInt(key);

    if (lastTriggerMs == null) return false;

    final lastTrigger = DateTime.fromMillisecondsSinceEpoch(lastTriggerMs);
    final elapsed = DateTime.now().difference(lastTrigger);

    return elapsed.inHours < _kCooldownHours;
  }

  /// Cooldown timestamp'ini kaydet
  Future<void> _saveCooldownTimestamp(
    SharedPreferences prefs,
    String zoneId,
  ) async {
    final key = '$_kCooldownKeyPrefix$zoneId';
    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    LogService.d(
      'Cooldown saved for "$zoneId" (next trigger after $_kCooldownHours hours)',
      tag: 'Geofence',
    );
  }

  /// Histerezis çıkış tamponu (metre): bir bölgeden "çıkıldı" sayılması için
  /// yarıçapın ne kadar dışına gidilmesi gerektiği. Profesyonel geofence
  /// pratiği (asimetrik çıkış) + orta GPS doğruluğu (~100m) gözetilerek:
  /// yarıçapın %20'si, en az 150 m, en çok 1000 m.
  double _exitBuffer(double radius) {
    final b = radius * 0.2;
    if (b < 150) return 150;
    if (b > 1000) return 1000;
    return b;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCAL NOTIFICATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Geofence tetiklendiğinde local notification göster
  ///
  /// Premium Big Picture Style kullanır:
  /// - Monochrome alpha-channel status bar icon
  /// - Ocean Teal accent color (brand rengi)
  /// - Büyük resim (genişletilebilir)
  /// - İlçe logosu thumbnail
  /// - LED branding
  /// - Emoji içermeyen temiz metin
  Future<void> _showLocalNotification(GeofenceZone zone) async {
    // Backend zone'larda deeplinkId yoksa payload boş — tap sadece uygulamayı
    // açar, navigate etmez. Eski (hardcoded) zone'larda district_detail tarafı korunur.
    final payload = jsonEncode(<String, dynamic>{
      if (zone.deeplinkId != null) ...{
        'target': 'district_detail',
        'id': zone.deeplinkId,
      },
    });

    // Dil bazlı mesaj — backend `message_en` döndürdüyse aktif dile göre seç.
    final lang = ref.read(apiClientProvider).languageCode;
    final message = zone.messageFor(lang);

    // Genişletilebilir metin stili — görsel gerektirmez (özel drawable'lar
    // pakette yok; eksik kaynak Android'de bildirimi tamamen engelliyordu).
    final styleInformation = BigTextStyleInformation(
      message,
      contentTitle: GeofenceNotificationStrings.boundaryTitle(lang, zone.name),
    );

    // Android bildirim detayları. Small icon MEVCUT bir kaynağa işaret etmeli;
    // aksi halde sistem bildirimi hiç gösterilmez → @mipmap/ic_launcher.
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _kNotificationChannelId,
      _kNotificationChannelName,
      channelDescription: _kNotificationChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      color: const Color(0xFF26A69A), // Ocean Teal — Brand accent
      icon: '@mipmap/ic_launcher',
      styleInformation: styleInformation,
      // NOT: enableLights/ledColor KALDIRILDI — ledOnMs/ledOffMs olmadan
      // PlatformException(invalid_led_details) fırlatıp bildirimi engelliyordu.
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      zone.id.hashCode,
      GeofenceNotificationStrings.welcomeTitle(lang, zone.name),
      message, // Dil bazlı gövde
      notificationDetails,
      payload: payload,
    );

    LogService.s('Local notification shown for: ${zone.name}', tag: 'Geofence');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEBUG UTILITIES
  // ─────────────────────────────────────────────────────────────────────────

  /// Debug: Belirli bir bölgenin cooldown'unu sıfırla
  Future<void> debugResetCooldown(String zoneId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kCooldownKeyPrefix$zoneId');
    await prefs.remove('$_kInsideKeyPrefix$zoneId');
    LogService.d('Cooldown + inside-state reset for "$zoneId"', tag: 'Geofence');
  }

  /// Debug: Tüm cooldown + içeride durumlarını sıfırla
  Future<void> debugResetAllCooldowns() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) =>
            k.startsWith(_kCooldownKeyPrefix) || k.startsWith(_kInsideKeyPrefix))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    LogService.d('All cooldowns + inside-state reset (${keys.length} keys)', tag: 'Geofence');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RIVERPOD PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Ana geofence service provider (AsyncNotifier — build() artık async)
final geofenceProvider =
    AsyncNotifierProvider<GeofenceNotifier, GeofenceState>(GeofenceNotifier.new);

/// Geofence servisi etkin mi? (loading/error durumunda false döner)
final isGeofenceEnabledProvider = Provider<bool>((ref) {
  return ref.watch(geofenceProvider).value?.isEnabled ?? false;
});

/// Şu an içinde olunan bölge (loading/error durumunda null döner)
final currentGeofenceZoneProvider = Provider<String?>((ref) {
  return ref.watch(geofenceProvider).value?.currentZoneId;
});
