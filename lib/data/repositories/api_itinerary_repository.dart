import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../api/api_client.dart' show ApiException;
import '../../api/endpoints.dart';
import '../models/itinerary.dart';
import 'itinerary_repository.dart';

/// mobile_integ.md §5.2 — API tabanlı itinerary deposu.
///
/// `ItineraryRepository` sözleşmesini sunucu uç noktalarına yönlendirir.
/// Tüm metotlar `ApiException` fırlatabilir; çağıran (notifier) UI'da
/// uygun mesajı gösterir veya state'i geri sarar.
class ApiItineraryRepository implements ItineraryRepository {
  ApiItineraryRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Itinerary>> list() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.itineraries,
        queryParameters: const {'page': 1, 'limit': 50},
      );
      if (kDebugMode) {
        debugPrint('[Itinerary] GET response: ${response.data}');
      }
      final data = response.data;
      if (data is Map<String, dynamic>) {
        // Format A: { data: [...] }
        var payload = data['data'];
        // Format B: { data: { items: [...] } }
        if (payload is Map<String, dynamic>) {
          payload = payload['items'] ?? payload['itineraries'] ?? payload;
        }
        if (payload is List) {
          final parsed = payload
              .whereType<Map<String, dynamic>>()
              .map(Itinerary.fromJson)
              .toList();
          if (kDebugMode) {
            debugPrint('[Itinerary] Parsed ${parsed.length} itinerary');
          }
          return parsed;
        }
      } else if (data is List) {
        // Format C: doğrudan array (sarmasız)
        final parsed = data
            .whereType<Map<String, dynamic>>()
            .map(Itinerary.fromJson)
            .toList();
        if (kDebugMode) {
          debugPrint('[Itinerary] Parsed ${parsed.length} itinerary (flat)');
        }
        return parsed;
      }
      if (kDebugMode) {
        debugPrint('[Itinerary] Unknown response shape — returning empty');
      }
      return const [];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<Itinerary?> getById(String id) async {
    try {
      final response = await _dio.get(ApiEndpoints.itineraryById(id));
      if (kDebugMode) {
        debugPrint('[Itinerary] getById($id) response: ${response.data}');
      }
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final parsed = Itinerary.fromJson(payload);
          if (kDebugMode) {
            debugPrint(
              '[Itinerary] getById($id) parsed: items=${parsed.items.length} '
              'itemsCount=${parsed.itemsCount}',
            );
          }
          return parsed;
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<Itinerary> create({
    required String title,
    DateTime? startsAt,
    DateTime? endsAt,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.itineraries,
        data: {
          'title': title,
          'starts_at': ?startsAt?.toIso8601String(),
          'ends_at': ?endsAt?.toIso8601String(),
          'notes': ?notes,
        },
      );
      return _extractItinerary(response);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<Itinerary> update(Itinerary itinerary) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.itineraryById(itinerary.id),
        data: {
          'title': itinerary.title,
          if (itinerary.startsAt != null)
            'starts_at': itinerary.startsAt!.toIso8601String(),
          if (itinerary.endsAt != null)
            'ends_at': itinerary.endsAt!.toIso8601String(),
          if (itinerary.notes != null) 'notes': itinerary.notes,
        },
      );
      return _extractItinerary(response);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _dio.delete(ApiEndpoints.itineraryById(id));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return;
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<Itinerary> addItem(String itineraryId, ItineraryItem item) async {
    final path = ApiEndpoints.itineraryItems(itineraryId);
    final body = {
      'entity_type': item.entityType.value,
      'entity_id': item.entityId,
      if (item.visitAt != null) 'visit_at': item.visitAt!.toIso8601String(),
      if (item.notes != null) 'notes': item.notes,
    };
    if (kDebugMode) {
      debugPrint('[Itinerary] POST $path → $body');
    }
    try {
      final res = await _dio.post(path, data: body);
      if (kDebugMode) {
        debugPrint('[Itinerary] POST $path → ${res.statusCode}');
      }
      // Backend güncel plan'ı item listesiyle birlikte döner; tutarlılık için tekrar al.
      final fresh = await getById(itineraryId);
      if (fresh == null) {
        throw const ApiException(message: 'Plan eklendi ama tekrar çekilemedi');
      }
      return fresh;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Itinerary] POST $path FAILED → status=${e.response?.statusCode} '
          'body=${e.response?.data} msg=${e.message}',
        );
      }
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<Itinerary> updateItem(
      String itineraryId, ItineraryItem item) async {
    try {
      await _dio.patch(
        ApiEndpoints.itineraryItem(itineraryId, item.id),
        data: {
          if (item.visitAt != null)
            'visit_at': item.visitAt!.toIso8601String(),
          if (item.notes != null) 'notes': item.notes,
        },
      );
      final fresh = await getById(itineraryId);
      if (fresh == null) {
        throw const ApiException(message: 'Plan güncellendi ama çekilemedi');
      }
      return fresh;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<Itinerary> removeItem(String itineraryId, String itemId) async {
    try {
      await _dio.delete(ApiEndpoints.itineraryItem(itineraryId, itemId));
      final fresh = await getById(itineraryId);
      if (fresh == null) {
        throw const ApiException(message: 'Durak silindi ama çekilemedi');
      }
      return fresh;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<Itinerary> reorderItems(
      String itineraryId, List<String> orderedIds) async {
    try {
      await _dio.put(
        ApiEndpoints.itineraryOrder(itineraryId),
        data: {'ordered_ids': orderedIds},
      );
      final fresh = await getById(itineraryId);
      if (fresh == null) {
        throw const ApiException(message: 'Sıralama güncellendi ama çekilemedi');
      }
      return fresh;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Itinerary _extractItinerary(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final payload = data['data'];
      if (payload is Map<String, dynamic>) {
        return Itinerary.fromJson(payload);
      }
    }
    throw const ApiException(message: 'Itinerary yanıtı beklenmedik formatta');
  }
}
