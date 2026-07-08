import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/cache/offline_cache_interceptor.dart';
import '../core/cache/offline_content_cache.dart';
import '../core/network/api_service.dart';
import '../core/providers/locale_provider.dart';
import '../core/network/app_user_agent.dart';
import '../core/network/auth_staff_api_config.dart';

/// API Client - Dio tabanlı HTTP client
/// JWT authentication, retry logic, locale support ve error handling içerir
class ApiClient {
  ApiClient._internal(this._dio, this._logger, this._languageCode);

  final Dio _dio;
  final Logger _logger;
  final String _languageCode;
  String? _jwtToken;

  /// Current language code
  String get languageCode => _languageCode;

  /// Factory with locale support
  factory ApiClient({
    required String baseUrl,
    required String languageCode,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Future<bool> Function()? onRefreshNeeded,
  }) {
    final logger = Logger(
      printer: PrettyPrinter(methodCount: 0, lineLength: 80),
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        // Release build için timeout'ları artır (yavaş ağlar için)
        connectTimeout: connectTimeout ?? const Duration(seconds: kDebugMode ? 10 : 15),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: kDebugMode ? 20 : 30),
        headers: {
          'Accept': 'application/json',
          'Accept-Language': languageCode,
          'User-Agent': buildSbbMobileUserAgent(),
        },
      ),
    );

    const storage = FlutterSecureStorage();

    // Locale interceptor - her isteğe lang parametresi ekle
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Query parametrelerine lang ekle (eğer yoksa)
          options.queryParameters = {
            ...options.queryParameters,
            'lang': languageCode,
          };

          // Attach the auth token dynamically
          try {
            final token = await storage.read(key: 'access_token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ [ApiClient] Error reading access_token: $e');
            }
          }

          return handler.next(options);
        },
      ),
    );

    // 401 → token refresh + retry. `onRefreshNeeded` provider tarafından
    // bağlanır (ApiService.refreshTokensExternal). Refresh başarılıysa aynı
    // isteği yeni token ile tekrarla; başarısızsa orijinal 401'i yukarı taşı.
    if (onRefreshNeeded != null) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onError: (error, handler) async {
            final opts = error.requestOptions;
            final isUnauthorized = error.response?.statusCode == 401;
            // Aynı isteği sonsuz kez retry etmesin
            final alreadyRetried = opts.extra['__refresh_retry__'] == true;

            if (!isUnauthorized || alreadyRetried) {
              return handler.next(error);
            }

            try {
              final ok = await onRefreshNeeded();
              if (!ok) {
                if (kDebugMode) {
                  debugPrint('🔓 [ApiClient] Refresh failed, propagating 401');
                }
                return handler.next(error);
              }
              // Yeni token storage'a yazıldı — header'ı güncelleyip retry
              final newToken = await storage.read(key: 'access_token');
              if (newToken != null) {
                opts.headers['Authorization'] = 'Bearer $newToken';
              }
              opts.extra['__refresh_retry__'] = true;
              if (kDebugMode) {
                debugPrint('🔄 [ApiClient] 401 → refreshed token, retrying ${opts.method} ${opts.path}');
              }
              final retryResponse = await dio.fetch(opts);
              return handler.resolve(retryResponse);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('⚠️ [ApiClient] Refresh-retry chain failed: $e');
              }
              return handler.next(error);
            }
          },
        ),
      );
    }

    // Geçici bağlantı hatalarında otomatik yeniden deneme (Connection refused, timeout)
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final opts = error.requestOptions;
          final retryCount = opts.extra['retry_count'] as int? ?? 0;
          const maxRetries = 2;
          final isRetryable = error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout;
          if (retryCount < maxRetries && isRetryable) {
            opts.extra['retry_count'] = retryCount + 1;
            if (kDebugMode) {
              debugPrint('🔄 [ApiClient] Retry ${retryCount + 1}/$maxRetries after ${error.type}');
            }
            await Future<void>.delayed(const Duration(milliseconds: 1500));
            try {
              final response = await dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(e is DioException ? e : DioException(requestOptions: opts, error: e));
            }
          }
          return handler.next(error);
        },
      ),
    );

    // Çevrimdışı içerik cache'i (§5.1.2 / §6.8.5) — retry interceptor'ından
    // SONRA eklenir ki onError yalnız retry'lar da tükendiğinde devreye girsin.
    // Başarılı GET'leri saklar, bağlantı koptuğunda cache'ten servis eder.
    dio.interceptors.add(
      OfflineCacheInterceptor(OfflineContentCache.instance),
    );

    // Logging interceptor (sadece debug mode'da) — compact format
    if (kDebugMode) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('🌐 [ApiClient] ${options.method} ${options.uri}');
            return handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint('✅ [ApiClient] ${response.statusCode} ${response.requestOptions.path}');
            
            if (response.data is String) {
              final dataStr = response.data as String;
              if (dataStr.trim().startsWith('<!DOCTYPE') || dataStr.trim().startsWith('<html')) {
                debugPrint('⚠️ [ApiClient] HTML response! URL: ${response.requestOptions.uri}');
              }
            }
            return handler.next(response);
          },
          onError: (error, handler) {
            debugPrint('❌ [ApiClient] ${error.response?.statusCode} ${error.requestOptions.path}: ${error.message}');
            
            if (error.response != null) {
              final response = error.response!;
              debugPrint('❌ [ApiClient] Content-Type: ${response.headers.value('content-type')}');
              debugPrint('❌ [ApiClient] Content-Encoding: ${response.headers.value('content-encoding')}');
              
              if (response.data != null) {
                try {
                  if (response.data is String) {
                    final str = response.data as String;
                    debugPrint('❌ [ApiClient] Response body (string, length=${str.length}): "$str"');
                    debugPrint('❌ [ApiClient] Response body bytes: ${str.codeUnits}');
                  } else {
                    debugPrint('❌ [ApiClient] Response body (type: ${response.data.runtimeType}): $response.data');
                  }
                } catch (e) {
                  debugPrint('❌ [ApiClient] Error parsing response body: $e');
                }
              }
            }
            
            return handler.next(error);
          },
        ),
      );
    }

    return ApiClient._internal(dio, logger, languageCode);
  }

  /// JWT token'ı set et
  void setToken(String token) {
    _jwtToken = token;
    _logger.i('🔑 JWT token set');
  }

  /// JWT token'ı temizle
  void clearToken() {
    _jwtToken = null;
    _logger.i('🔓 JWT token cleared');
  }

  /// Token var mı?
  bool get hasToken => _jwtToken != null;

  /// Dio instance'ını kapat (socket pool temizliği)
  /// Provider dispose olduğunda çağrılmalı
  void close() {
    _dio.close();
  }

  /// GET request
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
  }) async {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: _authOptions(requiresAuth: requiresAuth),
    );
  }

  /// POST request
  Future<Response<dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    bool requiresAuth = false,
  }) async {
    return _dio.post(
      path,
      data: data == null ? null : jsonEncode(data),
      options: _authOptions(
        requiresAuth: requiresAuth,
        contentType: 'application/json',
      ),
    );
  }

  /// PUT request
  Future<Response<dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
    bool requiresAuth = false,
  }) async {
    return _dio.put(
      path,
      data: data == null ? null : jsonEncode(data),
      options: _authOptions(
        requiresAuth: requiresAuth,
        contentType: 'application/json',
      ),
    );
  }

  /// DELETE request
  Future<Response<dynamic>> delete(
    String path, {
    Map<String, dynamic>? data,
    bool requiresAuth = false,
  }) async {
    return _dio.delete(
      path,
      data: data == null ? null : jsonEncode(data),
      options: _authOptions(
        requiresAuth: requiresAuth,
        contentType: 'application/json',
      ),
    );
  }

  /// Auth options builder
  Options _authOptions({
    String? contentType,
    bool requiresAuth = false,
  }) {
    // BaseOptions'taki header'ları koruyarak merge et
    final headers = <String, dynamic>{};

    if (_jwtToken != null) {
      headers['Authorization'] = 'Bearer $_jwtToken';
    } else if (requiresAuth) {
      _logger.w('⚠️ Auth required but no token set');
    }

    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }

    // BaseOptions'taki header'ları korumak için merge: false kullan
    // Dio otomatik olarak BaseOptions header'larını korur
    return Options(
      headers: headers,
      // BaseOptions header'larını koru
      followRedirects: true,
      // Sadece 2xx başarılı sayılır — 4xx hatalar DioException olarak fırlatılır
      // ve repository katmanında ApiException.fromDioError() ile handle edilir
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    );
  }
}

/// API Configuration
/// 
/// Environment seçimi: `--dart-define=ENVIRONMENT=dev|prod`
/// Base URL override: `--dart-define=API_BASE_URL=https://custom.api.com/v1`
/// 
/// Örnekler:
///   flutter run --dart-define=ENVIRONMENT=dev
///   flutter build apk --dart-define=ENVIRONMENT=prod
///   flutter run --dart-define=API_BASE_URL=https://staging.api.com/v1
class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// --dart-define ile gelen environment değeri
  static const _env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'prod');

  /// --dart-define ile gelen custom base URL (varsa config'i override eder)
  static const _customBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Development configuration (content API)
  /// Varsayılan olarak production ile aynı endpoint'i kullanır.
  /// Gerekirse --dart-define=API_BASE_URL=... ile override edebilirsiniz.
  static const _dev = ApiConfig(
    baseUrl: 'https://kesfetpanel.smartsamsun.com/api/v1',
  );

  /// Production configuration
  static const _prod = ApiConfig(
    baseUrl: 'https://kesfetpanel.smartsamsun.com/api/v1',
    connectTimeout: Duration(seconds: 15),
    receiveTimeout: Duration(seconds: 30),
  );

  /// Aktif konfigürasyon — environment'a göre otomatik seçilir.
  ///
  /// **Önemli:** Yerler, rotalar, etkinlikler, tarifler vb. içerik
  /// endpoint'leri **kesfetpanel.smartsamsun.com** içerik paneline gider.
  /// Heatmap gibi sadece Docker tarafında bulunan endpoint'ler ayrı bir
  /// client kullanır (bkz. `MapHeatmapRepository`).
  static ApiConfig get current {
    if (_customBaseUrl.isNotEmpty) {
      return ApiConfig(baseUrl: _customBaseUrl);
    }
    return _env == 'dev' ? _dev : _prod;
  }

  /// Geriye uyumluluk — mevcut kodda `ApiConfig.prod` kullanan yerler için
  static const prod = _prod;
  static const dev = _dev;
}

/// Auth API Configuration (Docker + NestJS)
///
/// Bu config sadece **kullanıcı yönetimi / auth** backend'i için kullanılır.
/// Varsayılan olarak Android emülatör senaryosuna göre ayarlı:
///   - Android Emülatör: http://10.0.2.2/
///
/// Diğer platformlar ve fiziksel cihazlar için:
///   `--dart-define=AUTH_API_BASE_URL=http://<BILGISAYAR_IP_ADRESI>/`
class AuthApiConfig {
  const AuthApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 5),
    this.receiveTimeout = const Duration(seconds: 3),
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// Aktif config (auth + staff aynı baseUrl üzerinden yönetilir).
  static AuthApiConfig get current =>
      AuthApiConfig(baseUrl: AuthStaffApiConfig.baseUrl);
}

/// API Client Provider - Locale-aware
/// Dil değiştiğinde otomatik olarak yeniden oluşturulur
final apiClientProvider = Provider<ApiClient>((ref) {
  // PERFORMANS: Sadece languageCode değiştiğinde client yeniden oluştur
  final languageCode = ref.watch(
    localeProvider.select((s) => s.locale.languageCode),
  );

  // `mobile_pending_changes.md` B2 — Background isolate (WorkManager) Riverpod
  // göremiyor; aktif dil tercihini SharedPreferences'a yazıyoruz ki geofence
  // worker doğru dilde bildirim üretebilsin.
  Future.microtask(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale_v1', languageCode);
    } catch (_) {}
  });

  // Environment'a göre config seç (--dart-define=ENVIRONMENT=dev|prod)
  final config = ApiConfig.current;

  debugPrint('🌍 [ApiClient] Creating new client with language: $languageCode');

  final client = ApiClient(
    baseUrl: config.baseUrl,
    languageCode: languageCode,
    connectTimeout: config.connectTimeout,
    receiveTimeout: config.receiveTimeout,
    // 401 alındığında ApiService'in refresh flow'unu paylaş — content API
    // (kesfetpanel) için auth API (NestJS) tarafından üretilen tokeni yenile,
    // sonra orijinal isteği retry et.
    onRefreshNeeded: () async {
      try {
        return await ref.read(apiServiceProvider).refreshTokensExternal();
      } catch (_) {
        return false;
      }
    },
  );

  // Locale değiştiğinde eski Dio instance'ının socket pool'unu kapat
  ref.onDispose(() {
    debugPrint('🧹 [ApiClient] Disposing old client (lang: $languageCode)');
    client.close();
  });

  return client;
});

/// Auth API Client Provider
///
/// Sadece Docker + NestJS tabanlı kullanıcı yönetimi (auth) backend'i için kullanılır.
/// Diğer tüm veri API'leri için `apiClientProvider` kullanılmaya devam eder.
final authApiClientProvider = Provider<ApiClient>((ref) {
  final languageCode = ref.watch(
    localeProvider.select((s) => s.locale.languageCode),
  );

  final config = AuthApiConfig.current;

  debugPrint('🌍 [AuthApiClient] Creating new auth client with language: $languageCode');

  final client = ApiClient(
    baseUrl: config.baseUrl,
    languageCode: languageCode,
    connectTimeout: config.connectTimeout,
    receiveTimeout: config.receiveTimeout,
  );

  ref.onDispose(() {
    debugPrint('🧹 [AuthApiClient] Disposing old auth client (lang: $languageCode)');
    client.close();
  });

  return client;
});

/// API Exception class
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.errors,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, List<String>>? errors;

  factory ApiException.fromDioError(DioException error) {
    if (error.response != null) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        // mobile_integ.md §0.2: backend zarfı `{ success, data, error?, message? }`.
        // `error` alanı ya tek satır mesaj ya da kısa kod (ör. `ORDER_MISMATCH`).
        // Mevcut `code` alanı geriye dönük uyumluluk için korunur.
        final errString = data['error'] as String?;
        return ApiException(
          message: data['message'] as String? ?? errString ?? 'Bir hata oluştu',
          code: data['code'] as String? ?? errString,
          statusCode: error.response?.statusCode,
          errors: (data['errors'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, List<String>.from(v as List)),
          ),
        );
      }
    }

    return ApiException(
      message: _getErrorMessage(error),
      statusCode: error.response?.statusCode,
    );
  }

  /// Bilinen backend kodlarına karşılık gelen sentinel değerler.
  /// Backend `error` alanı bu sabitlerden biri ise UI özel davranabilir.
  static const String codeOrderMismatch = 'ORDER_MISMATCH';
  static const String codeTooManyItems = 'TOO_MANY_ITEMS';

  /// `mobile_pending_changes.md` P0/4 — Backend `POINTS_FEATURE_ENABLED=false`
  /// olduğunda points/campaigns/achievements/visit/daily-login endpoint'leri
  /// `503 FEATURE_DISABLED` döner. UI bunu sessizce skip etmelidir.
  static const String codeFeatureDisabled = 'FEATURE_DISABLED';

  /// 503 + FEATURE_DISABLED (veya sadece 503) tespit edici.
  ///
  /// Bazı backend versiyonları `code/error` alanını set etmiyor — bu yüzden
  /// 503 status'unu da yeterli sayıyoruz (defensive).
  bool get isFeatureDisabled =>
      statusCode == 503 || code == codeFeatureDisabled;

  static String _getErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Bağlantı zaman aşımına uğradı';
      case DioExceptionType.sendTimeout:
        return 'İstek gönderme zaman aşımına uğradı';
      case DioExceptionType.receiveTimeout:
        return 'Yanıt alma zaman aşımına uğradı';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) return 'Oturum süresi doldu';
        if (statusCode == 403) return 'Bu işlem için yetkiniz yok';
        if (statusCode == 404) return 'İstenen kaynak bulunamadı';
        if (statusCode == 429) return 'Çok fazla istek gönderildi';
        if (statusCode != null && statusCode >= 500) return 'Sunucu hatası';
        return 'Bir hata oluştu';
      case DioExceptionType.cancel:
        return 'İstek iptal edildi';
      case DioExceptionType.connectionError:
        return 'İnternet bağlantısı yok';
      default:
        return 'Bir hata oluştu';
    }
  }

  @override
  String toString() => 'ApiException: $message (code: $code)';
}

/// `mobile_pending_changes.md` P0/4 — DioException üzerinden hızlı kontrol.
/// Repository katmanı henüz ApiException'a sarmalamadan 503'ü erken yakalamak
/// için kullanılır.
extension DioExceptionFeatureDisabled on DioException {
  bool get isFeatureDisabled {
    if (response?.statusCode == 503) return true;
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      final code = data['code'] ?? data['error'];
      if (code == ApiException.codeFeatureDisabled) return true;
    }
    return false;
  }
}
