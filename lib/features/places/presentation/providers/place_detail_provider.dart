import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/ar_service.dart';
import '../../../../core/services/discovery_service.dart';
import '../../../../core/services/place_id_resolver.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../auth/providers/auth_provider.dart';
import 'places_provider.dart';

/// Dual-backend orchestrator for place detail.
///
/// **ID Routing:**
/// - CMS content (System A): uses `cmsContentId` (= `externalId ?? id`)
/// - Gamification (System B): uses `id` (gamification internal ID)
///
/// When the incoming [id] might be either a CMS ID or a gamification ID,
/// the [PlaceIdResolver] is consulted to resolve the correct counterpart.
final placeDetailProvider = FutureProvider.family<Place?, String>((ref, id) async {
  final repository = ref.watch(placeRepositoryProvider);
  
  final languageCode = ref.watch(
    localeProvider.select((s) => s.locale.languageCode),
  );
  debugPrint('🌍 [placeDetailProvider] Current language: $languageCode');

  ref.watch(authProvider.select((s) => s.user?.id));

  // Read resolver (don't watch — avoids rebuild when resolver populates)
  final resolver = ref.read(placeIdResolverProvider);
  final cmsId = resolver.gamificationToCms[id] ?? id;
  final gamificationId = resolver.cmsToGamification[id] ?? id;
  debugPrint('🔀 [placeDetailProvider] id=$id → cmsId=$cmsId, gamificationId=$gamificationId');

  // ── Dual-backend fetch ─────────────────────────────────────────
  // Auth değiştiğinde (login/logout) rebuild tetikle
  ref.watch(authProvider.select((s) => s.status));

  // CMS content (System A) — always fetched
  // Gamification data (System B) — auth-optional: token yokken public data
  // (points), token varken full data (+ visited, claimed, last_visited_at)
  final contentFuture = repository.getPlace(cmsId);
  final gamificationFuture = ref
      .read(discoveryServiceProvider)
      .getPlaceDetail(gamificationId)
      .then<Map<String, dynamic>?>((v) => v)
      .catchError((e) {
          debugPrint('⚠️ [placeDetailProvider] Gamification API failed: $e');
          return null;
        });

  final results = await Future.wait([contentFuture, gamificationFuture]);
  final rawPlace = results[0] as Place?;
  final mobileData = results[1] as Map<String, dynamic>?;

  if (rawPlace == null) return null;

  var place = rawPlace;

  /// System B (gamification) için canonical id — proximity + visit API anahtarı.
  void applyGamificationIdFromMobile(Map<String, dynamic> data) {
    final mid = data['id']?.toString();
    if (mid != null && mid.isNotEmpty) {
      place = place.copyWith(id: mid, externalId: place.externalId ?? cmsId);
    }
  }

  // 1) Merge cached list data (already enriched by places_provider)
  final cachedPlaces = ref.read(placesProvider).allPlaces;
  final cachedPlace = cachedPlaces.isEmpty
      ? null
      : cachedPlaces.cast<Place?>().firstWhere(
          (p) =>
              p?.cmsContentId == cmsId ||
              p?.id == gamificationId,
          orElse: () => null,
        );

  if (cachedPlace != null &&
      cachedPlace.points != null &&
      cachedPlace.points! > 0) {
    place = place.copyWith(
      points: cachedPlace.points,
      visited: cachedPlace.visited,
      visitCount: cachedPlace.visitCount ?? place.visitCount,
      lastVisitedAt: cachedPlace.lastVisitedAt ?? place.lastVisitedAt,
      externalId: cachedPlace.externalId ?? place.externalId,
    );
    debugPrint('✅ [placeDetailProvider] Enriched from cached list: points=${cachedPlace.points}, visited=${cachedPlace.visited}');
  }

  // 2) Merge fresh gamification data (System B)
  if (mobileData != null) {
    applyGamificationIdFromMobile(mobileData);
    final points = _asInt(mobileData['points']);
    final visited = _asBool(mobileData['visited']);
    final visitCount = _asInt(mobileData['visit_count']);
    final lastVisitedAt = mobileData['last_visited_at'] != null
        ? DateTime.tryParse(mobileData['last_visited_at'].toString())
        : null;
    final mobileArModelUrl = mobileData['ar_model_url'] as String?;
    final mobileArModelName = mobileData['ar_model_name'] as String?;
    final mobileExternalId = mobileData['external_id']?.toString();

    // Gamification API `points: 0` döndürebilir (puan atanmamış demek);
    // bu durumda mevcut (CMS/list'ten gelen) puanı koru.
    final effectivePoints = (points != null && points > 0) ? points : place.points;
    place = place.copyWith(
      points: effectivePoints,
      visited: visited,
      visitCount: visitCount ?? place.visitCount,
      lastVisitedAt: lastVisitedAt ?? place.lastVisitedAt,
      arModelUrl: mobileArModelUrl ?? place.arModelUrl,
      arModelName: mobileArModelName ?? place.arModelName,
      externalId: mobileExternalId ?? place.externalId,
    );

    // Yanıtta `id` yoksa (veya apply atlandıysa) route çözümlemesindeki gamification id
    final mobileIdStr = mobileData['id']?.toString();
    if (mobileIdStr == null || mobileIdStr.isEmpty) {
      place = place.copyWith(
        id: gamificationId,
        externalId: place.externalId ?? cmsId,
      );
    }

    debugPrint(
      '\u2705 [placeDetailProvider] Merged gamification: '
      'api_points=$points effective=$effectivePoints visited=$visited '
      'claimed=${_asBool(mobileData['claimed'])} '
      'place.id=${place.id} externalId=${place.externalId}',
    );
  } else {
    // Mobil detay cevabı yoksa (ağ hatası): yine de CMS id ile karışık id’yi
    // gamification id’ye çekmeye çalış (resolver veya route parametresi).
    place = place.copyWith(
      id: gamificationId,
      externalId: place.externalId ?? cmsId,
    );
  }

  // ar_model_url zaten varsa ek sorguya gerek yok
  if (place.hasArModel) return place;

  // CMS endpoint ar_model_url döndürmediyse, mobile endpoint'ten kontrol et
  try {
    final arService = ref.read(arServiceProvider);
    final arResult = await arService.fetchArPlace(cmsId);
    if (arResult.hasModel) {
      return place.copyWith(
        arModelUrl: arResult.modelUrl,
        arModelName: arResult.modelName,
      );
    }
  } catch (e) {
    debugPrint('⚠️ [placeDetailProvider] AR enrichment failed: $e');
  }

  return place;
});

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = num.tryParse(value);
    return parsed?.toInt();
  }
  return null;
}

bool _asBool(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final s = value.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return false;
}

/// Place'ler için hesaplanan mesafeleri tutan provider
final placeDistancesProvider = NotifierProvider<PlaceDistancesNotifier, Map<String, String>>(
  PlaceDistancesNotifier.new,
);

/// Mesafe haritasını yöneten notifier
///
/// PERFORMANS: Toplu güncellemeler için [updateAllDistances] kullan.
/// Her [updateDistance] çağrısı tüm Map'i kopyalar ve tüm watcher'ları
/// rebuild eder. 280 mekan = 280 rebuild! [updateAllDistances] ile
/// tek seferde tek rebuild tetiklenir.
class PlaceDistancesNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};

  /// Tek bir mesafeyi güncelle (nadir kullanım — sadece tekil place detail vb.)
  void updateDistance(String placeId, String distance) {
    final newState = Map<String, String>.from(state);
    newState[placeId] = distance;
    state = newState;
  }

  /// Toplu mesafe güncellemesi — TEK seferde TEK rebuild tetikler.
  ///
  /// Eski yöntem: 280 place × [updateDistance] = 280 map copy + 280 rebuild
  /// Yeni yöntem: [updateAllDistances] = 1 map merge + 1 rebuild
  void updateAllDistances(Map<String, String> distances) {
    if (distances.isEmpty) return;
    state = {...state, ...distances};
  }
}
