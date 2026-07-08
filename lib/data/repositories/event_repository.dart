import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../models/models.dart';

/// Liste için önerilen fields (EVENTS_API_MOBILE_KULLANIM.md)
const String _listFields =
    'id,title,date,time,place,image_url,type,is_free,category_label';


/// Event Repository – Etkinlikler API (EVENTS_API_MOBILE_KULLANIM.md)
abstract class EventRepository {
  /// Sayfalı etkinlik listesi
  Future<ApiResponse<List<Event>>> getEvents({
    int page = 1,
    int limit = 20,
    String lang = 'tr',
    String? type,
    String? category,
    int? isFree,
    String sort = 'date',
    String order = 'ASC',
    String? fields,
  });

  /// Tek etkinlik detayı
  Future<Event?> getEvent(String id, {String lang = 'tr', String? fields});

  /// Etkinlik kategorileri (tür listesi)
  Future<List<EventCategoryItem>> getCategories({String lang = 'tr'});

  /// Öne çıkan etkinlikler
  Future<List<Event>> getFeatured({
    int limit = 10,
    String lang = 'tr',
    String? fields,
  });

  /// Yaklaşan etkinlikler
  Future<List<Event>> getUpcoming({
    int limit = 10,
    int days = 30,
    String lang = 'tr',
    String? fields,
  });

  /// Etkinlik arama (q min 2 karakter)
  Future<List<Event>> search({
    required String q,
    int limit = 20,
    String? category,
    String lang = 'tr',
    String? fields,
  });

  /// Görüntülenme kaydı
  Future<void> recordView(String eventId);
}

class ApiEventRepository implements EventRepository {
  ApiEventRepository(this._client);
  final ApiClient _client;

  Map<String, dynamic> _parseResponse(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('🔥 [EventRepository] JSON decode error: $e');
        rethrow;
      }
    }
    throw ApiException(message: 'API yanıtı geçersiz format');
  }

  @override
  Future<ApiResponse<List<Event>>> getEvents({
    int page = 1,
    int limit = 20,
    String lang = 'tr',
    String? type,
    String? category,
    int? isFree,
    String sort = 'date',
    String order = 'ASC',
    String? fields,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit.clamp(1, 100),
        'lang': lang,
        'sort': sort,
        'order': order,
        'fields': fields ?? _listFields,
        if (type != null && type.isNotEmpty) 'type': type,
        if (category != null && category.isNotEmpty) 'category': category,
        'is_free': ?isFree,
      };

      final response = await _client.get(
        ApiEndpoints.events,
        queryParameters: queryParams,
      );

      final data = _parseResponse(response.data);
      debugPrint('✅ [EventRepository] getEvents response: status=${data['status']}');
      
      if (data['status'] != true) {
        debugPrint('🔥 [EventRepository] getEvents: status is not true, message=${data['message']}');
        throw ApiException(
          message: data['message']?.toString() ?? 'İstek başarısız',
          code: data['code']?.toString(),
        );
      }

      final items = (data['data'] as List?) ?? [];
      final metaJson = data['meta'] as Map<String, dynamic>?;
      debugPrint('✅ [EventRepository] getEvents: parsed ${items.length} items, meta=$metaJson');

      return ApiResponse(
        status: true,
        message: data['message']?.toString() ?? 'Success',
        data: items
            .map((e) => Event.fromJson(e as Map<String, dynamic>))
            .toList(),
        meta: metaJson != null
            ? ApiMeta(
                page: metaJson['page'] as int? ?? page,
                limit: metaJson['limit'] as int? ?? limit,
                total: metaJson['total'] as int? ?? 0,
                totalPages: metaJson['total_pages'] as int? ?? 0,
                hasNext: metaJson['has_next'] == true,
                hasPrev: metaJson['has_prev'] == true,
              )
            : null,
      );
    } on DioException catch (e) {
      debugPrint('🔥 [EventRepository] getEvents DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    } catch (e) {
      debugPrint('🔥 [EventRepository] getEvents error: $e');
      rethrow;
    }
  }

  @override
  Future<Event?> getEvent(String id, {String lang = 'tr', String? fields}) async {
    try {
      const detailFields =
          'id,title,date,time,place,image_url,ticket_url,is_free,location,category_label,created_at,updated_at';
      final response = await _client.get(
        ApiEndpoints.event(id),
        queryParameters: {
          'lang': lang,
          'fields': fields ?? detailFields,
        },
      );

      final data = _parseResponse(response.data);
      if (data['status'] != true || data['data'] == null) return null;

      return Event.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<EventCategoryItem>> getCategories({String lang = 'tr'}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.eventsCategories,
        queryParameters: {'lang': lang},
      );

      final data = _parseResponse(response.data);
      debugPrint('✅ [EventRepository] getCategories response: status=${data['status']}');
      
      if (data['status'] != true) {
        debugPrint('⚠️ [EventRepository] getCategories: status is not true');
        return [];
      }

      final dataObj = data['data'];
      if (dataObj is! Map<String, dynamic>) {
        debugPrint('⚠️ [EventRepository] getCategories: data is not a Map');
        return [];
      }
      final categories = dataObj['categories'] as List?;
      if (categories == null) {
        debugPrint('⚠️ [EventRepository] getCategories: categories is null');
        return [];
      }

      final result = categories
          .map((e) => EventCategoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('✅ [EventRepository] getCategories: parsed ${result.length} categories');
      return result;
    } on DioException catch (e) {
      debugPrint('🔥 [EventRepository] getCategories DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    } catch (e) {
      debugPrint('🔥 [EventRepository] getCategories error: $e');
      rethrow;
    }
  }

  @override
  Future<List<Event>> getFeatured({
    int limit = 10,
    String lang = 'tr',
    String? fields,
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.eventsFeatured,
        queryParameters: {
          'limit': limit.clamp(1, 20),
          'lang': lang,
          'fields': fields ?? _listFields,
        },
      );

      final data = _parseResponse(response.data);
      if (data['status'] != true) return [];

      final items = (data['data'] as List?) ?? [];
      return items
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<Event>> getUpcoming({
    int limit = 10,
    int days = 30,
    String lang = 'tr',
    String? fields,
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.eventsUpcoming,
        queryParameters: {
          'limit': limit.clamp(1, 50),
          'days': days,
          'lang': lang,
          'fields': fields ?? _listFields,
        },
      );

      final data = _parseResponse(response.data);
      debugPrint('✅ [EventRepository] getUpcoming response: status=${data['status']}');
      
      if (data['status'] != true) {
        debugPrint('⚠️ [EventRepository] getUpcoming: status is not true');
        return [];
      }

      final items = (data['data'] as List?) ?? [];
      final result = items
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('✅ [EventRepository] getUpcoming: parsed ${result.length} events');
      return result;
    } on DioException catch (e) {
      debugPrint('🔥 [EventRepository] getUpcoming DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    } catch (e) {
      debugPrint('🔥 [EventRepository] getUpcoming error: $e');
      rethrow;
    }
  }

  @override
  Future<List<Event>> search({
    required String q,
    int limit = 20,
    String? category,
    String lang = 'tr',
    String? fields,
  }) async {
    if (q.length < 2) return [];

    try {
      final response = await _client.get(
        ApiEndpoints.eventsSearch,
        queryParameters: {
          'q': q,
          'limit': limit.clamp(1, 50),
          'lang': lang,
          'fields': fields ?? _listFields,
          if (category != null && category.isNotEmpty) 'category': category,
        },
      );

      final data = _parseResponse(response.data);
      if (data['status'] != true) return [];

      final items = (data['data'] as List?) ?? [];
      return items
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<void> recordView(String eventId) async {
    try {
      await _client.post(ApiEndpoints.eventView(eventId));
    } on DioException catch (_) {
      // Görüntülenme kaydı başarısız olsa da uygulamayı kırmamalı
    }
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiEventRepository(client);
});
