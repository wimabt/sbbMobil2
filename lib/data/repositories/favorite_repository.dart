import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api.dart';
import '../../core/network/api_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../models/models.dart';

/// Favorite Repository - Kullanıcı favorileri için data layer
/// JWT authentication gerektirir
abstract class FavoriteRepository {
  /// Tüm favorileri al
  Future<UserFavorites> getAllFavorites();

  /// Favori mekanları al (detaylı)
  Future<ApiResponse<List<Place>>> getFavoritePlaces({
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  });

  /// Favori tarifleri al (detaylı)
  Future<ApiResponse<List<Recipe>>> getFavoriteRecipes({
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  });

  /// Favori toggle (ekle/çıkar)
  Future<FavoriteToggleResult> toggleFavorite({
    required FavoriteEntityType entityType,
    required String entityId,
  });

  /// Toplu favori kontrolü
  Future<FavoriteCheckResult> checkFavorites({
    required FavoriteEntityType entityType,
    required List<String> entityIds,
  });
}

/// Local implementation – Favoriler cihazın kendi hafızasında tutulur.
///
/// `mobile_pending_changes.md` B15 sonrası backend whitelist'i (`place |
/// route | event | recipe | ar_point`) `ApiFavoriteRepository` üzerinden
/// senkronize edilir. Bu sınıf yalnızca:
///   1. Geçiş (migration) öncesi geriye uyumluluk için
///   2. Whitelist dışı tipler (`menu` — Gastronomi/Lezzetler) için fallback
/// olarak kullanılır.
class LocalFavoriteRepository implements FavoriteRepository {
  static const _kPlacesKey = 'favorites_places';
  static const _kRecipesKey = 'favorites_recipes';
  static const _kRoutesKey = 'favorites_routes';
  static const _kMenusKey = 'favorites_menus';

  /// API-only tipler (event, ar_point) local'de tutulmaz — çağrılırsa açık
  /// hata fırlat.
  String _prefsKeyFor(FavoriteEntityType type) {
    switch (type) {
      case FavoriteEntityType.place:
        return _kPlacesKey;
      case FavoriteEntityType.recipe:
        return _kRecipesKey;
      case FavoriteEntityType.route:
        return _kRoutesKey;
      case FavoriteEntityType.menu:
        return _kMenusKey;
      case FavoriteEntityType.event:
      case FavoriteEntityType.arPoint:
        throw UnsupportedError(
          'LocalFavoriteRepository: ${type.value} yalnızca API üzerinden '
          'desteklenir. ApiFavoriteRepository üzerinden çağırın.',
        );
    }
  }

  @override
  Future<UserFavorites> getAllFavorites() async {
    final prefs = await SharedPreferences.getInstance();

    final placeIds = prefs.getStringList(_kPlacesKey) ?? <String>[];
    final recipeIds = prefs.getStringList(_kRecipesKey) ?? <String>[];
    final routeIds = prefs.getStringList(_kRoutesKey) ?? <String>[];
    final menuIds = prefs.getStringList(_kMenusKey) ?? <String>[];

    return UserFavorites(
      places: placeIds
          .map(
            (id) => Favorite(
              id: id,
              entityType: FavoriteEntityType.place,
              entityId: id,
            ),
          )
          .toList(),
      recipes: recipeIds
          .map(
            (id) => Favorite(
              id: id,
              entityType: FavoriteEntityType.recipe,
              entityId: id,
            ),
          )
          .toList(),
      routes: routeIds
          .map(
            (id) => Favorite(
              id: id,
              entityType: FavoriteEntityType.route,
              entityId: id,
            ),
          )
          .toList(),
      menus: menuIds
          .map(
            (id) => Favorite(
              id: id,
              entityType: FavoriteEntityType.menu,
              entityId: id,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<ApiResponse<List<Place>>> getFavoritePlaces({
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  }) async {
    // Local cache sadece ID tutuyor; detaylı Place listesi backend'den yönetilecek.
    // Şimdilik boş bir liste dönüyoruz.
    return ApiResponse(
      status: true,
      message: 'Local favorites do not expose detailed place data.',
      data: const <Place>[],
      meta: ApiMeta(
        page: page,
        limit: limit,
        total: 0,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      ),
    );
  }

  @override
  Future<ApiResponse<List<Recipe>>> getFavoriteRecipes({
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  }) async {
    // Local cache sadece ID tutuyor; detaylı Recipe listesi backend'den yönetilecek.
    // Şimdilik boş bir liste dönüyoruz.
    return ApiResponse(
      status: true,
      message: 'Local favorites do not expose detailed recipe data.',
      data: const <Recipe>[],
      meta: ApiMeta(
        page: page,
        limit: limit,
        total: 0,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      ),
    );
  }

  @override
  Future<FavoriteToggleResult> toggleFavorite({
    required FavoriteEntityType entityType,
    required String entityId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final key = _prefsKeyFor(entityType);
    final current = prefs.getStringList(key) ?? <String>[];
    final updated = List<String>.from(current);

    bool isFavorite;
    if (updated.contains(entityId)) {
      updated.remove(entityId);
      isFavorite = false;
    } else {
      updated.add(entityId);
      isFavorite = true;
    }

    await prefs.setStringList(key, updated);

    return FavoriteToggleResult(
      success: true,
      isFavorite: isFavorite,
      entityType: entityType,
      entityId: entityId,
    );
  }

  @override
  Future<FavoriteCheckResult> checkFavorites({
    required FavoriteEntityType entityType,
    required List<String> entityIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final stored = prefs.getStringList(_prefsKeyFor(entityType)) ?? <String>[];

    return FavoriteCheckResult(
      entityType: entityType,
      favorites: {
        for (final id in entityIds) id: stored.contains(id),
      },
    );
  }
}

/// API implementation
///
/// `mobile_pending_changes.md` B15 — Favoriler artık `/api/v1/mobile/favorites`
/// altında canlı. `entity_type.isApiSynced == true` olanlar buraya gider;
/// `menu` gibi whitelist dışı tipler [_localFallback] üzerinden cihazda kalır.
class ApiFavoriteRepository implements FavoriteRepository {
  ApiFavoriteRepository(this._dio, {LocalFavoriteRepository? localFallback})
      : _localFallback = localFallback ?? LocalFavoriteRepository();

  /// Docker NestJS Dio (ApiService.dio) — `/api/v1/mobile/favorites/*` burada.
  /// Eskiden ApiClient (kesfetpanel) kullanılıyordu ama duplicate URL ve
  /// 404 üretiyordu: `/api/v1` + `/api/v1/mobile/...` = duplicate.
  final Dio _dio;

  /// Whitelist dışı entity tipleri (örn. `menu`) için local fallback.
  final LocalFavoriteRepository _localFallback;

  @override
  Future<UserFavorites> getAllFavorites() async {
    try {
      final response = await _dio.get(ApiEndpoints.favorites);

      // Backend'in tam dönüşünü görmek için (parse sorunlarını teşhis etmek için).
      if (kDebugMode) {
        debugPrint('[Favorites] GET response: ${response.data}');
      }

      // Backend response zarfı: `{success: true, data: [items]}`.
      // `data` ya List (yeni format) ya da Map (eski) olabilir; ikisini de
      // `UserFavorites.fromJson` dynamic kabul edip handle eder.
      final raw = response.data;
      dynamic dataField;
      if (raw is Map<String, dynamic>) {
        dataField = raw['data'];
      }
      final apiFavorites = UserFavorites.fromJson(dataField ?? raw);

      if (kDebugMode) {
        debugPrint(
          '[Favorites] Parsed: places=${apiFavorites.places.length} '
          'recipes=${apiFavorites.recipes.length} '
          'routes=${apiFavorites.routes.length} '
          'events=${apiFavorites.events.length}',
        );
      }

      // Whitelist dışı tipleri local'den ekle (şu an: menu).
      final localFavorites = await _localFallback.getAllFavorites();
      return apiFavorites.copyWith(menus: localFavorites.menus);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<ApiResponse<List<Place>>> getFavoritePlaces({
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.favoritesPlaces,
        queryParameters: {
          'page': page,
          'limit': limit,
          'lang': lang,
        },
      );

      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (obj) => (obj as List)
            .map((e) => Place.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<ApiResponse<List<Recipe>>> getFavoriteRecipes({
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.favoritesRecipes,
        queryParameters: {
          'page': page,
          'limit': limit,
          'lang': lang,
        },
      );

      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (obj) => (obj as List)
            .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<FavoriteToggleResult> toggleFavorite({
    required FavoriteEntityType entityType,
    required String entityId,
  }) async {
    // Whitelist dışı tipler (menu) → cihazda tut.
    if (!entityType.isApiSynced) {
      return _localFallback.toggleFavorite(
        entityType: entityType,
        entityId: entityId,
      );
    }

    try {
      final response = await _dio.post(
        ApiEndpoints.favoritesToggle,
        data: {
          'entity_type': entityType.value,
          'entity_id': entityId,
        },
      );

      if (kDebugMode) {
        debugPrint(
          '[Favorites] POST toggle($entityType/$entityId) → '
          '${response.statusCode} body: ${response.data}',
        );
      }

      final raw = response.data as Map<String, dynamic>;
      // Spec: `{ is_favorite: bool }`. Bazı wrapper'lar `data` altında verir.
      final payload =
          (raw['data'] is Map<String, dynamic>) ? raw['data'] as Map<String, dynamic> : raw;
      final isFavorite = payload['is_favorite'] as bool? ?? false;

      return FavoriteToggleResult(
        success: true,
        isFavorite: isFavorite,
        entityType: entityType,
        entityId: entityId,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<FavoriteCheckResult> checkFavorites({
    required FavoriteEntityType entityType,
    required List<String> entityIds,
  }) async {
    // Whitelist dışı tipler (menu) → cihazdan oku.
    if (!entityType.isApiSynced) {
      return _localFallback.checkFavorites(
        entityType: entityType,
        entityIds: entityIds,
      );
    }

    // Spec: `GET /favorites/check?entity_type=&entity_id=` — tekil sorgu.
    // Çoklu check için paralel istek atıyoruz; backend idempotent + cache'li.
    try {
      final results = await Future.wait(
        entityIds.map((id) async {
          final response = await _dio.get(
            ApiEndpoints.favoritesCheck,
            queryParameters: {
              'entity_type': entityType.value,
              'entity_id': id,
            },
          );
          final raw = response.data as Map<String, dynamic>;
          final payload = (raw['data'] is Map<String, dynamic>)
              ? raw['data'] as Map<String, dynamic>
              : raw;
          return MapEntry(id, payload['is_favorite'] as bool? ?? false);
        }),
      );

      return FavoriteCheckResult(
        entityType: entityType,
        favorites: Map.fromEntries(results),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

/// Provider — `mobile_pending_changes.md` B15 sonrası API destekli repository
/// kullanıyoruz. Whitelist dışı (`menu`) tipler hibrit fallback ile cihazda
/// kalır; geriye uyumlu.
final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  // Auth-aware (itineraryRepositoryProvider ile aynı desen): girişliyken
  // backend, anonim/misafirken cihaz. Anonim favoriler login'de
  // [FavoriteMigrationService] ile backend'e taşınır (postLoginSyncProvider).
  final auth = ref.watch(authProvider);
  if (auth.status == AuthStatus.authenticated) {
    // Backend `/api/v1/mobile/favorites/*` Docker NestJS'te servisleniyor.
    // ApiService.dio bu host'a bağlı + auto token attach + 401 refresh içeriyor.
    final dio = ref.watch(apiServiceProvider).dio;
    return ApiFavoriteRepository(dio);
  }
  // Anonim/misafir: place/recipe/route/menu cihazda tutulur.
  return LocalFavoriteRepository();
});
