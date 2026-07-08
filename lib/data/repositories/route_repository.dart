import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../models/models.dart';

/// Route Repository - CMS content layer (System A / PHP Backend)
///
/// **ID ROUTING RULE:**
/// All methods in this repository talk to the **PHP CMS backend** (System A).
/// IDs passed here MUST be CMS content IDs (`Route.cmsContentId` /
/// `Route.externalId`). NEVER pass gamification internal IDs to these methods.
abstract class RouteRepository {
  /// Rota listesi al (CMS content)
  Future<ApiResponse<List<Route>>> getRoutes({
    int page = 1,
    int limit = 20,
    String lang = 'tr',
    /// Sadece belirli alanları çekmek için optional fields parametresi
    String? fields,
  });

  /// Tek rota detayı (CMS content)
  /// [cmsRouteId] MUST be the System A content ID (`Route.cmsContentId`).
  Future<Route?> getRoute(String cmsRouteId, {String lang = 'tr'});

  /// Rota ara
  Future<ApiResponse<List<Route>>> searchRoutes({
    required String query,
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  });

  /// Zorluk seviyesine göre rotalar
  Future<ApiResponse<List<Route>>> getRoutesByDifficulty({
    required String level,
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  });

  /// Mesafe aralığına göre rotalar
  Future<ApiResponse<List<Route>>> getRoutesByDistance({
    double? min,
    double? max,
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  });
}

/// API implementation
class ApiRouteRepository implements RouteRepository {
  ApiRouteRepository(this._client, [ApiClient? authClient]);
  final ApiClient _client;

  @override
  Future<ApiResponse<List<Route>>> getRoutes({
    int page = 1,
    int limit = 20,
    String lang = 'tr',
    String? fields,
  }) async {
    try {

      // City guide backend'de rotalar için `travel-routes` endpoint'i kullanılıyor.
      // Backend tarafında completion_points / bonus_points / total_possible_points
      // alanları da bu endpoint'e eklendiği için mobil `/mobile/routes` endpoint'ine
      // geçmemize gerek yok.
      final response = await _client.get(
        ApiEndpoints.routes,
        queryParameters: {
          'page': page,
          'limit': limit,
          'lang': lang,
          'fields': ?fields,
        },
      );

      final raw = response.data;
      
      // NOT: 4xx status kodları artık Dio tarafından otomatik DioException olarak 
      // fırlatılıyor (validateStatus: 200-299). Manuel kontrol gereksiz.
      
      // HTML response kontrolü (beklenmeyen Content-Type durumları için)
      if (raw is String && raw.trim().startsWith('<!DOCTYPE')) {
        debugPrint('❌ [RouteApi] HTML response received instead of JSON');
        debugPrint('❌ [RouteApi] Status code: ${response.statusCode}');
        throw ApiException(
          message: 'API endpoint bulunamadı veya hata sayfası döndü. Status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      
      // Content-Type kontrolü
      final contentType = response.headers.value('content-type') ?? '';
      if (!contentType.contains('application/json') && !contentType.contains('text/json')) {
        debugPrint('⚠️ [RouteApi] Unexpected content-type: $contentType');
      }
      
      final data = raw is String ? jsonDecode(raw) : raw;
      debugPrint('✅ [RouteApi] /travel-routes status=${response.statusCode}');
      debugPrint('✅ [RouteApi] Content-Type: $contentType');
      
      // Response'un Map olduğundan emin ol
      if (data is! Map<String, dynamic>) {
        debugPrint('❌ [RouteApi] Response is not a Map, type: ${data.runtimeType}');
        debugPrint('❌ [RouteApi] Response data: $data');
        throw ApiException(
          message: 'API\'den beklenmeyen format geldi. JSON bekleniyordu.',
          statusCode: response.statusCode,
        );
      }
      
      debugPrint('✅ [RouteApi] response body: $data');

      final apiResponse = ApiResponse.fromJson(
        data,
        (obj) {
          if (obj == null) return <Route>[];
          if (obj is! List) {
            debugPrint('⚠️ [RouteApi] data is not a List, type: ${obj.runtimeType}');
            return <Route>[];
          }
          return obj
              .map((e) {
                try {
                  return Route.fromJson(e as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('⚠️ [RouteApi] Error parsing route: $e');
                  debugPrint('⚠️ [RouteApi] Route data: $e');
                  return null;
                }
              })
              .whereType<Route>()
              .toList();
        },
      );

      debugPrint('✅ [RouteApi] Parsed ${apiResponse.data?.length ?? 0} routes');

      return apiResponse;
    } on DioException catch (e) {
      debugPrint('🔥 [RouteApi] getRoutes DioException: ${e.message}');
      debugPrint('🔥 [RouteApi] statusCode: ${e.response?.statusCode}');
      debugPrint('🔥 [RouteApi] response data: ${e.response?.data}');
      throw ApiException.fromDioError(e);
    } catch (e) {
      debugPrint('🔥 [RouteApi] getRoutes Unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<Route?> getRoute(String id, {String lang = 'tr'}) async {
    // Caller (routeDetailProvider) already resolves CMS ID via RouteIdResolver.
    // Skip the extra API call that _resolveCmsId used to make.
    final cmsId = id;

    try {

      final response = await _client.get(
        ApiEndpoints.route(cmsId),
        queryParameters: {'lang': lang},
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;

      debugPrint('✅ [RouteApi] /travel-routes/$cmsId status=${response.statusCode}');

      if (data is! Map<String, dynamic>) {
        throw ApiException(
          message: "API'den beklenmeyen format geldi.",
          statusCode: response.statusCode,
        );
      }

      if (kDebugMode) {
        final routeData = data['data'];
        if (routeData is Map) {
          debugPrint('✅ [RouteApi] Route data keys: ${routeData.keys.toList()}');
          for (final field in ['places', 'stops', 'route_places', 'waypoints']) {
            if (routeData[field] is List) {
              debugPrint('✅ [RouteApi] $field: ${(routeData[field] as List).length} items');
            }
          }
        }
      }

      final api = ApiResponse.fromJson(
        data,
        (obj) => Route.fromJson(obj as Map<String, dynamic>),
      );

      if (api.data != null) {
        debugPrint('✅ [RouteApi] Parsed route: ${api.data!.name}, '
            'places: ${api.data!.places.length}, '
            'cover: ${api.data!.coverUrl ?? api.data!.cover}');
      }

      return api.data;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      debugPrint(
        '🔥 [RouteApi] getRoute(CMS) DioException: ${e.message} (status=$statusCode)',
      );
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<ApiResponse<List<Route>>> searchRoutes({
    required String query,
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.routesSearch,
        queryParameters: {
          'q': query,
          'page': page,
          'limit': limit,
          'lang': lang,
        },
      );

      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (obj) => (obj as List)
            .map((e) => Route.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<ApiResponse<List<Route>>> getRoutesByDifficulty({
    required String level,
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.routesDifficulty(level),
        queryParameters: {
          'page': page,
          'limit': limit,
          'lang': lang,
        },
      );

      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (obj) => (obj as List)
            .map((e) => Route.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<ApiResponse<List<Route>>> getRoutesByDistance({
    double? min,
    double? max,
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.routesDistance,
        queryParameters: {
          'min': ?min,
          'max': ?max,
          'page': page,
          'limit': limit,
          'lang': lang,
        },
      );

      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (obj) => (obj as List)
            .map((e) => Route.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

/// Provider
final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final authApiClient = ref.watch(authApiClientProvider);
  return ApiRouteRepository(apiClient, authApiClient);
});
