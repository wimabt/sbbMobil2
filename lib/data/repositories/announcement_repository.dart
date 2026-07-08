import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../models/models.dart';

/// Announcement Repository - Duyuru verileri için data layer
/// API Guide'a tam uyumlu implementasyon
abstract class AnnouncementRepository {
  /// Duyuru listesi al
  Future<ApiResponse<List<Announcement>>> getAnnouncements({
    int page = 1,
    int limit = 20,
    int? categoryId,
    String lang = 'tr',
    String? sort,
  });

  /// Tek duyuru detayı
  Future<Announcement?> getAnnouncement(String id, {String lang = 'tr'});

  /// Son duyurular (ana sayfa için)
  Future<List<Announcement>> getLatestAnnouncements({
    int limit = 5,
    String lang = 'tr',
  });

  /// Önemli duyurular
  Future<List<Announcement>> getImportantAnnouncements({String lang = 'tr'});

  /// Kategoriler
  Future<List<AnnouncementCategory>> getCategories({
    bool withCount = true,
    String lang = 'tr',
  });

  /// Kategoriye göre duyurular
  Future<ApiResponse<List<Announcement>>> getAnnouncementsByCategory({
    required int categoryId,
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  });

  /// Duyuru ara
  Future<List<Announcement>> searchAnnouncements({
    required String query,
    String lang = 'tr',
    int limit = 20,
  });

  /// Görüntülenme kaydet
  Future<void> recordView(String announcementId, {String? deviceId});

  /// Bildirim olarak gönderilmiş duyurular (Bildirimler sayfası)
  Future<List<Announcement>> getNotifications({
    int page = 1,
    int limit = 50,
    String lang = 'tr',
  });

  /// Push/bildirim tıklama analitiği kaydet
  Future<void> recordNotificationClick(
    String announcementId, {
    String? deviceId,
    String? oneSignalSubId,
  });
}

/// API implementation - Backend'e bağlı
class ApiAnnouncementRepository implements AnnouncementRepository {
  ApiAnnouncementRepository(this._client);
  final ApiClient _client;

  @override
  Future<ApiResponse<List<Announcement>>> getAnnouncements({
    int page = 1,
    int limit = 20,
    int? categoryId,
    String lang = 'tr',
    String? sort,
  }) async {
    try {

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        'lang': lang,
      };

      if (categoryId != null) {
        queryParams['category_id'] = categoryId;
      }
      if (sort != null) {
        queryParams['sort'] = sort;
      }

      final response = await _client.get(
        ApiEndpoints.announcements,
        queryParameters: queryParams,
      );

      final raw = response.data;
      dynamic data;
      
      try {
        data = raw is String ? jsonDecode(raw) : raw;
      } catch (e) {
        debugPrint('🔥 [AnnouncementApi] JSON decode error: $e');
        debugPrint('🔥 [AnnouncementApi] Response data type: ${raw.runtimeType}');
        if (raw is String) {
          debugPrint('🔥 [AnnouncementApi] Response preview: ${raw.substring(0, raw.length > 200 ? 200 : raw.length)}');
        }
        throw ApiException(
          message: 'API yanıtı geçersiz format: JSON parse hatası',
          statusCode: response.statusCode,
        );
      }
      
      debugPrint('✅ [AnnouncementApi] /announcements status=${response.statusCode}');

      // API response format: { success: true, data: [...], pagination: {...} }
      if (data is! Map<String, dynamic>) {
        debugPrint('🔥 [AnnouncementApi] Response is not a Map: ${data.runtimeType}');
        throw ApiException(
          message: 'API yanıtı beklenmeyen formatta',
          statusCode: response.statusCode,
        );
      }
      
      final dataMap = data;
      final items = (dataMap['data'] as List?) ?? [];
      final pagination = dataMap['pagination'] as Map<String, dynamic>?;
      

      return ApiResponse(
        status: dataMap['success'] == true,
        message: 'Success',
        data: items.map((e) => Announcement.fromJson(e as Map<String, dynamic>)).toList(),
        meta: ApiMeta(
          page: pagination?['page'] as int? ?? page,
          limit: pagination?['limit'] as int? ?? limit,
          total: pagination?['total'] as int? ?? items.length,
          totalPages: pagination?['total_pages'] as int? ?? 1,
          hasNext: pagination?['has_next'] == true,
          hasPrev: pagination?['has_prev'] == true,
        ),
      );
    } on DioException catch (e) {
      debugPrint('🔥 [AnnouncementApi] getAnnouncements DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<Announcement?> getAnnouncement(String id, {String lang = 'tr'}) async {
    try {

      final response = await _client.get(
        ApiEndpoints.announcement(id),
        queryParameters: {'lang': lang},
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;
      debugPrint('✅ [AnnouncementApi] /announcements/$id status=${response.statusCode}');

      final dataMap = data as Map<String, dynamic>;
      if (dataMap['success'] != true || dataMap['data'] == null) {
        return null;
      }

      return Announcement.fromJson(dataMap['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('🔥 [AnnouncementApi] getAnnouncement DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<Announcement>> getLatestAnnouncements({
    int limit = 5,
    String lang = 'tr',
  }) async {
    try {

      final response = await _client.get(
        ApiEndpoints.announcementsLatest,
        queryParameters: {'limit': limit, 'lang': lang},
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;
      debugPrint('✅ [AnnouncementApi] /announcements/latest status=${response.statusCode}');

      final dataMap = data as Map<String, dynamic>;
      final items = (dataMap['data'] as List?) ?? [];

      return items.map((e) => Announcement.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('🔥 [AnnouncementApi] getLatestAnnouncements DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<Announcement>> getImportantAnnouncements({String lang = 'tr'}) async {
    try {

      final response = await _client.get(
        ApiEndpoints.announcementsImportant,
        queryParameters: {'lang': lang},
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;
      debugPrint('✅ [AnnouncementApi] /announcements/important status=${response.statusCode}');

      final dataMap = data as Map<String, dynamic>;
      final items = (dataMap['data'] as List?) ?? [];

      return items.map((e) => Announcement.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('🔥 [AnnouncementApi] getImportantAnnouncements DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<AnnouncementCategory>> getCategories({
    bool withCount = true,
    String lang = 'tr',
  }) async {
    try {

      final response = await _client.get(
        ApiEndpoints.announcementsCategories,
        queryParameters: {'with_count': withCount, 'lang': lang},
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;
      debugPrint('✅ [AnnouncementApi] /announcements/categories status=${response.statusCode}');

      final dataMap = data as Map<String, dynamic>;
      final items = (dataMap['data'] as List?) ?? [];

      return items.map((e) => AnnouncementCategory.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('🔥 [AnnouncementApi] getCategories DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<ApiResponse<List<Announcement>>> getAnnouncementsByCategory({
    required int categoryId,
    int page = 1,
    int limit = 20,
    String lang = 'tr',
  }) async {
    try {

      final response = await _client.get(
        ApiEndpoints.announcementsByCategory(categoryId.toString()),
        queryParameters: {'page': page, 'limit': limit, 'lang': lang},
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;
      debugPrint('✅ [AnnouncementApi] /announcements/category/$categoryId status=${response.statusCode}');

      final dataMap = data as Map<String, dynamic>;
      final items = (dataMap['data'] as List?) ?? [];
      final pagination = dataMap['pagination'] as Map<String, dynamic>?;

      return ApiResponse(
        status: dataMap['success'] == true,
        message: 'Success',
        data: items.map((e) => Announcement.fromJson(e as Map<String, dynamic>)).toList(),
        meta: ApiMeta(
          page: pagination?['page'] as int? ?? page,
          limit: pagination?['limit'] as int? ?? limit,
          total: pagination?['total'] as int? ?? items.length,
          totalPages: pagination?['total_pages'] as int? ?? 1,
          hasNext: pagination?['has_next'] == true,
          hasPrev: pagination?['has_prev'] == true,
        ),
      );
    } on DioException catch (e) {
      debugPrint('🔥 [AnnouncementApi] getAnnouncementsByCategory DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<Announcement>> searchAnnouncements({
    required String query,
    String lang = 'tr',
    int limit = 20,
  }) async {
    if (query.length < 2) return [];

    try {

      final response = await _client.get(
        ApiEndpoints.announcementsSearch,
        queryParameters: {'q': query, 'lang': lang, 'limit': limit},
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;
      debugPrint('✅ [AnnouncementApi] /announcements/search status=${response.statusCode}');

      final dataMap = data as Map<String, dynamic>;
      final items = (dataMap['data'] as List?) ?? [];

      return items.map((e) => Announcement.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('🔥 [AnnouncementApi] searchAnnouncements DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<void> recordView(String announcementId, {String? deviceId}) async {
    try {

      await _client.post(
        ApiEndpoints.announcementView(announcementId),
        data: deviceId != null ? {'device_id': deviceId} : null,
      );

      debugPrint('✅ [AnnouncementApi] View recorded for announcement $announcementId');
    } on DioException catch (e) {
      // View kaydı başarısız olsa da uygulamayı kırmamalı
      debugPrint('⚠️ [AnnouncementApi] recordView failed: ${e.message}');
    }
  }

  @override
  Future<List<Announcement>> getNotifications({
    int page = 1,
    int limit = 50,
    String lang = 'tr',
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.announcementsNotifications,
        queryParameters: {'page': page, 'limit': limit, 'lang': lang},
      );

      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;
      debugPrint('✅ [AnnouncementApi] /announcements/notifications status=${response.statusCode}');

      final dataMap = data as Map<String, dynamic>;
      final items = (dataMap['data'] as List?) ?? [];

      return items
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('🔥 [AnnouncementApi] getNotifications DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<void> recordNotificationClick(
    String announcementId, {
    String? deviceId,
    String? oneSignalSubId,
  }) async {
    try {
      await _client.post(
        ApiEndpoints.announcementNotificationClick(announcementId),
        data: {
          'device_id': ?deviceId,
          'onesignal_sub_id': ?oneSignalSubId,
        },
      );
      debugPrint('✅ [AnnouncementApi] Notification click recorded for $announcementId');
    } on DioException catch (e) {
      // Analitik başarısız olsa da uygulamayı kırmamalı
      debugPrint('⚠️ [AnnouncementApi] recordNotificationClick failed: ${e.message}');
    }
  }
}

/// Provider — sbbMobilBackend (authApiClient). Duyurular artık CMS'ten değil,
/// admin panelin yönettiği Docker backend'inden okunur (memory: doğru backend
/// kuralı, blog_repository ile aynı yaklaşım).
final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  final client = ref.watch(authApiClientProvider);
  return ApiAnnouncementRepository(client);
});
