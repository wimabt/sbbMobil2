import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Profil paneli (auth backend) route ID'leri ile CMS route ID'leri arasında
/// çift yönlü eşleme sağlar.
///
/// Profil paneli `/api/v1/mobile/routes` cevabındaki her route'ta:
///   - `id`          → profil paneli dahili ID (örn. 1)
///   - `external_id` → CMS'deki karşılık ID (örn. 9)
///
/// CMS `/travel-routes` endpoint'i yalnızca kendi ID'lerini tanır; profil
/// paneli ID'si ile çağrılırsa 404 döner. Bu resolver, UI navigasyonunda
/// doğru ID'nin kullanılmasını garanti eder.
class RouteIdResolver extends Notifier<RouteIdResolverState> {
  @override
  RouteIdResolverState build() => const RouteIdResolverState();

  /// Gamification verisi yüklendiğinde çağrılır.
  /// [items]: `/api/v1/mobile/routes` cevabındaki route map'leri.
  void populate(List<Map<String, dynamic>> items) {
    final mobileToExternal = <String, String>{};
    final externalToMobile = <String, String>{};

    for (final item in items) {
      final mobileId = item['id']?.toString();
      final externalId = item['external_id']?.toString();
      if (mobileId == null || externalId == null) continue;
      mobileToExternal[mobileId] = externalId;
      externalToMobile[externalId] = mobileId;
    }

    state = RouteIdResolverState(
      mobileToExternal: mobileToExternal,
      externalToMobile: externalToMobile,
    );

    if (kDebugMode) {
      debugPrint(
        '🗺️ [RouteIdResolver] Populated ${mobileToExternal.length} mappings '
        '(e.g. ${mobileToExternal.entries.take(3).map((e) => '${e.key}→${e.value}').join(', ')})',
      );
    }
  }

  /// Verilen ID'yi CMS tarafındaki ID'ye çevirir.
  /// Eğer zaten CMS ID'si ise veya mapping yoksa aynı değeri döner.
  String toCmsId(String id) {
    return state.mobileToExternal[id] ?? id;
  }

  /// Verilen ID'yi profil paneli (mobile) tarafındaki ID'ye çevirir.
  /// Eğer zaten mobile ID'si ise veya mapping yoksa aynı değeri döner.
  String toMobileId(String id) {
    return state.externalToMobile[id] ?? id;
  }

  /// `/routes/:id` segmenti için CMS içerik ID'si ile gamification (mobil) ID'sini üretir.
  ///
  /// [param] hem PHP CMS `travel-routes` kayıt ID'si hem de NestJS mobil route ID'si
  /// olabilir; iki harita aynı rakamsal string için farklı anlamlar taşıyabilir.
  /// Bu yüzden tek başına `mobileToExternal[param]` veya `externalToMobile[param]`
  /// kullanmak yanlış eşleşmeye (liste başındaki rotaya tıklayınca başka rota) yol açar.
  ///
  /// Öncelik: yalnızca CMS tarafında kayıtlı → CMS; yalnızca mobilde → mobil;
  /// ikisinde de varsa (nadir) liste/navigasyonun CMS ID kullandığı varsayımıyla CMS önceliklidir.
  /// Hiçbiri yoksa [param] hem CMS hem mobil denemesi için aynen kullanılır (legacy).
  ({String cmsId, String gamificationId}) resolveForRoutePath(String param) {
    final s = state;
    final hasCmsKey = s.externalToMobile.containsKey(param);
    final hasMobileKey = s.mobileToExternal.containsKey(param);

    if (hasCmsKey && !hasMobileKey) {
      return (
        cmsId: param,
        gamificationId: s.externalToMobile[param]!,
      );
    }
    if (!hasCmsKey && hasMobileKey) {
      return (
        cmsId: s.mobileToExternal[param]!,
        gamificationId: param,
      );
    }
    if (hasCmsKey && hasMobileKey) {
      return (
        cmsId: param,
        gamificationId: s.externalToMobile[param]!,
      );
    }
    return (cmsId: param, gamificationId: param);
  }
}

class RouteIdResolverState {
  const RouteIdResolverState({
    this.mobileToExternal = const {},
    this.externalToMobile = const {},
  });

  /// mobile (profil paneli) ID → CMS external ID
  final Map<String, String> mobileToExternal;

  /// CMS external ID → mobile (profil paneli) ID
  final Map<String, String> externalToMobile;
}

final routeIdResolverProvider =
    NotifierProvider<RouteIdResolver, RouteIdResolverState>(
  RouteIdResolver.new,
);
