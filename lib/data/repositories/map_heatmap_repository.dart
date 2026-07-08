import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/active_locale.dart';
import '../../core/network/app_network_config.dart';
import '../../core/network/app_user_agent.dart';
import '../../core/network/ssl_pinning.dart';
import '../../core/services/log_service.dart';

/// Tek bir ısı haritası örneği (lat/lng + ağırlık).
///
/// Backend `mobile_pending_changes.md` B4 — şema:
/// ```json
/// { "lat": 41.28, "lng": 36.33, "weight": 0.8 }
/// ```
/// Bazı response varyasyonlarında `intensity` veya `count` alanları da
/// kullanılır; tüm yaygın isimlendirmeleri yakalıyoruz.
@immutable
class HeatmapPoint {
  const HeatmapPoint({
    required this.lat,
    required this.lng,
    this.weight = 1.0,
  });

  final double lat;
  final double lng;

  /// 0.0 ile 1.0 arası normalize edilmiş ağırlık.
  final double weight;

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    return HeatmapPoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      weight: (json['weight'] as num?)?.toDouble() ??
          (json['intensity'] as num?)?.toDouble() ??
          (json['count'] as num?)?.toDouble() ??
          1.0,
    );
  }
}

/// `mobile_pending_changes.md` B4 — ısı haritası verilerini çeker.
///
/// **Önemli:** Heatmap endpoint'i içerik panelinde (`kesfetpanel...`)
/// **bulunmuyor**, sadece Docker tarafındaki backend'de var. Bu yüzden
/// bu repository, [ApiClient]'tan bağımsız olarak `AppNetworkConfig.apiBaseUrl`
/// üzerinden ayrı bir Dio instance kullanır. Diğer içerik repository'leri
/// (places, routes, events, recipes, announcements) aynen kesfetpanel'e
/// gitmeye devam eder.
///
/// **In-memory cache (5 dk):** Spec'te bbox'a göre 5 dakika cache önerilmiş.
/// Mobilde aynı bbox + same since için tekrar fetch atmıyoruz.
///
/// Opsiyonel feature — backend hazır değilse fetch sessizce boş döner;
/// MapScreen toggle false kaldığında UI bunu hiç çağırmaz.
class MapHeatmapRepository {
  MapHeatmapRepository._(this._dio);

  /// Docker host'una bağlı, sadece bu repository tarafından kullanılan Dio.
  /// AppNetworkConfig değiştiğinde provider yeniden inşa edilir.
  final Dio _dio;

  factory MapHeatmapRepository.create() {
    final host = AppNetworkConfig.apiBaseUrl.trim();
    final stripped = host.endsWith('/')
        ? host.substring(0, host.length - 1)
        : host;
    final dio = Dio(
      BaseOptions(
        baseUrl: '$stripped/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        // Diğer tüm istemcilerle (ApiService/ApiClient/StaffApiService) aynı
        // header seti. User-Agent eksikliği bazı reverse-proxy/WAF kurallarınca
        // farklı muamele görebiliyor.
        headers: {
          'Accept': 'application/json',
          'User-Agent': buildSbbMobileUserAgent(),
        },
      ),
    );

    // ÖNEMLİ: Diğer Dio istemcileri SSL pinning'i uyguluyor; bu ham Dio
    // uygulamıyordu. Prod HTTPS'te (mobil.smartsamsun.com) pinning yapılandırılı
    // bir release'de, pinli istemciler `badCertificateCallback` yolundan
    // bağlanırken pin'siz heatmap Dio'su varsayılan TLS yolundan gidiyor ve
    // bazı cihazlarda handshake/route farkı nedeniyle sessizce boş dönüyordu.
    // Artık çalışan endpoint'lerle birebir aynı TLS davranışı.
    SslPinning.configureDio(dio);

    // Aktif dili bildir (içerik adı vb. için backend ileride kullanabilir).
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            options.headers['Accept-Language'] =
                await ActiveLocale.languageCode();
          } catch (_) {}
          handler.next(options);
        },
      ),
    );

    return MapHeatmapRepository._(dio);
  }

  static const Duration _kCacheTtl = Duration(minutes: 5);

  String? _lastCacheKey;
  DateTime? _lastCacheAt;
  List<HeatmapPoint>? _lastCacheData;

  /// Backend endpoint'i 404 dönmüşse zamanını tutarız. Cooldown süresince
  /// boş istek atmayız; cooldown bitince tekrar denenir (backend deploy edilmiş
  /// olabilir).
  static const Duration _kUnavailableCooldown = Duration(seconds: 60);
  DateTime? _unavailableSince;

  /// Endpoint şu an cooldown'da mı (yani son 60sn içinde 404 verdi mi).
  bool get isEndpointUnavailable {
    if (_unavailableSince == null) return false;
    final elapsed = DateTime.now().difference(_unavailableSince!);
    if (elapsed > _kUnavailableCooldown) {
      _unavailableSince = null;
      return false;
    }
    return true;
  }

  /// Manuel reset (örn. kullanıcı toggle'a yeniden bastığında).
  void resetAvailability() {
    _unavailableSince = null;
  }

  /// [bbox]: `minLat,minLng,maxLat,maxLng` (Google Maps `LatLngBounds`'tan üret).
  /// [since]: ISO8601 zaman damgası (örn. son 14 gün) — backend opsiyonel.
  Future<List<HeatmapPoint>> getHeatmap({
    required String bbox,
    String? since,
    bool forceRefresh = false,
  }) async {
    // Endpoint 404 vermiş ve cooldown sürmekte — boş dön.
    if (isEndpointUnavailable) {
      return const [];
    }

    final cacheKey = '$bbox::${since ?? ''}';

    if (!forceRefresh &&
        _lastCacheKey == cacheKey &&
        _lastCacheAt != null &&
        DateTime.now().difference(_lastCacheAt!) < _kCacheTtl &&
        _lastCacheData != null) {
      return _lastCacheData!;
    }

    try {
      final response = await _dio.get<dynamic>(
        '/map/heatmap',
        queryParameters: {
          'bbox': bbox,
          'since': ?since,
        },
      );

      final raw = response.data;
      final List<dynamic> list;
      if (raw is Map<String, dynamic>) {
        final payload = (raw['data'] is Map<String, dynamic>)
            ? raw['data'] as Map<String, dynamic>
            : raw;
        list = (payload['points'] as List?) ??
            (payload['data'] as List?) ??
            const [];
      } else if (raw is List) {
        list = raw;
      } else {
        list = const [];
      }

      final points = list
          .whereType<Map<String, dynamic>>()
          .map(HeatmapPoint.fromJson)
          .where((p) => p.lat != 0.0 || p.lng != 0.0)
          .toList(growable: false);

      _lastCacheKey = cacheKey;
      _lastCacheAt = DateTime.now();
      _lastCacheData = points;

      if (kDebugMode) {
        debugPrint('[Heatmap] fetched ${points.length} point(s) for bbox=$bbox');
      }
      return points;
    } on DioException catch (e) {
      // 404 → backend endpoint henüz yayında değil; 60sn cooldown ile
      // boş istek tekrarını engelle, sonra tekrar dener (deploy olabilir).
      if (e.response?.statusCode == 404) {
        _unavailableSince = DateTime.now();
        LogService.w(
          'Heatmap endpoint 404 — disabled for ${_kUnavailableCooldown.inSeconds}s',
          tag: 'Heatmap',
        );
        return const [];
      }
      LogService.w(
        'Heatmap fetch failed: type=${e.type.name} '
        'status=${e.response?.statusCode} msg=${e.message}',
        tag: 'Heatmap',
      );
      // Opsiyonel feature — hata durumunda son cache'i ya da boş listeyi döndür.
      return _lastCacheData ?? const [];
    } catch (e) {
      LogService.w('Heatmap parse failed: $e', tag: 'Heatmap');
      return _lastCacheData ?? const [];
    }
  }
}

final mapHeatmapRepositoryProvider = Provider<MapHeatmapRepository>((ref) {
  return MapHeatmapRepository.create();
});
