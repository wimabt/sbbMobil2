import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_locale.dart';
import 'app_user_agent.dart';
import 'auth_staff_api_config.dart';
import 'ssl_pinning.dart';

/// Backoffice/admin tarafındaki `requireCsrfHeader` middleware'i mutating isteklerde
/// bu header'ı bekler; yoksa 403 (CSRF) döner. Web admin paneli genelde otomatik gönderir.
const _kCsrfRequestedWithHeader = 'X-Requested-With';
const _kCsrfRequestedWithValue = 'XMLHttpRequest';

/// Secure API service for STAFF (backoffice + staff POS endpoints).
///
/// This is intentionally isolated from citizen OTP auth:
/// - uses separate secure-storage keys
/// - uses different auth endpoints:
///   - `/api/v1/backoffice/login`
///   - `/api/v1/backoffice/refresh`
class StaffApiService {
  /// Base URL for the backoffice/staff backend.
  ///
  /// Override at runtime:
  ///   --dart-define=STAFF_API_BASE_URL=https://...
  static String get baseUrl => AuthStaffApiConfig.baseUrl;

  static const _kAccessTokenKey = 'staff_access_token';
  static const _kRefreshTokenKey = 'staff_refresh_token';

  final Dio _dio;
  final FlutterSecureStorage _storage;

  final StreamController<void> _logoutController =
      StreamController<void>.broadcast();

  Stream<void> get onForcedLogout => _logoutController.stream;

  Dio get dio => _dio;

  Completer<void>? _refreshCompleter;

  StaffApiService({
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              _kCsrfRequestedWithHeader: _kCsrfRequestedWithValue,
              'User-Agent': buildSbbMobileUserAgent(),
            },
          ),
        ) {
    SslPinning.configureDio(_dio);

    if (kDebugMode) {
      debugPrint('ℹ️ [StaffApiService] baseUrl=$baseUrl');
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (kDebugMode) {
            debugPrint(
              '➡️ [StaffApiService] ${options.method} ${options.baseUrl}${options.path}',
            );
          }
          try {
            final token = await _storage.read(key: _kAccessTokenKey);
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
              if (kDebugMode) {
                final prefix = token.length <= 8
                    ? token
                    : token.substring(0, 8);
                debugPrint(
                  '🔑 [StaffApiService] Authorization attached (token prefix=$prefix...)',
                );
              }
            } else {
              if (kDebugMode) {
                debugPrint(
                  '⚠️ [StaffApiService] No staff access token in storage for request ${options.path}',
                );
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ [StaffApiService] Error reading token: $e');
            }
          }
          // Çift dilli: backoffice'e aktif dili bildir.
          try {
            final lang = await ActiveLocale.languageCode();
            options.headers['Accept-Language'] = lang;
            options.queryParameters = {
              ...options.queryParameters,
              if (!options.queryParameters.containsKey('lang')) 'lang': lang,
            };
          } catch (_) {}
          handler.next(options);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            debugPrint(
              '⬅️ [StaffApiService] ERROR ${error.response?.statusCode ?? '-'} '
              '${error.requestOptions.method} ${error.requestOptions.baseUrl}${error.requestOptions.path} '
              'type=${error.type} msg=${error.message}',
            );
          }
          final statusCode = error.response?.statusCode;
          if (statusCode == 401 && !_isRefreshRequest(error.requestOptions)) {
            final handled = await _handleUnauthorized(error, handler);
            if (handled) return;
          }
          handler.next(error);
        },
      ),
    );
  }

  bool _isRefreshRequest(RequestOptions request) {
    return request.path.contains('/api/v1/backoffice/refresh');
  }

  Future<bool> _handleUnauthorized(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    // If offline, don't force logout.
    try {
      final results = await Connectivity().checkConnectivity();
      final isOffline =
          results.isEmpty || results.contains(ConnectivityResult.none);
      if (isOffline) {
        handler.next(error);
        return true;
      }
    } catch (_) {}

    // Keep a local reference so we can await safely even if the field is nulled.
    final completer = _refreshCompleter ??= Completer<void>();
    final isLeader = completer == _refreshCompleter && !completer.isCompleted;

    if (isLeader) {
      try {
        final refreshed = await refreshTokens();
        if (refreshed) {
          completer.complete();
        } else {
          completer.completeError(Exception('Refresh failed'));
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      } finally {
        unawaited(completer.future.catchError((_) {}));
        if (identical(_refreshCompleter, completer)) {
          _refreshCompleter = null;
        }
      }
    }

    try {
      await completer.future;
    } catch (_) {
      await _handleForceLogout();
      handler.next(error);
      return true;
    }

    try {
      final token = await _storage.read(key: _kAccessTokenKey);
      if (token == null) {
        await _handleForceLogout();
        handler.next(error);
        return true;
      }

      final requestOptions = error.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $token';
      final cloneResponse = await _dio.fetch(requestOptions);
      handler.resolve(cloneResponse);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '🔥 [StaffApiService] Error retrying request after refresh: $e',
        );
      }
      await _handleForceLogout();
      handler.next(error);
      return true;
    }
  }

  // ─── Auth (Backoffice) ────────────────────────────────────────────

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post(
      '/api/v1/backoffice/login',
      data: <String, dynamic>{
        'username': username,
        'password': password,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final success = data['success'] == true;

    // Try body first, then headers (including set-cookie)
    final bodyTokens = _extractTokens(data);
    final headerTokens =
        success ? _extractTokensFromHeaders(response.headers) : null;
    final effectiveTokens = bodyTokens ?? headerTokens;

    if (success && effectiveTokens != null) {
      if (kDebugMode) {
        debugPrint(
          '🔐 [StaffApiService] login success — extracted tokens: '
          'access=${effectiveTokens['access_token'] != null}, '
          'refresh=${effectiveTokens['refresh_token'] != null} '
          '(source=${bodyTokens != null ? 'body' : 'headers/cookies'})',
        );
      }
      await _saveTokens(effectiveTokens);
    } else {
      if (kDebugMode) {
        debugPrint(
          '⚠️ [StaffApiService] login success=$success but tokens extraction failed. '
          'Top-level keys=${data.keys.toList()}',
        );
        if (data['tokens'] is Map) {
          debugPrint(
            '⚠️ [StaffApiService] tokens keys=${(data['tokens'] as Map).keys.toList()}',
          );
        }
        final cookies = response.headers.map['set-cookie'];
        if (cookies != null) {
          final parsed = _parseCookies(cookies);
          debugPrint(
            '⚠️ [StaffApiService] set-cookie cookie names=${parsed.keys.toList()}, '
            'values preview=${parsed.entries.map((e) => '${e.key}=${e.value.length > 20 ? '${e.value.substring(0, 20)}...' : e.value}').toList()}',
          );
        } else {
          debugPrint('⚠️ [StaffApiService] No set-cookie header found');
        }
        debugPrint(
          '⚠️ [StaffApiService] response header keys='
          '${response.headers.map.keys.toList()}',
        );
      }
    }
    return data;
  }

  Future<bool> refreshTokens() async {
    try {
      final refreshToken = await _storage.read(key: _kRefreshTokenKey);
      if (refreshToken == null) return false;

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            _kCsrfRequestedWithHeader: _kCsrfRequestedWithValue,
            'User-Agent': buildSbbMobileUserAgent(),
          },
        ),
      );
      SslPinning.configureDio(refreshDio);

      final response = await refreshDio.post(
        '/api/v1/backoffice/refresh',
        data: <String, dynamic>{'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) return false;

      final bodyTokens = _extractTokens(data);
      final headerTokens = _extractTokensFromHeaders(response.headers);
      final effectiveTokens = bodyTokens ?? headerTokens;

      if (effectiveTokens != null) {
        await _saveTokens(effectiveTokens);
        return true;
      }
      if (kDebugMode) {
        debugPrint('⚠️ [StaffApiService] refreshTokens: no tokens found in body or cookies');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 [StaffApiService] refreshTokens exception: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>> getBackofficeMe() async {
    final response = await _dio.get('/api/v1/backoffice/me');
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/v1/backoffice/logout — revokes refresh token server-side.
  Future<void> logout() async {
    try {
      await _dio.post('/api/v1/backoffice/logout');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [StaffApiService] logout request failed (ignoring): $e');
      }
    } finally {
      await _clearTokens();
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _kAccessTokenKey);
    return token != null;
  }

  // ─── Staff POS endpoints ──────────────────────────────────────────

  Future<Map<String, dynamic>> getStaffProfile() async {
    final response = await _dio.get('/api/v1/staff/profile');
    return response.data as Map<String, dynamic>;
  }

  /// Personele atanmış tesisler ([pos_new.md] §3.1).
  Future<Map<String, dynamic>> getStaffFacilities() async {
    final response = await _dio.get('/api/v1/staff/facilities');
    return response.data as Map<String, dynamic>;
  }

  /// [facilityId] çoklu tesis atamasında zorunlu ([pos_new.md] §3.2).
  Future<Map<String, dynamic>> getPosMenu({String? facilityId}) async {
    final response = await _dio.get(
      '/api/v1/staff/pos/menu',
      queryParameters: <String, dynamic>{
        if (facilityId != null && facilityId.isNotEmpty)
          'facility_id': facilityId,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> validateTokenOrCode({
    required String tokenOrCode,
    int? requestedAmount,
  }) async {
    final response = await _dio.post(
      '/api/v1/staff/pos/validate',
      data: <String, dynamic>{
        'token_or_code': tokenOrCode,
        'requested_amount': ?requestedAmount,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkout({
    required String tokenOrCode,
    required List<Map<String, dynamic>> items,
    required int manualAmount,
    String? facilityId,
  }) async {
    final response = await _dio.post(
      '/api/v1/staff/pos/checkout',
      data: <String, dynamic>{
        'token_or_code': tokenOrCode,
        'items': items,
        'manual_amount': manualAmount,
        if (facilityId != null && facilityId.isNotEmpty) 'facility_id': facilityId,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTransactions({
    required int page,
    required int limit,
  }) async {
    final response = await _dio.get(
      '/api/v1/staff/transactions',
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ─── Citizen QR endpoints (called from citizen side) ─────────────

  /// POST /api/v1/mobile/wallet/generate-qr — one-shot 60-second QR.
  Future<Map<String, dynamic>> generateQr() async {
    final response = await _dio.post('/api/v1/mobile/wallet/generate-qr');
    return response.data as Map<String, dynamic>;
  }

  /// GET /api/v1/mobile/qr/generate — polling alternative (every 10s).
  Future<Map<String, dynamic>> pollQr() async {
    final response = await _dio.get('/api/v1/mobile/qr/generate');
    return response.data as Map<String, dynamic>;
  }

  /// DELETE /api/v1/mobile/qr/session — close QR session on exit.
  Future<void> closeQrSession() async {
    try {
      await _dio.delete('/api/v1/mobile/qr/session');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [StaffApiService] closeQrSession failed (ignoring): $e');
      }
    }
  }

  // ─── Token persistence ────────────────────────────────────────────

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final accessToken = data['access_token']?.toString();
    final refreshToken = data['refresh_token']?.toString();
    if (accessToken != null) {
      await _storage.write(key: _kAccessTokenKey, value: accessToken);
    }
    if (refreshToken != null) {
      await _storage.write(key: _kRefreshTokenKey, value: refreshToken);
    }
  }

  /// Backoffice login responses can be slightly different between environments.
  /// Docs say `tokens` is at top-level, but we accept a few nested variants too.
  Map<String, dynamic>? _extractTokens(Map<String, dynamic> data) {
    // 1) tokens: { access_token, refresh_token }
    final topTokens = data['tokens'];
    if (topTokens is Map<String, dynamic>) {
      final normalized = _normalizeTokens(topTokens);
      if (normalized.isNotEmpty) return normalized;
    }

    // 2) access_token/refresh_token direkt top-level
    final directAccess = data['access_token'] ?? data['accessToken'];
    final directRefresh = data['refresh_token'] ?? data['refreshToken'];
    if (directAccess != null || directRefresh != null) {
      return <String, dynamic>{
        'access_token': directAccess?.toString(),
        'refresh_token': directRefresh?.toString(),
      }..removeWhere((k, v) => v == null);
    }

    // 3) common nested variant: data: { tokens: {...} }
    final nested = data['data'];
    if (nested is Map<String, dynamic>) {
      final nestedTokens = nested['tokens'];
      if (nestedTokens is Map<String, dynamic>) {
        final normalized = _normalizeTokens(nestedTokens);
        if (normalized.isNotEmpty) return normalized;
      }

      final maybeNestedData = nested['data'];
      if (maybeNestedData is Map<String, dynamic>) {
        final nested2Tokens = maybeNestedData['tokens'];
        if (nested2Tokens is Map<String, dynamic>) {
          final normalized = _normalizeTokens(nested2Tokens);
          if (normalized.isNotEmpty) return normalized;
        }
      }
    }

    // 4) fallback: recursively search for token keys anywhere
    final access = _findFirstStringByKeys(
      data,
      const {
        'access_token',
        'accessToken',
        'access',
        'jwt',
        'token',
      },
    );
    final refresh = _findFirstStringByKeys(
      data,
      const {
        'refresh_token',
        'refreshToken',
        'refresh',
      },
    );

    final tokens = <String, dynamic>{
      'access_token': ?access,
      'refresh_token': ?refresh,
    };
    if (tokens.isEmpty) return null;
    return tokens;
  }

  /// Attempt to extract access/refresh tokens from response headers.
  /// Checks Authorization header, custom headers, and **set-cookie**.
  Map<String, dynamic>? _extractTokensFromHeaders(Headers headers) {
    // 1) Authorization: Bearer <access>
    final auth =
        headers.value('authorization') ?? headers.value('Authorization');
    String? access = auth != null && auth.toLowerCase().startsWith('bearer ')
        ? auth.substring('bearer '.length).trim()
        : null;

    // 2) X-Refresh-Token header
    String? refresh = (headers.value('x-refresh-token') ??
            headers.value('X-Refresh-Token') ??
            headers.value('x-refresh') ??
            headers.value('X-Refresh'))
        ?.toString();

    // 3) set-cookie — many Node.js backends (express, helmet) send tokens here
    if (access == null || refresh == null) {
      final cookies = headers.map['set-cookie'];
      if (cookies != null && cookies.isNotEmpty) {
        final parsed = _parseCookies(cookies);
        if (kDebugMode) {
          debugPrint(
            '🍪 [StaffApiService] set-cookie keys=${parsed.keys.toList()}',
          );
        }
        access ??= parsed['access_token'] ??
            parsed['accessToken'] ??
            parsed['backoffice_access_token'] ??
            parsed['token'] ??
            parsed['jwt'];
        refresh ??= parsed['refresh_token'] ??
            parsed['refreshToken'] ??
            parsed['backoffice_refresh_token'];
      }
    }

    if (access == null && refresh == null) return null;

    return <String, dynamic>{
      'access_token': ?access,
      'refresh_token': ?refresh,
    };
  }

  /// Parse a list of raw `set-cookie` header values into a name→value map.
  /// Each entry looks like: `name=value; Path=/; HttpOnly; ...`
  Map<String, String> _parseCookies(List<String> rawCookies) {
    final result = <String, String>{};
    for (final raw in rawCookies) {
      final parts = raw.split(';');
      if (parts.isEmpty) continue;
      final nameValue = parts.first.trim();
      final eqIdx = nameValue.indexOf('=');
      if (eqIdx <= 0) continue;
      final name = nameValue.substring(0, eqIdx).trim();
      final value = nameValue.substring(eqIdx + 1).trim();
      if (value.isNotEmpty) {
        result[name] = value;
      }
    }
    return result;
  }

  Map<String, dynamic> _normalizeTokens(Map<String, dynamic> tokens) {
    final access =
        tokens['access_token'] ??
        tokens['accessToken'] ??
        tokens['access'] ??
        tokens['jwt'] ??
        tokens['token'];
    final refresh =
        tokens['refresh_token'] ??
        tokens['refreshToken'] ??
        tokens['refresh'];

    return <String, dynamic>{
      'access_token': access?.toString(),
      'refresh_token': refresh?.toString(),
    }..removeWhere((k, v) => v == null);
  }

  /// Recursively find the first string value for any of [keys] within [obj].
  /// Used to handle slight backend response shape differences.
  String? _findFirstStringByKeys(Object? obj, Set<String> keys) {
    if (obj == null) return null;

    if (obj is Map) {
      for (final k in keys) {
        final v = obj[k];
        if (v != null) return v.toString();
      }
      for (final v in obj.values) {
        final found = _findFirstStringByKeys(v, keys);
        if (found != null) return found;
      }
      return null;
    }

    if (obj is List) {
      for (final v in obj) {
        final found = _findFirstStringByKeys(v, keys);
        if (found != null) return found;
      }
    }

    return null;
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: _kAccessTokenKey);
    await _storage.delete(key: _kRefreshTokenKey);
  }

  Future<void> _handleForceLogout() async {
    await _clearTokens();
    if (!_logoutController.isClosed) {
      _logoutController.add(null);
    }
  }

  Future<void> dispose() async {
    await _logoutController.close();
  }
}

final staffApiServiceProvider = Provider<StaffApiService>((ref) {
  final service = StaffApiService();
  ref.onDispose(service.dispose);
  return service;
});

