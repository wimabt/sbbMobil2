import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../core/network/api_service.dart';
import '../../core/utils/image_url_helper.dart';
import '../models/models.dart';

/// Şehir Rehberi & Blog veri katmanı.
///
/// Backend: **sbbMobilBackend** `/api/v1/mobile/blog/*` (CMS değil) →
/// bu yüzden `authApiClientProvider` kullanılır (memory: doğru backend kuralı).
/// Sunucu dil-çözümünü `Accept-Language` header'ı + `?lang` ile yapar.
abstract class BlogRepository {
  Future<ApiResponse<List<BlogPost>>> getPosts({
    int page = 1,
    int limit = 20,
    String? category,
    String? tag,
    String? search,
    bool featured = false,
    String lang = 'tr',
  });

  Future<List<BlogPost>> getFeatured({int limit = 5, String lang = 'tr'});

  Future<BlogPost?> getPost(String slugOrId, {String lang = 'tr'});

  Future<List<BlogCategory>> getCategories({String lang = 'tr'});

  Future<List<BlogTag>> getTags({String lang = 'tr'});

  Future<void> recordView(String id);
}

class ApiBlogRepository implements BlogRepository {
  ApiBlogRepository(this._client);
  final ApiClient _client;

  Map<String, dynamic> _decode(dynamic raw) {
    final data = raw is String ? jsonDecode(raw) : raw;
    if (data is! Map<String, dynamic>) {
      throw ApiException(message: 'Beklenmeyen API yanıtı');
    }
    return data;
  }

  /// Görsel adresini cihazdan erişilebilir mutlak URL'ye çevirir:
  ///   • göreli yol (`/blog-images/x`) → `ApiService.baseUrl` ile birleştir
  ///   • iç-ağ mutlak URL (`http://192.168.x:9000/...`) → API host'una yeniden yaz
  String? _resolveImg(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) {
      return rewriteStorageUrl(s);
    }
    return buildImageUrl(s, baseUrl: ApiService.baseUrl);
  }

  /// JSON'daki görsel alanlarını çözüp BlogPost'a dönüştürür.
  BlogPost _toPost(Map<String, dynamic> m) {
    m['cover_image_url'] = _resolveImg(m['cover_image_url']);
    m['thumbnail_url'] = _resolveImg(m['thumbnail_url']);
    return BlogPost.fromJson(m);
  }

  @override
  Future<ApiResponse<List<BlogPost>>> getPosts({
    int page = 1,
    int limit = 20,
    String? category,
    String? tag,
    String? search,
    bool featured = false,
    String lang = 'tr',
  }) async {
    try {
      final qp = <String, dynamic>{'page': page, 'limit': limit, 'lang': lang};
      if (category != null && category.isNotEmpty) qp['category'] = category;
      if (tag != null && tag.isNotEmpty) qp['tag'] = tag;
      if (search != null && search.isNotEmpty) qp['search'] = search;
      if (featured) qp['featured'] = 'true';

      final response = await _client.get(ApiEndpoints.blog, queryParameters: qp);
      final map = _decode(response.data);
      final items = (map['data'] as List?) ?? [];
      final pagination = map['pagination'] as Map<String, dynamic>?;

      int? pInt(String a, String b) =>
          (pagination?[a] as int?) ?? (pagination?[b] as int?);

      return ApiResponse(
        status: map['success'] == true,
        message: 'Success',
        data: items
            .map((e) => _toPost(e as Map<String, dynamic>))
            .toList(),
        meta: ApiMeta(
          page: pagination?['page'] as int? ?? page,
          limit: pagination?['limit'] as int? ?? limit,
          total: pagination?['total'] as int? ?? items.length,
          totalPages: pInt('totalPages', 'total_pages') ?? 1,
          hasNext: (pagination?['page'] as int? ?? page) <
              (pInt('totalPages', 'total_pages') ?? 1),
          hasPrev: (pagination?['page'] as int? ?? page) > 1,
        ),
      );
    } on DioException catch (e) {
      debugPrint('🔥 [BlogApi] getPosts: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<BlogPost>> getFeatured({int limit = 5, String lang = 'tr'}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.blogFeatured,
        queryParameters: {'limit': limit, 'lang': lang},
      );
      final map = _decode(response.data);
      final items = (map['data'] as List?) ?? [];
      return items
          .map((e) => _toPost(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('🔥 [BlogApi] getFeatured: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<BlogPost?> getPost(String slugOrId, {String lang = 'tr'}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.blogPost(slugOrId),
        queryParameters: {'lang': lang},
      );
      final map = _decode(response.data);
      if (map['success'] != true || map['data'] == null) return null;
      return _toPost(map['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('🔥 [BlogApi] getPost: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<BlogCategory>> getCategories({String lang = 'tr'}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.blogCategories,
        queryParameters: {'lang': lang},
      );
      final map = _decode(response.data);
      final items = (map['data'] as List?) ?? [];
      return items
          .map((e) => BlogCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('🔥 [BlogApi] getCategories: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<BlogTag>> getTags({String lang = 'tr'}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.blogTags,
        queryParameters: {'lang': lang},
      );
      final map = _decode(response.data);
      final items = (map['data'] as List?) ?? [];
      return items
          .map((e) => BlogTag.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('🔥 [BlogApi] getTags: ${e.message}');
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<void> recordView(String id) async {
    try {
      await _client.post(ApiEndpoints.blogView(id));
    } on DioException catch (e) {
      // View kaydı best-effort — UI'ı kırmamalı.
      debugPrint('⚠️ [BlogApi] recordView failed: ${e.message}');
    }
  }
}

/// Provider — sbbMobilBackend (authApiClient).
final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  final client = ref.watch(authApiClientProvider);
  return ApiBlogRepository(client);
});
