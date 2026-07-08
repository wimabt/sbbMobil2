import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/local_activity_tracker.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/discovery_service.dart';
import '../../../core/services/notification_service.dart';

/// Authentication status of the current user.
enum AuthStatus {
  /// App just started, auth state not determined yet.
  initial,

  /// Currently performing a blocking auth operation (OTP, verify, profile).
  loading,

  /// OTP gönderildi, kullanıcı doğrulama ekranında.
  otpSent,

  /// User is fully authenticated and profile is loaded.
  authenticated,

  /// User is not authenticated.
  unauthenticated,
}

/// Immutable user model for the wallet auth context.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.phoneNumber,
    required this.role,
    this.phoneLast4,
    this.firstName,
    this.lastName,
    this.email,
    this.emailVerified = false,
    this.balance,
    this.createdAt,
    this.level,
    this.avatarUrl,
  });

  final String id;

  /// Backend artık maskeli döndürür: "+905****67"
  final String phoneNumber;
  final String role;

  /// Son 4 hane — profil UI'da göstermek için
  final String? phoneLast4;
  final String? firstName;
  final String? lastName;
  final String? email;

  /// E-posta doğrulanmış mı? Backend `email_verified` döndürür.
  /// Telefon değiştirme akışının ön koşuludur (step-up kodu e-postaya gider).
  final bool emailVerified;
  final String? balance;
  final DateTime? createdAt;
  final String? level;
  final String? avatarUrl;

  /// Maskeli telefon numarasını UI'da göstermek için formatlı döndürür.
  String get maskedPhone {
    if (phoneNumber.isNotEmpty) return phoneNumber;
    if (phoneLast4 != null && phoneLast4!.isNotEmpty) return '****$phoneLast4';
    return '';
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      role: json['role'] as String? ?? 'USER',
      phoneLast4: json['phone_last4'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      emailVerified: json['email_verified'] as bool? ?? false,
      balance: json['balance']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      level: json['level']?.toString(),
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  AuthUser copyWith({
    String? id,
    String? phoneNumber,
    String? role,
    String? phoneLast4,
    String? firstName,
    String? lastName,
    String? email,
    bool? emailVerified,
    String? balance,
    DateTime? createdAt,
    String? level,
    String? avatarUrl,
  }) {
    return AuthUser(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      phoneLast4: phoneLast4 ?? this.phoneLast4,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      level: level ?? this.level,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

/// Immutable Auth state.
class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.phoneNumber,
    this.otpCode,
    this.errorMessage,
    this.firstName,
    this.lastName,
    this.email,
    this.isLoading = false,
    this.userNotFoundForLogin = false,
    this.loginOtpFlow = false,
    this.pendingDeletion,
  });

  final AuthStatus status;
  final AuthUser? user;
  final String? phoneNumber;
  /// Development/test akışında backend'in `send-otp` response'unda döndürebildiği kod.
  /// Production'da asla gösterilmez (UI tarafı `kDebugMode` ile korumalı).
  final String? otpCode;
  final String? errorMessage;
  final bool isLoading;
  final String? firstName;
  final String? lastName;
  final String? email;
  /// Giriş akışında: numara sistemde yok (backend `USER_NOT_FOUND` / 404).
  final bool userNotFoundForLogin;

  /// Son başarılı OTP isteği giriş akışından mı (yeniden gönderimde `purpose: login`).
  final bool loginOtpFlow;

  /// KVKK / hesap silme — cold start'ta `GET /user/account/status` ile çekilir.
  /// `null` ya da `isPending == false` → banner gizli.
  /// `isPending == true` → home ekranında geri yükleme banner'ı gösterilir.
  final AccountStatusResult? pendingDeletion;

  factory AuthState.initial() {
    return const AuthState(
      status: AuthStatus.initial,
      user: null,
      phoneNumber: null,
      otpCode: null,
      errorMessage: null,
      firstName: null,
      lastName: null,
      email: null,
      isLoading: false,
      userNotFoundForLogin: false,
      loginOtpFlow: false,
      pendingDeletion: null,
    );
  }

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? phoneNumber,
    String? otpCode,
    String? errorMessage,
    bool clearOtpCode = false,
    bool? isLoading,
    bool clearError = false,
    String? firstName,
    String? lastName,
    String? email,
    bool? userNotFoundForLogin,
    bool clearUserNotFoundForLogin = false,
    bool? loginOtpFlow,
    AccountStatusResult? pendingDeletion,
    bool clearPendingDeletion = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      otpCode: clearOtpCode ? null : (otpCode ?? this.otpCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      userNotFoundForLogin: clearUserNotFoundForLogin
          ? false
          : (userNotFoundForLogin ?? this.userNotFoundForLogin),
      loginOtpFlow: loginOtpFlow ?? this.loginOtpFlow,
      pendingDeletion: clearPendingDeletion
          ? null
          : (pendingDeletion ?? this.pendingDeletion),
    );
  }
}

/// Riverpod-based Auth Notifier that orchestrates the OTP auth flow.
class AuthNotifier extends Notifier<AuthState> {
  late final ApiService _apiService;
  StreamSubscription<void>? _logoutSub;

  /// §2.4: Profil endpoint'ine rate limiting uygulandı.
  /// Aynı oturumda 60 saniye içinde tekrar çekilmesini engelle.
  DateTime? _lastProfileFetchAt;
  static const _profileThrottleDuration = Duration(seconds: 60);

  /// P1-3: OneSignal external user id ↔ JWT / profil durumu.
  void _bindOneSignalToAuthenticatedUser(AuthUser? user) {
    final id = user?.id;
    if (id == null || id.isEmpty) return;
    unawaited(ref.read(notificationProvider.notifier).login(id));
  }

  void _clearOneSignalExternalUser() {
    unawaited(ref.read(notificationProvider.notifier).logout());
  }

  /// Symmetric cleanup for manual logout, forced logout (401/refresh failure), and
  /// confirmed dead sessions (401/403 on profile). **Not** used for timeouts/network.
  Future<void> _performLogoutCleanup() async {
    await _apiService.clearLocalAuthData();
    await ref.read(notificationProvider.notifier).logout();
    ref.invalidate(discoveryServiceProvider);
    // Logout'ta cihazdaki anonim ziyaret/rota kayıtlarını temizle: yeni anonim
    // oturum temiz başlasın, hesaplar arası sızma olmasın (KVKK). Girişliyken
    // bu veri backend'de; login'de postLoginSync zaten migrate edip local'i
    // boşaltıyor, dolayısıyla burada genelde silinecek bir şey kalmaz.
    try {
      await ref.read(localActivityTrackerProvider).clearAll();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [AuthNotifier] localActivity clear failed: $e');
      }
    }
  }

  @override
  AuthState build() {
    _apiService = ref.read(apiServiceProvider);

    // Listen for forced logout events coming from the network layer
    _logoutSub = _apiService.onForcedLogout.listen((_) {
      if (kDebugMode) {
        debugPrint(
          '🔐 [AuthNotifier] Forced logout event received from ApiService',
        );
      }
      unawaited(_onForcedLogoutFromApi());
    });

    // Attempt to restore session on startup.
    unawaited(_restoreSession());

    // Ensure subscriptions are cleaned up when provider is disposed
    ref.onDispose(() {
      _logoutSub?.cancel();
    });

    return AuthState.initial();
  }

  Future<void> _onForcedLogoutFromApi() async {
    await _performLogoutCleanup();
    state = AuthState.initial().copyWith(status: AuthStatus.unauthenticated);
  }

  /// Initial check: if there is a token in storage, try to load profile.
  Future<void> _restoreSession() async {
    try {
      final loggedIn = await _apiService.isLoggedIn();
      if (!loggedIn) {
        _clearOneSignalExternalUser();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          phoneNumber: null,
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        status: AuthStatus.loading,
        isLoading: true,
        clearError: true,
      );

      final profileJson = await _apiService.getProfile();
      _lastProfileFetchAt = DateTime.now();
      final userJson = profileJson['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        _clearOneSignalExternalUser();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          isLoading: false,
        );
        return;
      }

      final user = AuthUser.fromJson(userJson);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
      );
      _bindOneSignalToAuthenticatedUser(user);

      // KVKK pending deletion check — cold start banner için.
      // Profile yüklendikten sonra fire-and-forget; UI'ı bloklamaz.
      unawaited(_refreshPendingDeletionStatus());
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 [AuthNotifier] restoreSession DioException: ${e.message}');
      }
      if (_isDioTerminalAuthFailure(e)) {
        await _performLogoutCleanup();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          isLoading: false,
          clearError: true,
        );
        return;
      }
      // Timeout / offline / 5xx — keep tokens; next launch or pull-to-refresh can retry.
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        isLoading: false,
        errorMessage:
            'Bağlantı hatası, lütfen internetinizi kontrol edin.',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 [AuthNotifier] restoreSession error: $e');
      }
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        isLoading: false,
        errorMessage:
            'Bağlantı hatası, lütfen internetinizi kontrol edin.',
      );
    }
  }

  /// Step 1 of OTP flow – send OTP to the given phone number.
  ///
  /// [type]: `"login"` (giriş) veya `"register"` (kayıt).
  /// Giriş akışında kayıtlı olmayan numara backend tarafından reddedilir.
  Future<void> sendOtp(
    String phoneNumber, {
    String? firstName,
    String? lastName,
    String? email,
    String type = 'login',
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      isLoading: true,
      errorMessage: null,
      phoneNumber: phoneNumber,
      clearOtpCode: true,
      firstName: firstName,
      lastName: lastName,
      email: email,
      clearUserNotFoundForLogin: true,
    );

    try {
      final result = await _apiService.sendOtp(phoneNumber, type: type, email: email);
      final success = result['success'] == true;

      if (success) {
        await _apiService.savePhoneNumber(phoneNumber);
        final otpFromResponse = (result['otp'] ?? result['code'])?.toString();

        state = state.copyWith(
          status: AuthStatus.otpSent,
          isLoading: false,
          clearError: true,
          phoneNumber: phoneNumber,
          otpCode: otpFromResponse,
          loginOtpFlow: type == 'login',
        );
      } else {
        if (type == 'login' && _isUserNotRegisteredPayload(result)) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            isLoading: false,
            errorMessage: null,
            userNotFoundForLogin: true,
          );
          return;
        }
        final message = result['error']?.toString() ??
            result['message']?.toString() ??
            'İşlem başarısız. Lütfen tekrar deneyin.';
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: message,
        );
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 [AuthNotifier] sendOtp DioException: ${e.message}');
      }

      if (type == 'login' && _isUserNotRegisteredDio(e)) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: null,
          userNotFoundForLogin: true,
        );
        return;
      }

      final message = _extractErrorMessage(
        e,
        fallback429:
            'Çok fazla deneme yaptınız, lütfen kısa bir süre bekledikten sonra tekrar deneyin.',
        fallbackGeneral:
            'OTP gönderilirken bir hata oluştu. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.',
      );

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        errorMessage: message,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 [AuthNotifier] sendOtp error: $e');
      }
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        errorMessage:
            'Beklenmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin.',
      );
    }
  }

  /// Step 2a – Giriş akışı: verify OTP and load user profile.
  ///
  /// Yeni dönüş tipi — caller, 409 PENDING / 410 FINAL gibi özel durumları
  /// yakalayıp dialog veya yönlendirme yapabilsin.
  ///
  /// [restore] true → silinmeye işaretlenmiş hesabı geri al (kullanıcı önceki
  /// 409 dialog'unda "Geri Al"a basmışsa).
  Future<VerifyOtpOutcome> verifyOtp({
    required String phoneNumber,
    required String otp,
    bool restore = false,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      isLoading: true,
      clearError: true,
    );

    try {
      final result = await _apiService.verifyOtp(
        phoneNumber,
        otp,
        restore: restore,
      );
      final success = result['success'] == true;

      if (!success) {
        final message = result['error']?.toString() ??
            result['message']?.toString() ??
            'Doğrulama başarısız. Lütfen kodu kontrol edip tekrar deneyin.';
        _clearOneSignalExternalUser();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: message,
        );
        return VerifyOtpOutcome.failure(message);
      }

      final userJson = result['user'] as Map<String, dynamic>?;
      final user = userJson != null ? AuthUser.fromJson(userJson) : null;
      final restored = result['restored'] == true;

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
        clearError: true,
      );
      _bindOneSignalToAuthenticatedUser(user);

      ref.read(analyticsServiceProvider).track(
        AnalyticsEvents.authLogin,
        properties: {'method': 'otp', if (restored) 'restored': true},
      );

      unawaited(loadProfile(force: true));
      return VerifyOtpOutcome.success(restored: restored);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      String? code;
      Map<String, dynamic>? payload;
      if (body is Map<String, dynamic>) {
        code = body['code'] as String?;
        payload = (body['data'] is Map<String, dynamic>)
            ? body['data'] as Map<String, dynamic>
            : null;
      }

      // 409 — Hesap silinmek üzere; restore penceresi açık.
      if (status == 409 && code == 'ACCOUNT_DELETION_PENDING') {
        _clearOneSignalExternalUser();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          clearError: true,
        );
        return VerifyOtpOutcome.deletionPending(
          daysRemaining: (payload?['days_remaining'] as num?)?.toInt() ?? 0,
          deletionRequestedAt: payload?['deletion_requested_at'] as String?,
          deletionReason: payload?['deletion_reason'] as String?,
        );
      }

      // 410 — Pencere kapalı, hesap kalıcı silinmiş.
      if (status == 410 && code == 'ACCOUNT_DELETION_FINAL') {
        _clearOneSignalExternalUser();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          clearError: true,
        );
        return VerifyOtpOutcome.deletionFinal(
          message: body is Map<String, dynamic>
              ? body['error'] as String?
              : null,
        );
      }

      _handleVerifyDioError(e);
      return VerifyOtpOutcome.failure(state.errorMessage ?? 'Doğrulama hatası');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 [AuthNotifier] verifyOtp error: $e');
      }
      _clearOneSignalExternalUser();
      const errorMsg =
          'Beklenmeyen bir hata oluştu. Lütfen biraz sonra tekrar deneyin.';
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        errorMessage: errorMsg,
      );
      return VerifyOtpOutcome.failure(errorMsg);
    }
  }

  /// Step 2b – Kayıt akışı: register with OTP + user info.
  Future<void> registerWithOtp({
    required String phoneNumber,
    required String otp,
    required String firstName,
    required String lastName,
    String? email,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      isLoading: true,
      clearError: true,
    );

    try {
      final result = await _apiService.register(
        phoneNumber: phoneNumber,
        otp: otp,
        firstName: firstName,
        lastName: lastName,
        email: email,
      );
      final success = result['success'] == true;

      if (!success) {
        final message = result['error']?.toString() ??
            result['message']?.toString() ??
            'Kayıt başarısız. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';
        _clearOneSignalExternalUser();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: message,
        );
        return;
      }

      final userJson = result['user'] as Map<String, dynamic>?;
      final user = userJson != null ? AuthUser.fromJson(userJson) : null;

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
        clearError: true,
      );
      _bindOneSignalToAuthenticatedUser(user);

      // mobile_analytics_todo.md §2.13 — auth_register (always-on)
      ref.read(analyticsServiceProvider).track(
        AnalyticsEvents.authRegister,
        properties: const {'method': 'otp'},
      );

      unawaited(loadProfile(force: true));
    } on DioException catch (e) {
      _handleVerifyDioError(e);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 [AuthNotifier] registerWithOtp error: $e');
      }
      _clearOneSignalExternalUser();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        errorMessage:
            'Beklenmeyen bir hata oluştu. Lütfen biraz sonra tekrar deneyin.',
      );
    }
  }

  void _handleVerifyDioError(DioException e) {
    if (kDebugMode) {
      debugPrint('🔥 [AuthNotifier] verify/register DioException: ${e.message}');
    }

    String message;
    final statusCode = e.response?.statusCode;
    if (statusCode == 400 || statusCode == 401) {
      message = _extractErrorMessage(
        e,
        fallbackGeneral:
            'Geçersiz veya süresi dolmuş doğrulama kodu. Lütfen yeni bir kod isteyip tekrar deneyin.',
      );
    } else if (statusCode == 429) {
      message = _extractErrorMessage(
        e,
        fallback429:
            'Çok fazla doğrulama denemesi yaptınız, lütfen kısa bir süre bekledikten sonra tekrar deneyin.',
      );
    } else {
      message =
          'Doğrulama sırasında bir hata oluştu. Lütfen internet bağlantınızı kontrol edin.';
    }

    _clearOneSignalExternalUser();
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      isLoading: false,
      errorMessage: message,
    );
  }

  /// Explicitly fetch the latest profile from backend.
  /// §2.4: Throttle — 60 saniye içinde tekrar çağrılırsa skip eder.
  /// [force] true ise throttle'ı atlar (verify-otp sonrası ilk yükleme).
  Future<void> loadProfile({bool force = false}) async {
    if (!force && _lastProfileFetchAt != null) {
      final elapsed = DateTime.now().difference(_lastProfileFetchAt!);
      if (elapsed < _profileThrottleDuration) {
        if (kDebugMode) {
          debugPrint(
            '⏳ [AuthNotifier] loadProfile throttled — '
            '${_profileThrottleDuration.inSeconds - elapsed.inSeconds}s kaldı',
          );
        }
        return;
      }
    }

    state = state.copyWith(
      status: AuthStatus.loading,
      isLoading: true,
      clearError: true,
    );

    try {
      final profileJson = await _apiService.getProfile();
      _lastProfileFetchAt = DateTime.now();
      final userJson = profileJson['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        await _performLogoutCleanup();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          isLoading: false,
          errorMessage:
              'Kullanıcı bilgileri alınamadı. Lütfen tekrar giriş yapın.',
        );
        return;
      }

      final user = AuthUser.fromJson(userJson);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
      );
      _bindOneSignalToAuthenticatedUser(user);
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 [AuthNotifier] loadProfile DioException: ${e.message}');
      }
      if (_isDioTerminalAuthFailure(e)) {
        await _performLogoutCleanup();
        state = AuthState.initial().copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage:
              'Oturum süreniz dolmuş olabilir. Lütfen tekrar giriş yapın.',
        );
        return;
      }
      final preserved = state.user;
      state = state.copyWith(
        status: preserved != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: preserved,
        isLoading: false,
        errorMessage:
            'Bağlantı hatası, lütfen internetinizi kontrol edin.',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 [AuthNotifier] loadProfile error: $e');
      }
      final preserved = state.user;
      state = state.copyWith(
        status: preserved != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: preserved,
        isLoading: false,
        errorMessage:
            'Kullanıcı bilgileri alınırken bir bağlantı sorunu oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  /// §2.2: Backend'in döndürdüğü hata mesajını kullanıcıya göster.
  /// §2.8.5: Release modda hassas bilgi sızıntısını önlemek için
  /// stack trace, SQL, path gibi debug bilgisi içeren mesajlar filtrelenir.
  String _extractErrorMessage(
    DioException e, {
    String? fallback429,
    String fallbackGeneral = 'Bir hata oluştu. Lütfen tekrar deneyin.',
  }) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final backendMsg =
          data['message'] as String? ?? data['error'] as String?;
      if (backendMsg != null &&
          backendMsg.isNotEmpty &&
          _isSafeForUser(backendMsg)) {
        return backendMsg;
      }
    }
    if (e.response?.statusCode == 429 && fallback429 != null) {
      return fallback429;
    }
    return fallbackGeneral;
  }

  /// Release modda backend mesajının kullanıcıya gösterilip gösterilemeyeceğini kontrol eder.
  /// Stack trace, SQL, dosya yolu gibi debug bilgisi içeren mesajları engeller.
  bool _isSafeForUser(String message) {
    if (kDebugMode) return true;
    final lower = message.toLowerCase();
    const dangerousPatterns = [
      'stack', 'trace', 'exception', 'error at', 'sql', 'query',
      'internal server', 'cannot read property', 'undefined',
      'typeorm', 'prisma', 'sequelize', 'nest', '.ts:', '.js:',
      'at /', 'at \\', '/src/', '/dist/',
    ];
    return !dangerousPatterns.any(lower.contains);
  }

  /// Giriş ekranı: "numara kayıtlı değil" diyalogu kapandıktan sonra bayrağı sıfırla.
  void clearUserNotFoundLoginFlag() {
    state = state.copyWith(clearUserNotFoundForLogin: true);
  }

  /// User-initiated logout (e.g. from settings/profile screen).
  Future<void> logout() async {
    state = state.copyWith(
      status: AuthStatus.loading,
      isLoading: true,
      clearError: true,
    );

    // mobile_analytics_todo.md §2.13 — auth_logout (always-on); ardından flush.
    final analytics = ref.read(analyticsServiceProvider);
    analytics.track(AnalyticsEvents.authLogout);
    try {
      // mobile_integ.md §2.2 — logout'tan önce son bir analitik flush.
      await analytics.flush();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [AuthNotifier] pre-logout analytics flush failed: $e');
      }
    }

    try {
      await _apiService.logout();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [AuthNotifier] logout error: $e');
      }
    }
    await _performLogoutCleanup();
    state = AuthState.initial().copyWith(status: AuthStatus.unauthenticated);
  }

  /// Hesap silme akışı — şartname §14.4.2 + KVKK §10.7.2 + App Store 5.1.1.
  ///
  /// Backend 30 gün soft-delete penceresi açar. Mobile bu süre içinde aynı
  /// telefonla OTP verify yaparsa 409 PENDING dönüp restore flow tetiklenir.
  ///
  /// Dönen result:
  /// - `success: true` → local cleanup yapıldı, mesaj UI'a yansıtılmalı
  /// - `success: false` → backend reddetti, kullanıcı login kalır
  /// Pending hesap silme durumunu yenile (cold start + restore sonrası).
  /// Hata olursa sessizce ignore — banner sadece pozitif sinyalle açılır.
  Future<void> _refreshPendingDeletionStatus() async {
    try {
      final status = await _apiService.fetchAccountStatus();
      // State yarış: bu arada logout olduysa state'i kirletme.
      if (state.status != AuthStatus.authenticated) return;
      if (status != null && status.isPending) {
        state = state.copyWith(pendingDeletion: status);
      } else {
        state = state.copyWith(clearPendingDeletion: true);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [AuthNotifier] refreshPendingDeletionStatus failed: $e');
      }
    }
  }

  /// Home ekranındaki banner üzerinden tetiklenen geri yükleme.
  /// `POST /user/account/restore` çağırır; başarılıysa banner'ı kapatır.
  Future<bool> restoreCurrentAccount() async {
    final ok = await _apiService.restoreAccount();
    if (ok) {
      state = state.copyWith(clearPendingDeletion: true);
    }
    return ok;
  }

  Future<DeleteAccountResult> deleteAccount({String? reason}) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      isLoading: true,
      clearError: true,
    );

    // Analytics — silme talebi (içerik yok, sadece event)
    final analytics = ref.read(analyticsServiceProvider);
    try {
      analytics.track('account_deletion_requested');
      await analytics.flush();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [AuthNotifier] pre-delete analytics flush failed: $e');
      }
    }

    final result = await _apiService.deleteAccount(reason: reason);

    if (!result.success) {
      // Backend reddetti — kullanıcıyı login'de tut, hata göster.
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage ??
            'Hesabınız silinemedi. Lütfen daha sonra tekrar deneyin.',
        status: AuthStatus.authenticated,
      );
      return result;
    }

    // Silme başarılı → logout cleanup ile aynı flow.
    // Backend zaten refresh token'ı DB'den revoke etti; biz secure storage'ı
    // temizliyoruz. 30 gün içinde tekrar OTP login'de 409 yakalanırsa restore.
    await _performLogoutCleanup();
    state = AuthState.initial().copyWith(status: AuthStatus.unauthenticated);
    return result;
  }
}

/// OTP doğrulama sonucu — caller (OTP ekranı) bu sonuca göre davranır:
/// - success → router AuthState değiştiği için otomatik home'a yönlendirir
/// - deletionPending → restore dialog göster
/// - deletionFinal → register ekranına yönlendir
/// - failure → snackbar/inline error göster
sealed class VerifyOtpOutcome {
  const VerifyOtpOutcome();

  factory VerifyOtpOutcome.success({bool restored}) = VerifyOtpSuccess;
  factory VerifyOtpOutcome.deletionPending({
    required int daysRemaining,
    String? deletionRequestedAt,
    String? deletionReason,
  }) = VerifyOtpDeletionPending;
  factory VerifyOtpOutcome.deletionFinal({String? message}) =
      VerifyOtpDeletionFinal;
  factory VerifyOtpOutcome.failure(String message) = VerifyOtpFailure;
}

class VerifyOtpSuccess extends VerifyOtpOutcome {
  const VerifyOtpSuccess({this.restored = false});
  final bool restored;
}

class VerifyOtpDeletionPending extends VerifyOtpOutcome {
  const VerifyOtpDeletionPending({
    required this.daysRemaining,
    this.deletionRequestedAt,
    this.deletionReason,
  });
  final int daysRemaining;
  final String? deletionRequestedAt;
  final String? deletionReason;
}

class VerifyOtpDeletionFinal extends VerifyOtpOutcome {
  const VerifyOtpDeletionFinal({this.message});
  final String? message;
}

class VerifyOtpFailure extends VerifyOtpOutcome {
  const VerifyOtpFailure(this.message);
  final String message;
}

/// 401/403: access/refresh gerçekten geçersiz; yerel oturum temizlenmeli.
bool _isDioTerminalAuthFailure(DioException e) {
  final code = e.response?.statusCode;
  return code == 401 || code == 403;
}

/// send-otp yanıtında "bu numara yok" tespiti (JSON gövde).
bool _isUserNotRegisteredPayload(Map<String, dynamic> result) {
  final c = result['code']?.toString().toUpperCase() ??
      result['error_code']?.toString().toUpperCase() ??
      '';
  if (c == 'USER_NOT_FOUND' ||
      c == 'USER_NOT_REGISTERED' ||
      c == 'NOT_REGISTERED') {
    return true;
  }
  return false;
}

/// send-otp HTTP hatasında "bu numara yok" tespiti.
bool _isUserNotRegisteredDio(DioException e) {
  final code = e.response?.statusCode;
  if (code == 404) return true;
  final data = e.response?.data;
  if (data is Map<String, dynamic>) {
    return _isUserNotRegisteredPayload(data);
  }
  return false;
}

/// Public provider for the Auth state.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

