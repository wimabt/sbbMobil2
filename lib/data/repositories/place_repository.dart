import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../api/api.dart';
import '../../core/utils/distance_helper.dart';
import '../../core/services/location_service.dart';
import '../models/models.dart';

/// Top-level function for isolate JSON parsing
/// Must be a top-level function (not a method) to work with compute()
List<Place> _parsePlacesInIsolate(List<dynamic> jsonList) {
  return jsonList
      .map((e) => Place.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Place Repository - CMS content layer (System A / PHP Backend)
///
/// **ID ROUTING RULE:**
/// All methods in this repository talk to the **PHP CMS backend** (System A).
/// IDs passed here MUST be CMS content IDs (`Place.cmsContentId` /
/// `Place.externalId`). NEVER pass gamification internal IDs to these methods.
abstract class PlaceRepository {
  /// Mekan listesi al (CMS content)
  /// [fields] parametresi ile sadece belirli alanlar çekilebilir (optimize)
  Future<ApiResponse<List<Place>>> getPlaces({
    int page = 1,
    int limit = 20,
    String? category,
    String lang = 'tr',
    String? fields,
  });

  /// Mekan özet listesi al (optimize edilmiş - liste ve harita için)
  /// [userLat], [userLng] verilirse server-side mesafe hesaplanır
  Future<ApiResponse<List<PlaceSummary>>> getPlacesSummary({
    int page = 1,
    int limit = 100,
    String? category,
    double? userLat,
    double? userLng,
    int? radius,
    bool withDistance = true,
    String sort = 'featured',
    String order = 'DESC',
    String lang = 'tr',
  });

  /// Tek mekan detayı (CMS content)
  /// [cmsPlaceId] MUST be the System A content ID (`Place.cmsContentId`).
  Future<Place?> getPlace(String cmsPlaceId, {String lang = 'tr'});

  /// Yakındaki mekanlar
  Future<ApiResponse<List<Place>>> getNearbyPlaces({
    required double lat,
    required double lng,
    int radius = 5,
    int limit = 20,
  });

  /// Mekan ara
  Future<ApiResponse<List<Place>>> searchPlaces({
    required String query,
    String? category,
    int page = 1,
    int limit = 20,
  });

  /// Place kategorileri (place count ile)
  Future<ApiResponse<List<PlaceCategory>>> getCategories({String lang = 'tr'});

  /// Öne çıkan mekanları getir (ana sayfa için optimize)
  Future<ApiResponse<List<Place>>> getFeaturedPlaces({
    int limit = 20,
    String lang = 'tr',
  });
}

/// Mock implementation - Backend gelene kadar kullanılacak
class MockPlaceRepository implements PlaceRepository {
  // Mock places data
  final List<Place> _mockPlaces = [
    const Place(
      id: '1',
      name: 'Tarihi Belediye Binası',
      description:
          '1890 yılında inşa edilen tarihi belediye binası, şehrin en önemli mimari eserlerinden biridir.',
      category: 'Tarihi',
      imageUrl: 'assets/images/place-historic.jpg',
      rating: 4.8,
      reviewCount: 124,
      distance: '1.2 km',
      featured: true,
      lat: 41.2867,
      lng: 36.33,
    ),
    const Place(
      id: '2',
      name: 'Merkez Park',
      description:
          'Şehrin kalbinde 50 hektarlık yeşil alan, yürüyüş parkurları ve çocuk oyun alanları.',
      category: 'Park',
      imageUrl: 'assets/images/place-park.jpg',
      rating: 4.5,
      reviewCount: 89,
      distance: '800 m',
      featured: true,
      lat: 41.2900,
      lng: 36.34,
    ),
    const Place(
      id: '3',
      name: 'Kültür ve Kongre Merkezi',
      description: 'Modern mimari tasarımıyla öne çıkan çok amaçlı kültür merkezi.',
      category: 'Kültür',
      imageUrl: 'assets/images/place-culture.jpg',
      rating: 4.7,
      reviewCount: 56,
      distance: '2.1 km',
      featured: false,
      lat: 41.2850,
      lng: 36.32,
    ),
  ];

  @override
  Future<ApiResponse<List<Place>>> getPlaces({
    int page = 1,
    int limit = 20,
    String? category,
    String lang = 'tr',
    String? fields,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    var filtered = _mockPlaces;
    if (category != null && category.isNotEmpty && category != 'all') {
      filtered = _mockPlaces
          .where((p) => p.category?.toLowerCase() == category.toLowerCase() || 
                        p.categoryId?.toString() == category)
          .toList();
    }

    return ApiResponse(
      status: true,
      message: 'Success',
      data: filtered,
      meta: ApiMeta(
        page: page,
        limit: limit,
        total: filtered.length,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      ),
    );
  }

  @override
  Future<Place?> getPlace(String id, {String lang = 'tr'}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    try {
      return _mockPlaces.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ApiResponse<List<Place>>> getNearbyPlaces({
    required double lat,
    required double lng,
    int radius = 5,
    int limit = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // Return all places as "nearby" for mock
    return ApiResponse(
      status: true,
      message: 'Success',
      data: _mockPlaces,
      meta: ApiMeta(
        page: 1,
        limit: limit,
        total: _mockPlaces.length,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      ),
    );
  }

  @override
  Future<ApiResponse<List<Place>>> searchPlaces({
    required String query,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final filtered = _mockPlaces.where((p) {
      final matchesQuery = p.name.toLowerCase().contains(query.toLowerCase()) ||
          (p.description?.toLowerCase().contains(query.toLowerCase()) ?? false);
      final matchesCategory = category == null ||
          category.isEmpty ||
          p.category?.toLowerCase() == category.toLowerCase() ||
          p.categoryId?.toString() == category;
      return matchesQuery && matchesCategory;
    }).toList();

    return ApiResponse(
      status: true,
      message: 'Success',
      data: filtered,
      meta: ApiMeta(
        page: page,
        limit: limit,
        total: filtered.length,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      ),
    );
  }

  @override
  Future<ApiResponse<List<PlaceCategory>>> getCategories({String lang = 'tr'}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return ApiResponse(
      status: true,
      message: 'Success',
      data: const [
        PlaceCategory(id: 'all', label: 'Tümü'),
        PlaceCategory(id: 'historic', label: 'Tarihi'),
        PlaceCategory(id: 'park', label: 'Parklar'),
        PlaceCategory(id: 'culture', label: 'Kültür'),
        PlaceCategory(id: 'food', label: 'Yeme-İçme'),
      ],
    );
  }

  @override
  Future<ApiResponse<List<PlaceSummary>>> getPlacesSummary({
    int page = 1,
    int limit = 100,
    String? category,
    double? userLat,
    double? userLng,
    int? radius,
    bool withDistance = true,
    String sort = 'featured',
    String order = 'DESC',
    String lang = 'tr',
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Mock places'ı PlaceSummary'ye dönüştür
    var filtered = _mockPlaces;
    if (category != null && category.isNotEmpty && category != 'all') {
      filtered = _mockPlaces
          .where((p) => p.category?.toLowerCase() == category.toLowerCase() || 
                        p.categoryId?.toString() == category)
          .toList();
    }

    final summaries = filtered.map((place) {
      // Mock mesafe hesaplama (kullanıcı konumu varsa)
      int? distanceMeters;
      String? distanceFormatted;
      if (userLat != null && userLng != null && place.lat != null && place.lng != null) {
        final dist = DistanceHelper.calculateHaversineDistance(
          LatLng(userLat, userLng),
          LatLng(place.lat!, place.lng!),
        );
        distanceMeters = dist.round();
        distanceFormatted = DistanceHelper.formatDistance(dist);
      }

      return PlaceSummary(
        id: place.id,
        name: place.name,
        description: place.description,
        categoryId: place.categoryId,
        categoryName: place.category,
        lat: place.lat,
        lng: place.lng,
        imageUrl: place.imageUrl,
        thumbnailUrl: null, // Mock'ta thumbnail yok
        rating: place.rating,
        reviewCount: place.reviewCount,
        featured: place.featured,
        distanceMeters: distanceMeters,
        distanceFormatted: distanceFormatted,
        distanceType: 'straight_line',
      );
    }).toList();

    return ApiResponse(
      status: true,
      message: 'Success',
      data: summaries,
      meta: ApiMeta(
        page: page,
        limit: limit,
        total: summaries.length,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      ),
    );
  }

  @override
  Future<ApiResponse<List<Place>>> getFeaturedPlaces({
    int limit = 20,
    String lang = 'tr',
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final featured = _mockPlaces.where((p) => p.featured).take(limit).toList();
    
    return ApiResponse(
      status: true,
      message: 'Success',
      data: featured,
      meta: ApiMeta(
        page: 1,
        limit: limit,
        total: featured.length,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      ),
    );
  }
}

/// API implementation - Backend hazır olduğunda kullanılacak
class ApiPlaceRepository implements PlaceRepository {
  ApiPlaceRepository(this._client);
  final ApiClient _client;

  @override
  Future<ApiResponse<List<Place>>> getPlaces({
    int page = 1,
    int limit = 20,
    String? category,
    String lang = 'tr',
    String? fields, // Yeni: Sadece belirli alanları çek
  }) async {
    try {
      // Limit çok yüksekse query parametresine ekleme (tüm sonuçları al)
      final queryParams = <String, dynamic>{
        'page': page,
        'lang': lang,
      };

      if (category != null) {
        queryParams['category'] = category;
      }
      if (fields != null) {
        queryParams['fields'] = fields; // Liste için optimize edilmiş alanlar
      }
      
      // Limit sadece makul bir değer ise ekle (10000 gibi çok yüksek değerler için ekleme)
      if (limit < 1000) {
        queryParams['limit'] = limit;
      }
      
      final response = await _client.get(
        ApiEndpoints.places,
        queryParameters: queryParams,
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;

      // PERFORMANCE: Use compute() for large JSON parsing (>20 items)
      final dataMap = data as Map<String, dynamic>;
      final itemsList = dataMap['data'] as List? ?? [];

      List<Place> places;
      if (itemsList.length > 20) {
        places = await compute(_parsePlacesInIsolate, itemsList);
      } else {
        // Small response: parse synchronously (isolate overhead not worth it)
        places = itemsList
            .map((e) => Place.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final apiResponse = ApiResponse<List<Place>>(
        status: dataMap['status'] == true,
        message: dataMap['message'] as String? ?? 'Success',
        data: places,
        meta: dataMap['meta'] != null 
            ? ApiMeta.fromJson(dataMap['meta'] as Map<String, dynamic>)
            : null,
      );

      // Distance hesaplama artık provider'da yapılıyor (non-blocking)
      // Repository'den kaldırıldı çünkü her sayfa için blocking yapıyordu

      return apiResponse;
    } on DioException catch (e) {
      debugPrint('🔥 [PlaceApi] getPlaces failed: status=${e.response?.statusCode} msg=${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<Place?> getPlace(String id, {String lang = 'tr'}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.place(id),
        queryParameters: {'lang': lang},
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;

      final api = ApiResponse.fromJson(
        data as Map<String, dynamic>,
        (obj) => Place.fromJson(obj as Map<String, dynamic>),
      );

      if (!api.status) {
        debugPrint('⚠️ [PlaceApi] getPlace status=false, message=${api.message}');
        return null;
      }

      final place = api.data;
      // Distance hesaplamayı background'da yap (non-blocking)
      if (place != null && place.lat != null && place.lng != null) {
        _addDistanceToPlace(place);
      }
      return place;
    } on DioException catch (e) {
      debugPrint('🔥 [PlaceApi] getPlace failed: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<ApiResponse<List<Place>>> getNearbyPlaces({
    required double lat,
    required double lng,
    int radius = 5,
    int limit = 20,
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.placesNearby,
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius': radius,
          'limit': limit,
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
  Future<ApiResponse<List<Place>>> searchPlaces({
    required String query,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'q': query,
        'page': page,
        'limit': limit,
      };

      if (category != null) {
        queryParams['category'] = category;
      }

      final response = await _client.get(
        ApiEndpoints.placesSearch,
        queryParameters: queryParams,
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
  Future<ApiResponse<List<PlaceCategory>>> getCategories({String lang = 'tr'}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.placesCategories,
        queryParameters: {'lang': lang},
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;

      // API response: { status: true, data: { categories: [...] } }
      final dataMap = data as Map<String, dynamic>;
      final categoriesData = dataMap['data'] as Map<String, dynamic>?;
      final categoriesList = categoriesData?['categories'] as List? ?? [];

      return ApiResponse.fromJson(
        dataMap,
        (obj) => categoriesList
            .map((e) => PlaceCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      debugPrint('🔥 [PlaceApi] getCategories failed: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  /// Add distance to a single place (non-blocking, background)
  void _addDistanceToPlace(Place place) {
    // Background'da çalıştır - UI'ı bloklamaz
    Future.microtask(() async {
      try {
        final userLocation = await LocationService.getCurrentLocation() ??
            await LocationService.getLastKnownLocation();

        if (userLocation == null || place.lat == null || place.lng == null) {
          return;
        }

        final distance = await DistanceHelper.calculateOSRMDistance(
          origin: userLocation,
          destination: LatLng(place.lat!, place.lng!),
        );

        // distance != null: provider state'i update edebilir; burada log gerekmez
        if (distance == null) return;
      } catch (e) {
        debugPrint('⚠️ [PlaceApi] Error calculating distance: $e');
      }
    });
  }

  @override
  Future<ApiResponse<List<PlaceSummary>>> getPlacesSummary({
    int page = 1,
    int limit = 100,
    String? category,
    double? userLat,
    double? userLng,
    int? radius,
    bool withDistance = true,
    String sort = 'featured',
    String order = 'DESC',
    String lang = 'tr',
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'lang': lang,
        'sort': sort,
        'order': order,
      };
      
      // Limit sadece makul bir değer ise ekle
      if (limit < 1000) {
        queryParams['limit'] = limit;
      }
      
      // Kullanıcı konumu varsa mesafe hesaplama için gönder
      if (userLat != null && userLng != null) {
        queryParams['lat'] = userLat;
        queryParams['lng'] = userLng;
        queryParams['with_distance'] = withDistance;
        if (radius != null) {
          queryParams['radius'] = radius;
        }
      }
      
      if (category != null) {
        queryParams['category'] = category;
      }

      final response = await _client.get(
        ApiEndpoints.placesSummary,
        queryParameters: queryParams,
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;
      return ApiResponse.fromJson(
        data as Map<String, dynamic>,
        (obj) => (obj as List)
            .map((e) => PlaceSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      debugPrint('🔥 [PlaceApi] getPlacesSummary failed: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<ApiResponse<List<Place>>> getFeaturedPlaces({
    int limit = 20,
    String lang = 'tr',
  }) async {
    try {
      // /places/featured endpoint'ini dene
      try {
        final response = await _client.get(
          ApiEndpoints.placesFeatured,
          queryParameters: {
            'limit': limit,
            'lang': lang,
          },
        );

        final raw = response.data;
        final data = raw is String ? jsonDecode(raw) : raw;

        return ApiResponse.fromJson(
          data as Map<String, dynamic>,
          (obj) => (obj as List)
              .map((e) => Place.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      } on DioException catch (e) {
        // Endpoint yoksa veya hata varsa fallback'e geç
        debugPrint('⚠️ [PlaceApi] /places/featured failed (${e.response?.statusCode}), falling back to /places');
      }

      // Fallback: /places endpoint'ini featured filtresiyle kullan
      final response = await _client.get(
        ApiEndpoints.places,
        queryParameters: {
          'limit': limit,
          'lang': lang,
          'featured': true, // Backend destekliyorsa
          'sort': 'featured', // Featured öncelikli sıralama
          'order': 'DESC',
          'fields':
              'id,name,description,category_id,lat,lng,image_url,thumbnail_url,featured,points',
        },
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;

      final apiResponse = ApiResponse.fromJson(
        data as Map<String, dynamic>,
        (obj) => (obj as List)
            .map((e) => Place.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

      // Client-side: Sadece featured olanları filtrele
      final featuredOnly = apiResponse.data?.where((p) => p.featured).toList() ?? [];

      return ApiResponse(
        status: apiResponse.status,
        message: apiResponse.message,
        data: featuredOnly,
        meta: apiResponse.meta,
      );
    } on DioException catch (e) {
      debugPrint('🔥 [PlaceApi] getFeaturedPlaces failed: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

}

/// Provider - Şimdilik Mock, backend gelince ApiPlaceRepository'ye geç
final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  // Gerçek backend API'sini kullan
  final client = ref.watch(apiClientProvider);
  return ApiPlaceRepository(client);
});
