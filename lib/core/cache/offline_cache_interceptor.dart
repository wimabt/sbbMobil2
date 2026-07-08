import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'offline_content_cache.dart';

/// §5.1.2 / §6.8.5 — "stale-on-error" çevrimdışı içerik interceptor'ı.
///
/// * Başarılı GET yanıtlarını [OfflineContentCache]'e yazar.
/// * İstek **bağlantı hatasıyla** başarısız olursa (retry'lar da tükendikten
///   sonra) daha önce önbelleğe alınmış yanıt varsa onu döndürür. Böylece
///   daha önce görüntülenen içerik internet olmadan da açılır.
///
/// Önbelleğe alınması istenmeyen istekler `options.extra['no_cache'] = true`
/// ile hariç tutulabilir.
class OfflineCacheInterceptor extends Interceptor {
  OfflineCacheInterceptor(this._cache);

  final OfflineContentCache _cache;

  bool _isCacheable(RequestOptions o) =>
      o.method.toUpperCase() == 'GET' && o.extra['no_cache'] != true;

  bool _isNetworkError(DioException err) =>
      err.type == DioExceptionType.connectionError ||
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.sendTimeout ||
      err.error is SocketException;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    final data = response.data;
    final code = response.statusCode ?? 0;
    final cacheableBody = data is Map || data is List;
    if (_isCacheable(o) && code >= 200 && code < 300 && cacheableBody) {
      // Fire-and-forget; yanıtı bloklamadan diske yaz.
      unawaited(_cache.store(
        url: o.uri.toString(),
        statusCode: code,
        data: data as Object,
      ));
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final o = err.requestOptions;
    if (_isCacheable(o) && _isNetworkError(err)) {
      final cached = await _cache.read(o.uri.toString());
      if (cached != null) {
        handler.resolve(Response<dynamic>(
          requestOptions: o,
          data: cached.data,
          statusCode: cached.statusCode,
          extra: {
            'fromOfflineCache': true,
            'cachedAt': cached.cachedAt.toIso8601String(),
          },
          headers: Headers.fromMap({
            'x-from-offline-cache': ['true'],
          }),
        ));
        return;
      }
    }
    handler.next(err);
  }
}
