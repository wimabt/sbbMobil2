import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart' show ApiException;
import '../../api/endpoints.dart';
import '../../core/network/api_service.dart';
import '../../core/providers/locale_provider.dart';

/// mobile_integ.md §3.2 madde 4 — `GET /api/v1/mobile/categories?lang=tr`
///
/// Discovery feed Thin mimarisinde kart datası `placesProvider` üzerinden
/// gelir; ama `Place.category` (free-text) alanı backend lokalize değil ve
/// "Attraction" gibi yanlış değerler dönebiliyor. Yeni endpoint
/// `category_id → display name` haritasını lokalize döndürür ve kartta bu
/// kullanılır. Açılışta bir kere çağrılır, sonuç bellekte cache.
class MobileCategoriesRepository {
  MobileCategoriesRepository(this._dio, this._defaultLang);

  final Dio _dio;
  final String _defaultLang;

  /// Çekilen kategori adlarını `category_id → ad` map'i olarak döndürür.
  Future<Map<int, String>> fetchNames({String? lang}) async {
    final query = <String, dynamic>{'lang': lang ?? _defaultLang};
    try {
      final response = await _dio.get(
        ApiEndpoints.mobileCategories,
        queryParameters: query,
      );
      final raw = response.data;
      final list = raw is Map<String, dynamic>
          ? (raw['data'] as List?)
          : raw is List
              ? raw
              : null;
      if (list == null) {
        throw const ApiException(
          message: 'Mobile categories response geçersiz',
        );
      }
      final result = <int, String>{};
      for (final entry in list) {
        if (entry is! Map<String, dynamic>) continue;
        final id = entry['id'];
        final name = entry['name'] ?? entry['label'];
        if (id == null || name == null) continue;
        final intId = id is int ? id : int.tryParse(id.toString());
        if (intId == null) continue;
        result[intId] = name.toString();
      }
      return result;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

final mobileCategoriesRepositoryProvider =
    Provider<MobileCategoriesRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final lang = ref.watch(localeProvider).locale.languageCode;
  return MobileCategoriesRepository(apiService.dio, lang);
});

/// Açılışta bir kere fetch edilen `category_id → ad` haritası. Hata durumunda
/// boş map döner — kart "Attraction" yerine boş kategori basar, legacy
/// `Place.category` alanı son çare olarak kullanılabilir.
///
/// Locale değişirse otomatik invalidate olur.
final mobileCategoryNamesProvider =
    FutureProvider<Map<int, String>>((ref) async {
  final repo = ref.watch(mobileCategoriesRepositoryProvider);
  try {
    return await repo.fetchNames();
  } catch (e) {
    debugPrint('⚠️ [MobileCategories] fetch failed: $e');
    return const <int, String>{};
  }
});

/// Senkron kart render'ı için kolay erişim — fetch henüz tamamlanmadıysa
/// boş map döner; bu durumda kart legacy `Place.category` alanına düşer.
final mobileCategoryNamesSyncProvider = Provider<Map<int, String>>((ref) {
  return ref.watch(mobileCategoryNamesProvider).asData?.value ??
      const <int, String>{};
});

/// Place için görüntülenecek kategori adını çözer.
///
/// Öncelik:
/// 1. `place.categoryId` map'te varsa → lokalize ad
/// 2. Yoksa legacy `place.category` (geçiş süresince paralel gönderiliyor)
/// 3. İkisi de yoksa boş string
String resolveCategoryDisplayName(
  int? categoryId,
  String? legacyCategory,
  Map<int, String> namesById,
) {
  if (categoryId != null) {
    final resolved = namesById[categoryId];
    if (resolved != null && resolved.isNotEmpty) return resolved;
  }
  return legacyCategory ?? '';
}
