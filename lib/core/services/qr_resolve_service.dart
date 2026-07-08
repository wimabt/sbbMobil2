import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';

/// `mobile_pending_changes.md` B8 — Kalıcı (persistent) QR çözümleme.
///
/// Backend response şeması:
/// ```json
/// {
///   "code": "K3X9Y7AB",
///   "target_type": "place|route|event|recipe|ar_point|url",
///   "target_id": "p123",
///   "label": "Saathane giriş tabela",
///   "deep_link": "sbb://place/p123"
/// }
/// ```
@immutable
class QrResolveResponse {
  const QrResolveResponse({
    required this.code,
    required this.targetType,
    required this.targetId,
    required this.deepLink,
    this.label,
  });

  final String code;
  final String targetType;
  final String targetId;

  /// `sbb://<scheme>/<id>` ya da harici `https://...` URL.
  final String deepLink;
  final String? label;

  factory QrResolveResponse.fromJson(Map<String, dynamic> json) {
    return QrResolveResponse(
      code: (json['code'] ?? '').toString(),
      targetType: (json['target_type'] ?? '').toString(),
      targetId: (json['target_id'] ?? '').toString(),
      deepLink: (json['deep_link'] ?? '').toString(),
      label: json['label']?.toString(),
    );
  }
}

/// Backend'in dönebileceği hata türleri.
enum QrResolveErrorKind {
  /// Kod bulunamadı veya artık geçerli değil.
  notFound,

  /// Ağ ya da sunucu hatası.
  network,

  /// Beklenmedik durum.
  unknown,
}

@immutable
class QrResolveException implements Exception {
  const QrResolveException(this.kind, [this.message]);
  final QrResolveErrorKind kind;
  final String? message;

  @override
  String toString() => 'QrResolveException($kind${message != null ? ': $message' : ''})';
}

/// Kısa (8-12 karakter) kalıcı QR kodu mu?
///
/// Spec ([mobile_pending_changes.md] B8):
///   * uzunluk < 16
///   * regex `^[A-HJKMNP-Z2-9]{6,12}$`
///   * büyük/küçük harf duyarsız (mobilde uppercase'e normalize ediyoruz)
class PersistentQrCode {
  PersistentQrCode._();

  static final RegExp _pattern = RegExp(r'^[A-HJKMNP-Z2-9]{6,12}$');

  static bool isLikely(String payload) {
    final trimmed = payload.trim();
    if (trimmed.length >= 16) return false;
    return _pattern.hasMatch(trimmed.toUpperCase());
  }

  /// Tarama ile gelen ham metni normalize et — boşlukları temizle, upper'a çevir.
  static String normalize(String payload) => payload.trim().toUpperCase();
}

class QrResolveService {
  QrResolveService(this._client);
  final ApiClient _client;

  Future<QrResolveResponse> resolve(String code) async {
    try {
      final response = await _client.get(
        ApiEndpoints.qrResolve,
        queryParameters: {'code': PersistentQrCode.normalize(code)},
      );

      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const QrResolveException(QrResolveErrorKind.unknown,
            'Beklenmeyen yanıt formatı');
      }
      final payload = (raw['data'] is Map<String, dynamic>)
          ? raw['data'] as Map<String, dynamic>
          : raw;
      return QrResolveResponse.fromJson(payload);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const QrResolveException(QrResolveErrorKind.notFound);
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw QrResolveException(QrResolveErrorKind.network, e.message);
      }
      throw QrResolveException(QrResolveErrorKind.unknown, e.message);
    }
  }
}

final qrResolveServiceProvider = Provider<QrResolveService>((ref) {
  // QR resolve sbbMobilBackend'te (/api/v1/qr/resolve) — CMS değil. authApiClientProvider.
  return QrResolveService(ref.watch(authApiClientProvider));
});
