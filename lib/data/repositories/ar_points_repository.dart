import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart' show ApiException;
import '../../api/endpoints.dart';
import '../../core/network/api_service.dart';
import '../../core/providers/locale_provider.dart';
import '../models/ar_point.dart';

/// backend_ar_todo.md AR2 — yakın çevredeki AR noktalarını getirir.
class ArPointsRepository {
  ArPointsRepository(this._dio, this._defaultLang);

  final Dio _dio;
  final String _defaultLang;

  /// `GET /api/v1/mobile/ar/points`
  ///
  /// [previewToken] backoffice'ten alınmış kısa süreli token; verilirse
  /// `is_preview = true` olan noktalar da response'a dahil olur (test cihazı
  /// senaryosu, §6.8.3.8).
  Future<ArPointsResult> fetchNearby({
    required double lat,
    required double lng,
    double radiusKm = 2.0,
    String? lang,
    String? previewToken,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.mobileArPoints,
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius_km': radiusKm,
          'lang': lang ?? _defaultLang,
          'preview_token': ?previewToken,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const ArPointsResult();
      }
      final payload = data['data'];
      List<ArPoint> points = const [];
      if (payload is Map<String, dynamic>) {
        final list = payload['points'];
        if (list is List) {
          points = list
              .whereType<Map<String, dynamic>>()
              .map(ArPoint.fromJson)
              .toList();
        }
      }
      final meta = data['meta'] is Map<String, dynamic>
          ? data['meta'] as Map<String, dynamic>
          : const <String, dynamic>{};
      return ArPointsResult(points: points, meta: meta);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

class ArPointsResult {
  const ArPointsResult({this.points = const [], this.meta = const {}});

  final List<ArPoint> points;
  final Map<String, dynamic> meta;

  bool get isEmpty => points.isEmpty;
  int get count => points.length;
  bool get preview => meta['preview'] == true;
}

final arPointsRepositoryProvider = Provider<ArPointsRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final lang = ref.watch(localeProvider).locale.languageCode;
  return ArPointsRepository(apiService.dio, lang);
});
