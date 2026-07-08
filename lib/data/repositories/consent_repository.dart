import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart' show ApiException;
import '../../api/endpoints.dart';
import '../../core/network/api_service.dart';
import '../../features/legal/data/legal_documents.dart';

/// A2 (KVKK §10.6.3, §14.2.3) — Açık rıza kaydının sunucu tarafında
/// denetim izi (ip_hash + timestamp) ile kalıcılaştırılması.
///
/// Cihazdaki [consentProvider] rızayı yerelde tutar; auth tamamlandığında
/// ([postLoginSyncProvider]) bu repo ile sunucuya push'lanır. Backend kaydı
/// append-only olduğu için tekrar gönderim guard'ı [ConsentNotifier]
/// tarafında (`serverSyncedVersion`) yapılır.
///
/// Auth gerektiren tüm endpoint'ler `ApiService.dio` üzerinden çağrılır;
/// JWT interceptor ve 401 → refresh akışı otomatik devrededir.
class ConsentRepository {
  ConsentRepository(this._dio);

  final Dio _dio;

  /// Açık rıza kaydını sunucuya yazar (append-only denetim kaydı).
  ///
  /// [docType] varsayılan olarak [LegalDocIds.acikRiza]; [version] kabul
  /// edilen yasal metin sürümü ([kLegalContentVersion]).
  /// Hata durumunda [ApiException] fırlatır.
  Future<void> submitConsent({
    String docType = LegalDocIds.acikRiza,
    required int version,
    required bool accepted,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.userConsents,
        data: {
          'doc_type': docType,
          'doc_version': version,
          'accepted': accepted,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Kullanıcının doc_type başına en güncel rıza durumunu + sunucuda
  /// yayımlanmış güncel sürümü getirir.
  Future<RemoteConsentStatus> fetchConsents() async {
    try {
      final response = await _dio.get(ApiEndpoints.userConsents);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          return RemoteConsentStatus.fromJson(payload);
        }
      }
      return const RemoteConsentStatus();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

/// Backend `GET /user/consents` yanıtı.
@immutable
class RemoteConsentStatus {
  const RemoteConsentStatus({
    this.consents = const [],
    this.currentVersion,
  });

  /// doc_type başına en güncel kayıt (`{doc_type, doc_version, accepted}`).
  final List<RemoteConsent> consents;

  /// Sunucuda yayımlanmış (is_draft=false) güncel açık rıza sürümü.
  /// Henüz yayımlanmış metin yoksa `null`.
  final int? currentVersion;

  factory RemoteConsentStatus.fromJson(Map<String, dynamic> json) {
    final raw = json['consents'];
    final list = <RemoteConsent>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) list.add(RemoteConsent.fromJson(e));
      }
    }
    final cv = json['current_version'];
    return RemoteConsentStatus(
      consents: list,
      currentVersion: cv is num ? cv.toInt() : null,
    );
  }
}

/// Tek bir uzak rıza kaydı.
@immutable
class RemoteConsent {
  const RemoteConsent({
    required this.docType,
    required this.docVersion,
    required this.accepted,
  });

  final String docType;
  final int docVersion;
  final bool accepted;

  factory RemoteConsent.fromJson(Map<String, dynamic> json) => RemoteConsent(
        docType: (json['doc_type'] ?? '').toString(),
        docVersion: (json['doc_version'] is num)
            ? (json['doc_version'] as num).toInt()
            : 0,
        accepted: json['accepted'] == true,
      );
}

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ConsentRepository(apiService.dio);
});
