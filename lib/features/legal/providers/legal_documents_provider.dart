import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../core/services/log_service.dart';
import '../data/legal_documents.dart';

/// Backend'de YAYIMLANMIŞ bir yasal metnin OTA verisi (gövde + meta).
@immutable
class RemoteLegalDoc {
  const RemoteLegalDoc({
    required this.docType,
    required this.title,
    required this.body,
    this.publishedAt,
  });

  final String docType;
  final String title;
  final String body;
  final String? publishedAt;

  factory RemoteLegalDoc.fromJson(Map<String, dynamic> j) => RemoteLegalDoc(
        docType: (j['doc_type'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        publishedAt: j['published_at']?.toString(),
      );
}

/// §5.3.2 / §14.2.3 — Yayımlanmış yasal metinleri backend'den çeker (OTA).
///
/// Yalnız `is_draft=false` olanlar döner. Admin'den yayımlanan metin/gövde
/// mağaza güncellemesi olmadan uygulamaya yansır. Hata veya boş yanıtta
/// ekranlar koda gömülü [kLegalDocuments]'a düşer (taslak gösterimi korunur).
final legalDocumentsProvider =
    FutureProvider.autoDispose<Map<String, RemoteLegalDoc>>((ref) async {
  try {
    // ÖNEMLİ: Legal endpoint'i auth/mobil backend'inde (sbbMobilBackend),
    // CMS (kesfetpanel) içerik backend'inde DEĞİL. Bu yüzden authApiClientProvider
    // (AuthStaff baseUrl) kullanılır — apiClientProvider (CMS) DEĞİL.
    final client = ref.watch(authApiClientProvider);
    final res = await client.get(
      ApiEndpoints.legalDocuments,
      queryParameters: {'lang': client.languageCode},
    );

    final raw = res.data;
    Map<String, dynamic>? payload;
    if (raw is Map<String, dynamic>) {
      payload = (raw['data'] is Map<String, dynamic>)
          ? raw['data'] as Map<String, dynamic>
          : raw;
    }
    final list = (payload?['documents'] as List?) ?? const [];

    final map = <String, RemoteLegalDoc>{};
    for (final e in list) {
      if (e is Map<String, dynamic>) {
        final d = RemoteLegalDoc.fromJson(e);
        if (d.docType.isNotEmpty && d.body.trim().isNotEmpty) {
          map[d.docType] = d;
        }
      }
    }
    return map;
  } catch (e) {
    LogService.w('legalDocuments fetch failed: $e', tag: 'Legal');
    return const <String, RemoteLegalDoc>{};
  }
});

/// Yayımlanmış (backend) metni, koda gömülü [fallback] üzerine bindirir.
///
/// Backend'de yayımlıysa: başlık + gövde backend'den gelir, **taslak değildir**
/// ve **sürüm gizlenir**. Yoksa fallback (taslak) aynen döner.
LegalDocument resolveLegalDocument(
  LegalDocument fallback,
  RemoteLegalDoc? remote,
) {
  if (remote == null || remote.body.trim().isEmpty) return fallback;
  return LegalDocument(
    id: fallback.id,
    title: remote.title.isNotEmpty ? remote.title : fallback.title,
    summary: fallback.summary,
    icon: fallback.icon,
    version: '', // sürüm uygulamada gösterilmiyor
    lastUpdated: _formatDate(remote.publishedAt) ?? fallback.lastUpdated,
    sections: [LegalSection(body: remote.body)],
    isDraft: false,
  );
}

const List<String> _kTrMonths = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

String? _formatDate(String? iso) {
  if (iso == null) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  return '${d.day} ${_kTrMonths[d.month - 1]} ${d.year}';
}
