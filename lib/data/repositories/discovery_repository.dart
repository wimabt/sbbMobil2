import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart' show ApiException;
import '../../api/endpoints.dart';
import '../../core/network/api_service.dart';
import '../../core/providers/locale_provider.dart';
import '../models/discovery_feed.dart';

/// mobile_integ.md §3 — Discovery feed repository.
///
/// Anonim çağrılarda token attach edilmez; auth varsa interceptor ekler.
/// 60 sn yerel mikro-cache (kullanıcı arka plana atıp geri dönerse).
class DiscoveryRepository {
  DiscoveryRepository(this._dio, this._defaultLang);

  final Dio _dio;
  final String _defaultLang;

  DateTime? _lastFetched;
  DiscoveryFeed? _cached;
  static const Duration _cacheTtl = Duration(seconds: 60);

  Future<DiscoveryFeed> fetchFeed({
    double? lat,
    double? lng,
    double radiusKm = 25,
    String? lang,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cached != null &&
        _lastFetched != null &&
        now.difference(_lastFetched!) < _cacheTtl) {
      return _cached!;
    }
    final query = <String, dynamic>{
      'lang': lang ?? _defaultLang,
      'radius_km': radiusKm,
      'lat': ?lat,
      'lng': ?lng,
    };
    try {
      final response = await _dio.get(
        ApiEndpoints.discoveryFeed,
        queryParameters: query,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final feed = DiscoveryFeed.fromJson(data);
        _cached = feed;
        _lastFetched = now;
        return feed;
      }
      throw const ApiException(message: 'Discovery feed response geçersiz');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  void invalidate() {
    _cached = null;
    _lastFetched = null;
  }
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final lang = ref.watch(localeProvider).locale.languageCode;
  return DiscoveryRepository(apiService.dio, lang);
});
