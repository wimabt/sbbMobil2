import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_service.dart';
import '../../../auth/providers/auth_provider.dart';

/// Hesap iletişim bilgisi (e-posta / telefon) yönetimi.
///
/// Sözleşme: `account_contact_change_mobile_todo.md` +
/// `account_contact_change_backend_todo.md`.
///
/// Çapraz kilit güvenlik modeli:
///   • Telefon işlemleri step-up'ı → DOĞRULANMIŞ E-POSTAYA kod
///   • E-posta işlemleri step-up'ı → MEVCUT TELEFONA OTP
///
/// Step-up doğrulandığında backend'ten dönen tek kullanımlık, kısa ömürlü
/// "sensitive-action token" yalnızca bellekte tutulur (asla disk/secure
/// storage'a yazılmaz) ve akış tamamlanınca veya iptal edilince temizlenir.

/// Backend'in döndürdüğü standart hata kodları (mobil bunları lokalize eder).
class ContactErrorCodes {
  static const emailRequiredFirst = 'EMAIL_REQUIRED_FIRST';
  static const changeAlreadyPending = 'CHANGE_ALREADY_PENDING';
  static const invalidCode = 'INVALID_CODE';
  static const codeExpired = 'CODE_EXPIRED';
  static const tooManyAttempts = 'TOO_MANY_ATTEMPTS';
  static const rateLimited = 'RATE_LIMITED';
  static const valueAlreadyInUse = 'VALUE_ALREADY_IN_USE';
  static const sameValue = 'SAME_VALUE';

  /// E-posta başka bir hesapta DOĞRULANMAMIŞ olarak kayıtlı → kullanıcıdan
  /// "doğrulayarak bu hesaba bağla" onayı istenir (hata değil, kontrol sinyali).
  static const emailClaimConfirm = 'EMAIL_CLAIM_CONFIRM';
}

/// Akış metotlarının dönüş tipi. UI, [success] / [errorCode] üzerinden karar verir.
class ContactActionResult {
  const ContactActionResult.ok([this.data])
      : success = true,
        errorCode = null,
        message = null,
        statusCode = null;

  const ContactActionResult.fail({this.errorCode, this.message, this.statusCode})
      : success = false,
        data = null;

  final bool success;

  /// Standart hata kodu (ör. `EMAIL_REQUIRED_FIRST`) — UI lokalize eder.
  final String? errorCode;

  /// Backend'in serbest metin mesajı (eşlenmemiş kodda UI'da gösterilebilir).
  final String? message;

  /// HTTP durum kodu (varsa) — tanı/loglama için.
  final int? statusCode;

  final Map<String, dynamic>? data;
}

class AccountContactNotifier extends Notifier<void> {
  late final ApiService _api;

  /// Step-up sonrası alınan tek kullanımlık token — yalnızca bellekte.
  String? _sensitiveToken;

  @override
  void build() {
    _api = ref.read(apiServiceProvider);
  }

  /// Akış iptal edilince / tamamlanınca step-up token'ını temizle.
  void resetSensitive() => _sensitiveToken = null;

  bool get hasSensitiveToken =>
      _sensitiveToken != null && _sensitiveToken!.isNotEmpty;

  // ════════════════════════════════════════════════════════════════════
  // FAZ 1 — Mevcut e-postayı doğrula (step-up yok)
  // ════════════════════════════════════════════════════════════════════

  Future<ContactActionResult> startEmailVerification() =>
      _run(() => _api.startEmailVerification());

  Future<ContactActionResult> confirmEmailVerification(String code) async {
    final res = await _run(() => _api.confirmEmailVerification(code));
    if (res.success) await _refreshProfile();
    return res;
  }

  // ════════════════════════════════════════════════════════════════════
  // FAZ 2 — E-posta değiştirme / ekleme (telefon step-up)
  // ════════════════════════════════════════════════════════════════════

  Future<ContactActionResult> startEmailChange() =>
      _run(() => _api.startEmailChange());

  Future<ContactActionResult> verifyEmailChangeStepup(String otp) =>
      _runStepup(() => _api.verifyEmailChangeStepup(otp));

  Future<ContactActionResult> setNewEmail(String newEmail,
          {bool confirmClaim = false}) =>
      _runWithToken((t) => _api.setNewEmail(newEmail,
          sensitiveToken: t, confirmClaim: confirmClaim));

  Future<ContactActionResult> confirmEmailChange(String code) async {
    final res =
        await _runWithToken((t) => _api.confirmEmailChange(code, sensitiveToken: t));
    if (res.success) {
      resetSensitive();
      await _refreshProfile();
    }
    return res;
  }

  // ════════════════════════════════════════════════════════════════════
  // FAZ 3 — Telefon değiştirme (e-posta step-up; doğrulanmış e-posta gerekir)
  // ════════════════════════════════════════════════════════════════════

  Future<ContactActionResult> startPhoneChange() =>
      _run(() => _api.startPhoneChange());

  Future<ContactActionResult> verifyPhoneChangeStepup(String code) =>
      _runStepup(() => _api.verifyPhoneChangeStepup(code));

  Future<ContactActionResult> setNewPhone(String newPhone) =>
      _runWithToken((t) => _api.setNewPhone(newPhone, sensitiveToken: t));

  Future<ContactActionResult> confirmPhoneChange(String otp) async {
    final res =
        await _runWithToken((t) => _api.confirmPhoneChange(otp, sensitiveToken: t));
    if (res.success) {
      resetSensitive();
      await _refreshProfile();
    }
    return res;
  }

  // ════════════════════════════════════════════════════════════════════
  // Yardımcılar
  // ════════════════════════════════════════════════════════════════════

  /// Step-up dışı standart çağrı.
  Future<ContactActionResult> _run(
    Future<Map<String, dynamic>> Function() call,
  ) async {
    try {
      final data = await call();
      if (data['success'] == false) return _failFromBody(data);
      return ContactActionResult.ok(data);
    } on DioException catch (e) {
      return _failFromDio(e);
    } catch (e) {
      if (kDebugMode) debugPrint('🔥 [AccountContact] $e');
      return const ContactActionResult.fail();
    }
  }

  /// Step-up doğrulama — başarıda dönen token'ı belleğe alır.
  Future<ContactActionResult> _runStepup(
    Future<Map<String, dynamic>> Function() call,
  ) async {
    final res = await _run(call);
    if (res.success) {
      final token = _extractToken(res.data ?? const {});
      if (token == null) {
        // Token gelmediyse akış güvenli ilerleyemez.
        return const ContactActionResult.fail();
      }
      _sensitiveToken = token;
    }
    return res;
  }

  /// Sensitive-token gerektiren çağrı. Token yoksa akış baştan başlamalı.
  Future<ContactActionResult> _runWithToken(
    Future<Map<String, dynamic>> Function(String token) call,
  ) async {
    final token = _sensitiveToken;
    if (token == null || token.isEmpty) {
      return const ContactActionResult.fail(
        errorCode: ContactErrorCodes.codeExpired,
      );
    }
    return _run(() => call(token));
  }

  Future<void> _refreshProfile() async {
    try {
      await ref.read(authProvider.notifier).loadProfile(force: true);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [AccountContact] profile refresh: $e');
    }
  }

  ContactActionResult _failFromBody(Map<String, dynamic> body) {
    final code = (body['code'] ?? body['error_code'])?.toString();
    final msg = (body['message'] ?? body['error'])?.toString();
    return ContactActionResult.fail(errorCode: code, message: msg);
  }

  ContactActionResult _failFromDio(DioException e) {
    final status = e.response?.statusCode;
    if (kDebugMode) {
      debugPrint(
        '🔥 [AccountContact] Dio $status ${e.requestOptions.path} '
        'type=${e.type.name} data=${e.response?.data}',
      );
    }
    String? code;
    String? msg;
    final body = e.response?.data;
    if (body is Map<String, dynamic>) {
      code = (body['code'] ?? body['error_code'])?.toString();
      msg = (body['message'] ?? body['error'])?.toString();
    }
    if (code == null && status == 429) {
      code = ContactErrorCodes.rateLimited;
    }
    // Hiç mesaj/kod yoksa (ör. ağ/timeout, HTML 404) kullanıcıya net bir ipucu.
    if (code == null && (msg == null || msg.isEmpty)) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        msg = 'Sunucuya ulaşılamadı. Bağlantınızı kontrol edip tekrar deneyin.';
      }
    }
    return ContactActionResult.fail(errorCode: code, message: msg, statusCode: status);
  }

  String? _extractToken(Map<String, dynamic> data) {
    final direct = data['token'] ?? data['sensitive_token'];
    if (direct is String && direct.isNotEmpty) return direct;
    final nested = data['data'];
    if (nested is Map<String, dynamic>) {
      final t = nested['token'] ?? nested['sensitive_token'];
      if (t is String && t.isNotEmpty) return t;
    }
    return null;
  }
}

final accountContactProvider =
    NotifierProvider<AccountContactNotifier, void>(AccountContactNotifier.new);
