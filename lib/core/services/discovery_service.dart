import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_service.dart';
import '../../data/models/points.dart';
import '../../api/api.dart';

/// Discovery Service – Keşif ve Puan Sistemi (System B / Gamification Backend)
///
/// **IMPORTANT — ID ROUTING RULE:**
/// All methods in this service talk to the **NestJS gamification backend**
/// (System B). They expect **gamification internal IDs** (`Place.id`,
/// `Route.id`). NEVER pass CMS content IDs (`externalId` / `cmsContentId`)
/// to these methods.
///
/// flutter-integration.md §11'deki DiscoveryService sınıfının implementasyonu.
/// Auth backend'inin mobile endpoint'lerini (§8-10) kullanarak:
///   - Yerleri listeler, detay getirir, ziyaret eder
///   - Rotaları listeler, detay getirir, durak ziyaret eder
///   - Puan bakiyesi ve geçmiş sorgular
///
/// Bu servis [ApiService]'in `dio` instance'ını kullanır ve böylece
/// JWT auth interceptor'lerinden (otomatik token ekleme, 401 → refresh)
/// otomatik olarak faydalanır.
class DiscoveryService {
  DiscoveryService(this._apiService);

  final ApiService _apiService;

  /// Kolay erişim – auth interceptor'lü Dio
  Dio get _dio => _apiService.dio;

  CancelToken? _activeToken;

  /// Navigasyon hızlı değiştiğinde bekleyen istekleri iptal eder.
  ///
  /// Örn: kullanıcı Place detay ekranından hızla geri çıkıp başka bir detaya girerse,
  /// önceki istekler tamamlanıp state'e stale veri basmasın.
  void cancelPending() {
    _activeToken?.cancel('Navigation changed');
    _activeToken = CancelToken();
  }

  CancelToken _token() {
    _activeToken ??= CancelToken();
    return _activeToken!;
  }

  // ─── Yerler ──────────────────────────────────────────────────────

  /// Yerleri listele (filtre, arama, pagination destekli)
  ///
  /// Endpoint: `GET /api/v1/mobile/places`
  Future<Map<String, dynamic>> getPlaces({
    String? category,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (category != null) query['category'] = category;
    if (search != null) query['search'] = search;

    final response = await _dio.get(
      '/api/v1/mobile/places',
      queryParameters: query,
      cancelToken: _token(),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Yer detayı getir (gamification data: points, visited, claimed).
  ///
  /// Endpoint: `GET /api/v1/mobile/places/:id`
  /// [gamificationPlaceId] MUST be the System B internal ID (`Place.id`).
  /// Do NOT pass CMS content IDs here.
  Future<Map<String, dynamic>> getPlaceDetail(String gamificationPlaceId) async {
    final response = await _dio.get(
      '/api/v1/mobile/places/$gamificationPlaceId',
      cancelToken: _token(),
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Yeri ziyaret et ve puan kazan ⭐
  ///
  /// Endpoint: `POST /api/v1/mobile/places/:id/visit`
  /// [gamificationPlaceId] MUST be the System B internal ID (`Place.id`).
  ///
  /// GPS koordinatları gönderilir, backend Haversine ile 100m mesafe kontrolü yapar.
  /// Başarılıysa [VisitResult] döner.
  Future<VisitResult> visitPlace(
    String gamificationPlaceId,
    double lat,
    double lng,
  ) async {
    final response = await _dio.post(
      '/api/v1/mobile/places/$gamificationPlaceId/visit',
      data: {'lat': lat, 'lng': lng},
      cancelToken: _token(),
    );
    final data = response.data as Map<String, dynamic>;
    return VisitResult.fromJson(data['data'] as Map<String, dynamic>);
  }

  // ─── Rotalar ─────────────────────────────────────────────────────

  /// Rotaları listele
  ///
  /// Endpoint: `GET /api/v1/mobile/routes`
  Future<List<dynamic>> getRoutes({String? search}) async {
    final response = await _dio.get(
      '/api/v1/mobile/routes',
      queryParameters: search != null ? {'search': search} : null,
      cancelToken: _token(),
    );
    return (response.data['data'] as List?) ?? [];
  }

  /// Rota detayı (duraklar ile birlikte) — gamification data.
  ///
  /// Endpoint: `GET /api/v1/mobile/routes/:id`
  /// [gamificationRouteId] MUST be the System B internal ID (`Route.id`).
  /// Do NOT pass CMS content IDs here.
  Future<Map<String, dynamic>> getRouteDetail(int gamificationRouteId) async {
    final response = await _dio.get(
      '/api/v1/mobile/routes/$gamificationRouteId',
      cancelToken: _token(),
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Rota durağını ziyaret et ⭐
  ///
  /// Endpoint: `POST /api/v1/mobile/routes/:routeId/places/:placeId/visit`
  /// [gamificationRouteId] and [gamificationPlaceId] MUST be System B internal IDs.
  ///
  /// Son durak ziyaret edildiğinde rota tamamlandı bonusu da eklenir.
  Future<RouteVisitResult> visitRouteStop(
    int gamificationRouteId,
    String gamificationPlaceId,
    double lat,
    double lng,
  ) async {
    final response = await _dio.post(
      '/api/v1/mobile/routes/$gamificationRouteId/places/$gamificationPlaceId/visit',
      data: {'lat': lat, 'lng': lng},
      cancelToken: _token(),
    );
    final data = response.data as Map<String, dynamic>;
    return RouteVisitResult.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Kullanıcının tüm rotalarındaki ilerleme listesi
  ///
  /// Endpoint: `GET /api/v1/mobile/routes/progress`
  Future<List<RouteProgressEntry>> getRouteProgress() async {
    try {
      final response = await _dio.get(
        '/api/v1/mobile/routes/progress',
        cancelToken: _token(),
      );
      final list = (response.data['data'] as List?) ?? [];
      return list
          .map((e) => RouteProgressEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // `mobile_pending_changes.md` P0/4 — Feature kapalıyken sessiz skip.
      if (e.isFeatureDisabled) return const [];
      rethrow;
    }
  }

  // ─── Puanlar ─────────────────────────────────────────────────────

  /// Puan bakiyesi
  ///
  /// Endpoint: `GET /api/v1/mobile/points/balance`
  Future<PointsBalance> getPointsBalance() async {
    try {
      final response = await _dio.get(
        '/api/v1/mobile/points/balance',
        cancelToken: _token(),
      );
      final data = response.data as Map<String, dynamic>;
      return PointsBalance.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      // `mobile_pending_changes.md` P0/4 — Feature kapalıyken sessiz skip.
      if (e.isFeatureDisabled) return PointsBalance.empty();
      rethrow;
    }
  }

  /// Puan geçmişi (pagination destekli)
  ///
  /// Endpoint: `GET /api/v1/mobile/points/history`
  Future<Map<String, dynamic>> getPointsHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/mobile/points/history',
        queryParameters: {'page': page, 'limit': limit},
        cancelToken: _token(),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // `mobile_pending_changes.md` P0/4 — Feature kapalıyken sessiz skip.
      if (e.isFeatureDisabled) {
        return const <String, dynamic>{'data': <dynamic>[], 'pagination': null};
      }
      rethrow;
    }
  }

  /// Puan geçmişini parse edilmiş liste olarak getir
  Future<List<PointTransaction>> getPointsHistoryParsed({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await getPointsHistory(page: page, limit: limit);
    final list = (data['data'] as List?) ?? [];
    return list
        .map((e) => PointTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Kampanyalar & Rozetler (mobile_integ.md) ─────────────────────

  /// Aktif kampanyalar listesini getir (§2.6 pagination destekli).
  ///
  /// Endpoint: `GET /api/v1/mobile/campaigns` veya `/my`
  /// Response artık `pagination` metadata içeriyor: page, limit, total, total_pages.
  Future<CampaignsPageResult> getCampaigns({
    bool onlyMy = false,
    int page = 1,
    int limit = 20,
  }) async {
    final path = onlyMy
        ? ApiEndpoints.mobileMyCampaigns
        : ApiEndpoints.mobileCampaigns;

    debugPrint('📢 [Campaigns] GET $path?page=$page&limit=$limit');

    try {
      final response = await _dio.get(
        path,
        queryParameters: {'page': page, 'limit': limit},
        cancelToken: _token(),
      );
      final raw = response.data;

      final List<dynamic> list;
      Map<String, dynamic>? pagination;

      if (raw is List) {
        list = raw;
      } else if (raw is Map<String, dynamic>) {
        list = (raw['data'] as List?) ?? <dynamic>[];
        pagination = raw['pagination'] as Map<String, dynamic>?;
      } else {
        throw StateError('Unexpected campaigns response shape: ${raw.runtimeType}');
      }

      final items = list.whereType<Map<String, dynamic>>().toList();
      final totalPages = pagination?['total_pages'] as int? ?? 1;

      debugPrint('📢 [Campaigns] Page $page/$totalPages — ${items.length} items');
      return CampaignsPageResult(items: items, totalPages: totalPages, currentPage: page);
    } on DioException catch (e) {
      // `mobile_pending_changes.md` P0/4 — Feature kapalıyken sessiz skip.
      if (e.isFeatureDisabled) {
        return CampaignsPageResult(items: const [], totalPages: 1, currentPage: page);
      }
      rethrow;
    }
  }

  /// Kullanıcının kampanya geçmişini getirir.
  ///
  /// Endpoint: `GET /api/v1/mobile/campaigns/history`
  ///
  /// Dönen yapı:
  /// {
  ///   "places": [...],
  ///   "routes": [...],
  ///   "summary": {...}
  /// }
  Future<Map<String, dynamic>> getCampaignsHistory() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.mobileCampaignsHistory,
        cancelToken: _token(),
      );
      final data = response.data as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      // `mobile_pending_changes.md` P0/4 — Feature kapalıyken sessiz skip.
      if (e.isFeatureDisabled) {
        return const <String, dynamic>{
          'places': <dynamic>[],
          'routes': <dynamic>[],
          'summary': <String, dynamic>{},
        };
      }
      rethrow;
    }
  }

  /// Tek bir kampanya detayını getir.
  ///
  /// Endpoint: `GET /api/v1/mobile/campaigns/:id`
  /// [gamificationCampaignId] MUST be the System B internal ID.
  Future<Map<String, dynamic>> getCampaignDetail(String gamificationCampaignId) async {
    final response = await _dio.get(
      ApiEndpoints.mobileCampaign(gamificationCampaignId),
      cancelToken: _token(),
    );
    final data = response.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  /// Kullanıcıyı kampanyaya dahil et.
  ///
  /// Endpoint: `POST /api/v1/mobile/campaigns/:id/enroll`
  /// [gamificationCampaignId] MUST be the System B internal ID.
  Future<Map<String, dynamic>> enrollToCampaign(String gamificationCampaignId) async {
    final response = await _dio.post(
      ApiEndpoints.mobileCampaignEnroll(gamificationCampaignId),
      cancelToken: _token(),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Kullanıcının rozet / başarımlar listesini getir.
  ///
  /// Endpoint: `GET /api/v1/mobile/achievements`
  Future<List<Map<String, dynamic>>> getAchievements() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.mobileAchievements,
        cancelToken: _token(),
      );
      final data = response.data as Map<String, dynamic>;
      final list = (data['data'] as List?) ?? <dynamic>[];
      return list
          .whereType<Map<String, dynamic>>()
          .toList();
    } on DioException catch (e) {
      // `mobile_pending_changes.md` P0/4 — Feature kapalıyken sessiz skip.
      if (e.isFeatureDisabled) return const [];
      rethrow;
    }
  }
}

/// §2.6 Pagination destekli kampanya sonucu
class CampaignsPageResult {
  final List<Map<String, dynamic>> items;
  final int totalPages;
  final int currentPage;

  const CampaignsPageResult({
    required this.items,
    required this.totalPages,
    required this.currentPage,
  });

  bool get hasMore => currentPage < totalPages;
}

/// Riverpod provider for DiscoveryService
final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return DiscoveryService(apiService);
});
