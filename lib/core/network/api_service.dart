import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_locale.dart';
import 'app_user_agent.dart';
import 'auth_staff_api_config.dart';
import 'ssl_pinning.dart';

/// Secure API service for the Fintech Auth backend.
///
/// - Handles OTP auth (`send-otp`, `verify-otp`)
/// - Manages access + refresh tokens in FlutterSecureStorage
/// - Automatically attaches Authorization header
/// - On 401, tries `POST /api/v1/auth/refresh` with token rotation
/// - If refresh fails, clears storage and emits a logout event
class ApiService {
  /// Base URL for the NestJS auth backend.
  ///
  /// Defaults to Android emulator IP, but can be overridden at runtime:
  ///   `--dart-define=AUTH_API_BASE_URL=http://<BILGISAYAR_IP_ADRESI>`
  static String get baseUrl => AuthStaffApiConfig.baseUrl;

  static const _kAccessTokenKey = 'access_token';
  static const _kRefreshTokenKey = 'refresh_token';
  static const _kPhoneNumberKey = 'user_phone_number';

  final Dio _dio;
  final FlutterSecureStorage _storage;

  /// Emits an event when a terminal auth failure occurs (refresh token invalid/expired).
  final StreamController<void> _logoutController =
      StreamController<void>.broadcast();

  /// Stream that can be listened to by Auth layer to react to forced logout.
  Stream<void> get onForcedLogout => _logoutController.stream;

  /// Exposes the internal Dio instance (with auth interceptors) for
  /// other services (e.g. DiscoveryService) that need authenticated requests.
  Dio get dio => _dio;

  /// Single-flight refresh controller to pause concurrent 401 requests
  /// while a refresh is in progress. §2.3: Tek refresh denemesi —
  /// başarısız olursa login'e yönlendir (sonsuz döngü engeli).
  Completer<void>? _refreshCompleter;

  /// §2.8.3: Proaktif token refresh timer'ı — access token süresi dolmadan
  /// 1 dakika önce yenileme yapar.
  Timer? _proactiveRefreshTimer;

  ApiService({
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': buildSbbMobileUserAgent(),
            },
          ),
        ) {
    if (kDebugMode) {
      debugPrint('🌐 [ApiService] baseUrl = $baseUrl');
    }
    // Security: SSL certificate pinning (if HTTPS + pins configured)
    SslPinning.configureDio(_dio);

    // Debug-only istek/yanıt loglama. mobil.smartsamsun.com'a gerçekten
    // ulaşıp ulaşmadığımızı, hangi URL'yi vurduğumuzu konsoldan izlemek için.
    if (kDebugMode) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint(
              '➡️  [ApiService] ${options.method} ${options.uri}',
            );
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
              '✅ [ApiService] ${response.statusCode} ${response.requestOptions.uri}',
            );
            handler.next(response);
          },
          onError: (error, handler) {
            debugPrint(
              '❌ [ApiService] ${error.type.name} ${error.requestOptions.uri} '
              '→ status=${error.response?.statusCode} '
              'msg=${error.message}',
            );
            handler.next(error);
          },
        ),
      );
    }

    // Interceptor: automatic token attachment + 401 handling
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await _storage.read(key: _kAccessTokenKey);
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ [ApiService] Error reading token: $e');
            }
          }
          // Çift dilli: backoffice backend'e aktif dili bildir (Accept-Language
          // + ?lang=). Aksi halde profil/puan/rozet verisi her zaman TR döner.
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
          final statusCode = error.response?.statusCode;

          // §2.2: 429 — rate limit. Otomatik retry YAPMA, hatayı doğrudan ilet.
          if (statusCode == 429) {
            if (kDebugMode) {
              debugPrint(
                '⚠️ [ApiService] 429 Rate Limited: ${error.requestOptions.path}',
              );
            }
            handler.next(error);
            return;
          }

          // Only handle 401 from non-refresh endpoints
          if (statusCode == 401 && !_isRefreshRequest(error.requestOptions)) {
            final handled = await _handleUnauthorized(error, handler);
            if (handled) {
              return;
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Determines if the request is the refresh-token call itself.
  bool _isRefreshRequest(RequestOptions request) {
    return request.path.contains('/api/v1/auth/refresh');
  }

  /// Centralized 401 handling with request "pausing" and token rotation.
  ///
  /// - Ensures only one refresh runs at a time
  /// - Other 401 requests wait for the refresh to complete
  /// - On success, retries the failed request with new access token
  /// - On failure, clears tokens and emits logout event
  ///
  /// ÖNEMLİ: Önce bağlantı kontrolü yapılır. Geçici ağ kesintisi
  /// varsa (tünel, asansör vb.) kullanıcı zorla çıkış yapılmaz.
  Future<bool> _handleUnauthorized(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    // GÜVENLİK: 401 öncesinde bağlantı kontrolü.
    // Cihaz offline ise auth sorunu değil ağ sorunu — zorla çıkış yapma.
    try {
      final results = await Connectivity().checkConnectivity();
      final isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
      if (isOffline) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ [ApiService] 401 alındı ama cihaz offline — '
            'zorla çıkış yapılmıyor, istek kuyruğa alınıyor.',
          );
        }
        handler.next(error);
        return true;
      }
    } catch (_) {
      // Bağlantı kontrolü hata verirse normal akışa devam et
    }

    // Lazily create a shared refresh completer if not already refreshing.
    // Keep a local reference so we can await safely even if the field is nulled.
    final completer = _refreshCompleter ??= Completer<void>();

    // Only the "leader" actually performs the refresh.
    final isLeader = completer == _refreshCompleter && !completer.isCompleted;

    if (isLeader) {
      try {
        final refreshed = await _tryRefreshToken();
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
        // Allow a new refresh cycle after current completer finishes.
        unawaited(completer.future.catchError((_) {}));
        if (identical(_refreshCompleter, completer)) {
          _refreshCompleter = null;
        }
      }
    }

    try {
      // All 401 requests wait here until refresh completes
      await completer.future;
    } catch (_) {
      // Refresh failed → hard logout
      await _handleForceLogout();
      handler.next(error);
      return true;
    }

    // Refresh succeeded → retry original request with new access token
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
        debugPrint('🔥 [ApiService] Error retrying request after refresh: $e');
      }
      await _handleForceLogout();
      handler.next(error);
      return true;
    }
  }

  // ─── Auth Methods ────────────────────────────────────────────────

  /// Send OTP to the given phone number.
  ///
  /// [type]: `"login"` = giriş ekranı (kayıtlı olmayan numara reddedilir),
  ///         `"register"` = kayıt ekranı (yeni kullanıcı için OTP).
  Future<Map<String, dynamic>> sendOtp(
    String phoneNumber, {
    String type = 'login',
    String? email,
  }) async {
    final trimmedEmail = email?.trim();
    final response = await _dio.post(
      '/api/v1/auth/send-otp',
      data: <String, dynamic>{
        'phone_number': phoneNumber,
        'type': type,
        // Kayıt akışında e-postayı erken gönder: backend, e-posta başka bir
        // hesapta doğrulanmışsa OTP'ye geçmeden uyarabilsin.
        if (trimmedEmail != null && trimmedEmail.isNotEmpty) 'email': trimmedEmail,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Verify OTP (giriş akışı) → receives tokens + user and persists tokens.
  ///
  /// [restore] true ise: backend pending hesabı geri alır (silinmek üzere
  /// işaretlenmişse). Bu flag ilk verify 409 ACCOUNT_DELETION_PENDING
  /// döndükten sonra kullanıcı "Geri Al" seçince ikinci çağrıda set edilir.
  Future<Map<String, dynamic>> verifyOtp(
    String phoneNumber,
    String otp, {
    bool restore = false,
  }) async {
    final response = await _dio.post(
      '/api/v1/auth/verify-otp',
      data: <String, dynamic>{
        'phone_number': phoneNumber,
        'otp': otp,
        if (restore) 'restore': true,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true && data['tokens'] is Map<String, dynamic>) {
      await _saveTokens(data['tokens'] as Map<String, dynamic>);
    }
    return data;
  }

  /// Register (kayıt akışı) → send-otp(type:register) sonrası OTP ile kayıt.
  /// first_name ve last_name zorunlu.
  Future<Map<String, dynamic>> register({
    required String phoneNumber,
    required String otp,
    required String firstName,
    required String lastName,
    String? email,
  }) async {
    final response = await _dio.post(
      '/api/v1/auth/register',
      data: <String, dynamic>{
        'phone_number': phoneNumber,
        'otp': otp,
        'first_name': firstName,
        'last_name': lastName,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true && data['tokens'] is Map<String, dynamic>) {
      await _saveTokens(data['tokens'] as Map<String, dynamic>);
    }
    return data;
  }

  /// Fetch authenticated user profile.
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/api/v1/auth/me');
    return response.data as Map<String, dynamic>;
  }

  // ════════════════════════════════════════════════════════════════════
  // Hesap iletişim bilgisi yönetimi — e-posta doğrulama + e-posta/telefon
  // değiştirme. Sözleşme: account_contact_change_backend_todo.md
  //
  // Çapraz kilit güvenlik modeli:
  //   • Telefon işlemleri step-up'ı  → DOĞRULANMIŞ E-POSTAYA kod
  //   • E-posta işlemleri step-up'ı  → MEVCUT TELEFONA OTP
  // Step-up doğrulanınca backend kısa ömürlü, tek kullanımlık bir
  // "sensitive-action token" döner. Sonraki set-new/confirm çağrıları bu
  // token'ı `X-Sensitive-Action` header'ında taşır (access-token'ın
  // Authorization header'ından ayrı tutulur).
  // ════════════════════════════════════════════════════════════════════

  static const _kSensitiveActionHeader = 'X-Sensitive-Action';

  Options _sensitiveOpts(String token) =>
      Options(headers: <String, String>{_kSensitiveActionHeader: token});

  // ── FAZ 1: Mevcut e-postayı doğrula (step-up yok; kanal zaten e-postanın kendisi) ──

  /// Mevcut (doğrulanmamış) e-postaya 6 haneli doğrulama kodu gönderir.
  Future<Map<String, dynamic>> startEmailVerification() async {
    final r = await _dio.post('/api/v1/user/email/verify/start');
    return r.data as Map<String, dynamic>;
  }

  /// E-postaya gelen kodu doğrular → `email_verified = true`.
  Future<Map<String, dynamic>> confirmEmailVerification(String code) async {
    final r = await _dio.post(
      '/api/v1/user/email/verify/confirm',
      data: <String, dynamic>{'code': code},
    );
    return r.data as Map<String, dynamic>;
  }

  // ── FAZ 2: E-posta değiştirme / ekleme (4 adım) ──
  // E-postası olmayan (legacy) kullanıcı için de aynı akış: backend "mevcut
  // e-posta yok" durumunu ekleme gibi ele alır.

  /// Step-up başlat: mevcut telefona OTP gönderir.
  Future<Map<String, dynamic>> startEmailChange() async {
    final r = await _dio.post('/api/v1/user/account/change-email/start');
    return r.data as Map<String, dynamic>;
  }

  /// Telefon OTP'sini doğrula → sensitive-action token döner (`data.token`).
  Future<Map<String, dynamic>> verifyEmailChangeStepup(String otp) async {
    final r = await _dio.post(
      '/api/v1/user/account/change-email/verify-stepup',
      data: <String, dynamic>{'otp': otp},
    );
    return r.data as Map<String, dynamic>;
  }

  /// Yeni e-postayı bildir → yeni adrese doğrulama kodu gönderilir.
  ///
  /// [confirmClaim] true: e-posta başka bir hesapta DOĞRULANMAMIŞ olarak
  /// kayıtlıysa, kullanıcı "doğrulayarak bu hesaba bağla" onayını verdi demektir
  /// (backend `EMAIL_CLAIM_CONFIRM` döndükten sonra ikinci çağrı).
  Future<Map<String, dynamic>> setNewEmail(
    String newEmail, {
    required String sensitiveToken,
    bool confirmClaim = false,
  }) async {
    final r = await _dio.post(
      '/api/v1/user/account/change-email/set-new',
      data: <String, dynamic>{
        'new_email': newEmail,
        if (confirmClaim) 'confirm_claim': true,
      },
      options: _sensitiveOpts(sensitiveToken),
    );
    return r.data as Map<String, dynamic>;
  }

  /// Yeni e-postaya gelen kodu doğrula → e-posta güncellenir + `email_verified=true`.
  Future<Map<String, dynamic>> confirmEmailChange(
    String code, {
    required String sensitiveToken,
  }) async {
    final r = await _dio.post(
      '/api/v1/user/account/change-email/confirm',
      data: <String, dynamic>{'code': code},
      options: _sensitiveOpts(sensitiveToken),
    );
    return r.data as Map<String, dynamic>;
  }

  // ── FAZ 3: Telefon değiştirme (4 adım, doğrulanmış e-posta gerektirir) ──

  /// Step-up başlat: doğrulanmış e-postaya kod gönderir.
  /// Doğrulanmış e-posta yoksa backend `409 EMAIL_REQUIRED_FIRST` döner.
  Future<Map<String, dynamic>> startPhoneChange() async {
    final r = await _dio.post('/api/v1/user/account/change-phone/start');
    return r.data as Map<String, dynamic>;
  }

  /// E-postaya gelen step-up kodunu doğrula → sensitive-action token döner.
  Future<Map<String, dynamic>> verifyPhoneChangeStepup(String code) async {
    final r = await _dio.post(
      '/api/v1/user/account/change-phone/verify-stepup',
      data: <String, dynamic>{'code': code},
    );
    return r.data as Map<String, dynamic>;
  }

  /// Yeni telefonu bildir → yeni numaraya OTP gönderilir.
  Future<Map<String, dynamic>> setNewPhone(
    String newPhone, {
    required String sensitiveToken,
  }) async {
    final r = await _dio.post(
      '/api/v1/user/account/change-phone/set-new',
      data: <String, dynamic>{'new_phone': newPhone},
      options: _sensitiveOpts(sensitiveToken),
    );
    return r.data as Map<String, dynamic>;
  }

  /// Yeni telefona gelen OTP'yi doğrula → numara güncellenir, diğer cihazların
  /// oturumları backend tarafından iptal edilir (mevcut cihaz hariç).
  Future<Map<String, dynamic>> confirmPhoneChange(
    String otp, {
    required String sensitiveToken,
  }) async {
    final r = await _dio.post(
      '/api/v1/user/account/change-phone/confirm',
      data: <String, dynamic>{'otp': otp},
      options: _sensitiveOpts(sensitiveToken),
    );
    final data = r.data as Map<String, dynamic>;
    // K3: Numara değişiminde backend diğer tüm oturumları iptal eder ve mevcut
    // cihaza taze bir token çifti döner. Bunları kaydetmezsek mevcut cihaz da
    // bir sonraki istekte düşer. Eski access token süresi dolana dek çalışsa da
    // refresh token iptal edildiği için yenileme başarısız olurdu.
    if (data['tokens'] is Map<String, dynamic>) {
      await _saveTokens(data['tokens'] as Map<String, dynamic>);
    }
    return data;
  }

  /// Notify backend to revoke the session. Does **not** clear local storage;
  /// [AuthNotifier] calls [clearLocalAuthData] as part of unified logout cleanup.
  Future<void> logout() async {
    try {
      await _dio.post('/api/v1/auth/logout');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ApiService] Logout request failed: $e');
      }
    }
  }

  /// Hesap silme — KVKK §14.4.2 ve App Store 5.1.1 zorunluluğu.
  ///
  /// Backend `DELETE /api/v1/user/account` 200 + soft-delete metadata döner:
  /// ```json
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "deleted_at": "2026-05-25T...",
  ///     "restore_deadline": "2026-06-24T...",
  ///     "days_remaining": 30,
  ///     "message": "Hesabınız silinmek üzere işaretlendi..."
  ///   }
  /// }
  /// ```
  ///
  /// 30 günlük geri alma penceresi: bu süre içinde aynı telefonla login
  /// olunursa OTP verify 409 ACCOUNT_DELETION_PENDING döner; mobile
  /// `restore: true` flag'i ile yeniden verify çağırır ve hesap geri gelir.
  Future<DeleteAccountResult> deleteAccount({String? reason}) async {
    try {
      final response = await _dio.delete(
        '/api/v1/user/account',
        data: reason == null ? null : {'reason': reason},
      );
      final data = response.data;
      String? message;
      int? daysRemaining;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          message = payload['message'] as String?;
          daysRemaining = (payload['days_remaining'] as num?)?.toInt();
        }
      }
      return DeleteAccountResult.success(
        message: message,
        daysRemaining: daysRemaining,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ [ApiService] Account deletion failed: '
          'status=${e.response?.statusCode} msg=${e.message}',
        );
      }
      final data = e.response?.data;
      String? errorMsg;
      if (data is Map<String, dynamic>) {
        errorMsg = (data['message'] ?? data['error']) as String?;
      }
      return DeleteAccountResult.failure(errorMessage: errorMsg);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ApiService] Account deletion error: $e');
      }
      return DeleteAccountResult.failure();
    }
  }

  /// Pending hesap durumu — `GET /api/v1/user/account/status`.
  /// Eğer kullanıcı silme talep ettiyse `pending: true` + `days_remaining` döner.
  /// Cold start'ta çağrılır → home'da banner gösterilir.
  Future<AccountStatusResult?> fetchAccountStatus() async {
    try {
      final response = await _dio.get('/api/v1/user/account/status');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = (data['data'] is Map<String, dynamic>)
            ? data['data'] as Map<String, dynamic>
            : data;
        return AccountStatusResult(
          isPending: payload['pending'] == true,
          daysRemaining: (payload['days_remaining'] as num?)?.toInt(),
          deletionRequestedAt: payload['deletion_requested_at'] as String?,
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ApiService] fetchAccountStatus failed: $e');
      }
      return null;
    }
  }

  /// `POST /api/v1/user/account/restore` — pending durumdaki hesabı geri alır.
  /// Mevcut token ile çağrılır (silme öncesi token hâlâ geçerli).
  Future<bool> restoreAccount() async {
    try {
      await _dio.post('/api/v1/user/account/restore');
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ApiService] restoreAccount failed: $e');
      }
      return false;
    }
  }

  /// Clears access/refresh tokens and related keys from secure storage.
  Future<void> clearLocalAuthData() async {
    await _clearTokens();
  }

  // ─── Secure Phone Number Storage (§2.5) ─────────────────────────

  /// Kullanıcının girdiği tam telefon numarasını güvenli depoya kaydet.
  /// Backend artık tam numara döndürmediği için OTP akışında kullanılır.
  Future<void> savePhoneNumber(String phoneNumber) async {
    await _storage.write(key: _kPhoneNumberKey, value: phoneNumber);
  }

  /// Güvenli depodan tam telefon numarasını oku.
  Future<String?> getPhoneNumber() async {
    return _storage.read(key: _kPhoneNumberKey);
  }

  // ─── Token Management ────────────────────────────────────────────

  Future<void> _saveTokens(Map<String, dynamic> tokens) async {
    final accessToken = tokens['access_token'] as String?;
    final refreshToken = tokens['refresh_token'] as String?;

    if (accessToken != null) {
      await _storage.write(key: _kAccessTokenKey, value: accessToken);
      _scheduleProactiveRefresh(accessToken);
    }
    if (refreshToken != null) {
      await _storage.write(key: _kRefreshTokenKey, value: refreshToken);
    }
  }

  /// §2.8.3 / P1-4: Access token `exp` ile süreyi çıkarır; süresi dolmadan
  /// ~60 sn önce refresh planlar. Kalan süre 60 sn'den kısaysa **hemen** refresh dener
  /// (negatif gecikmede timer kurulmaz, 401 beklenmez).
  void _scheduleProactiveRefresh(String accessToken) {
    _proactiveRefreshTimer?.cancel();
    _proactiveRefreshTimer = null;

    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json['exp'] as int?;
      if (exp == null) return;

      final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final refreshAt = expiryTime.subtract(const Duration(seconds: 60));
      final delay = refreshAt.difference(DateTime.now());

      if (delay <= Duration.zero) {
        if (kDebugMode) {
          debugPrint(
            '🔄 [ApiService] Proactive refresh: token within 60s of expiry '
            '(or past schedule point) — refreshing immediately',
          );
        }
        unawaited(_runProactiveRefreshAttempt());
        return;
      }

      if (kDebugMode) {
        debugPrint(
          '🔄 [ApiService] Proactive refresh scheduled in ${delay.inSeconds}s',
        );
      }

      _proactiveRefreshTimer = Timer(delay, () {
        unawaited(_runProactiveRefreshAttempt());
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ApiService] Failed to schedule proactive refresh: $e');
      }
    }
  }

  Future<void> _runProactiveRefreshAttempt() async {
    final refreshed = await _tryRefreshToken();
    if (!refreshed) {
      await _handleForceLogout();
    }
  }

  Future<void> _clearTokens() async {
    _proactiveRefreshTimer?.cancel();
    _proactiveRefreshTimer = null;
    await _storage.delete(key: _kAccessTokenKey);
    await _storage.delete(key: _kRefreshTokenKey);
    await _storage.delete(key: _kPhoneNumberKey);
  }

  /// Dışarıdan tetiklenebilen token refresh — başka HTTP client'ların
  /// (örn. `ApiClient` kesfetpanel.smartsamsun.com için) 401 alınca çağırması için.
  ///
  /// Aynı in-flight refresh varsa onu paylaşır (`_refreshCompleter`), yoksa
  /// yeni bir tane başlatır. `true` döner = yeni token storage'a yazıldı,
  /// caller isteğini yeni token ile tekrarlayabilir.
  Future<bool> refreshTokensExternal() async {
    final existing = _refreshCompleter;
    if (existing != null && !existing.isCompleted) {
      try {
        await existing.future;
        return true;
      } catch (_) {
        return false;
      }
    }
    return _tryRefreshToken();
  }

  /// Try to refresh tokens using the stored refresh token.
  ///
  /// Returns `true` if new tokens were obtained and saved, `false` otherwise.
  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await _storage.read(key: _kRefreshTokenKey);
      if (refreshToken == null) return false;

      // Use a separate Dio without interceptors to avoid recursion.
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': buildSbbMobileUserAgent(),
          },
        ),
      );
      // Security: SSL certificate pinning on refresh client too.
      SslPinning.configureDio(refreshDio);

      final response = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: <String, dynamic>{
          'refresh_token': refreshToken,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true && data['tokens'] is Map<String, dynamic>) {
        await _saveTokens(data['tokens'] as Map<String, dynamic>);
        if (kDebugMode) {
          debugPrint('🔄 [ApiService] Token refresh successful');
        }
        return true;
      }

      if (kDebugMode) {
        debugPrint('⚠️ [ApiService] Token refresh failed: $data');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 [ApiService] Token refresh exception: $e');
      }
      return false;
    }
  }

  /// Check if user has an access token in secure storage.
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _kAccessTokenKey);
    return token != null;
  }

  /// Returns the current access token from secure storage, if any.
  Future<String?> getAccessToken() async {
    return _storage.read(key: _kAccessTokenKey);
  }

  /// Called when refresh fails or tokens are invalid.
  Future<void> _handleForceLogout() async {
    await _clearTokens();
    if (!_logoutController.isClosed) {
      _logoutController.add(null);
    }
  }

  /// Dispose resources if you ever need to tear down the service.
  Future<void> dispose() async {
    _proactiveRefreshTimer?.cancel();
    _proactiveRefreshTimer = null;
    await _logoutController.close();
  }
}

/// Hesap silme talebinin sonucu — backend mesajı + days_remaining taşır.
class DeleteAccountResult {
  const DeleteAccountResult._({
    required this.success,
    this.message,
    this.daysRemaining,
    this.errorMessage,
  });

  final bool success;

  /// Backend mesajı — "Hesabınız 30 gün içinde silinecek..."
  final String? message;
  final int? daysRemaining;
  final String? errorMessage;

  factory DeleteAccountResult.success({String? message, int? daysRemaining}) =>
      DeleteAccountResult._(
        success: true,
        message: message,
        daysRemaining: daysRemaining,
      );

  factory DeleteAccountResult.failure({String? errorMessage}) =>
      DeleteAccountResult._(success: false, errorMessage: errorMessage);
}

/// Pending hesap durumu — `GET /user/account/status` response'u.
class AccountStatusResult {
  const AccountStatusResult({
    required this.isPending,
    this.daysRemaining,
    this.deletionRequestedAt,
  });

  final bool isPending;
  final int? daysRemaining;
  final String? deletionRequestedAt;
}

/// Riverpod provider for ApiService to be shared across the app.
final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService();

  // Ensure ApiService is disposed when no longer used.
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

