import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_activity_tracker.dart';
import '../../../data/models/favorite.dart';
import '../../favorites/presentation/providers/favorites_provider.dart';
import '../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../places/presentation/providers/places_provider.dart';
import '../domain/personalization_engine.dart';
import '../domain/personalization_profile.dart';
import 'category_interest_map_provider.dart';

/// Şartname §6.4 — Birleşik kişiselleştirme profili sağlayıcısı.
///
/// İki senaryoyu tek modelle çözer:
///   • **Anonim:** açık ilgi alanları cihazdaki `onboarding_provider`'dan,
///     davranış sinyalleri `LocalActivityTracker` + favorilerden gelir.
///   • **Girişli:** açık ilgi alanları login sonrası `reconcileWithServer` ile
///     sunucu profilinden senkronlanır (yine `onboarding_provider.interests`
///     üzerinden okunur); davranış sinyalleri KVKK gereği yalnızca cihazda kalır.
///
/// Ağırlıklandırma:
///   • Açık seçim          → 1.0 (baskın)
///   • Davranış (yer başı)  → +0.25, slug başına tavan 0.9
///   • Tamamlanan rota      → `routes` slug'ına +0.25 × adet (tavan 0.9)
const double _kBehaviorStep = 0.25;
const double _kBehaviorCap = 0.9;

final personalizationProfileProvider =
    Provider.autoDispose<PersonalizationProfile>((ref) {
  // ── 1) Açık ilgi alanları (onboarding / sunucu profili) ──────────────
  final explicit = ref.watch(onboardingProvider.select((s) => s.interests));

  // ── 2) Davranış sinyalleri (yalnızca cihazda — KVKK) ─────────────────
  final activity = ref.watch(localActivityStateProvider);
  final favPlaceIds = ref.watch(
    favoritesProvider.select(
      (s) => s.favoriteIds[FavoriteEntityType.place] ?? const <String>{},
    ),
  );
  final allPlaces = ref.watch(placesProvider.select((s) => s.allPlaces));
  final categoryInterests = ref.watch(categoryInterestMapProvider);

  // Davranıştan örtük ağırlık (slug başına tavanlı birikim).
  final behavior = <String, double>{};
  void bumpBehavior(String slug, double delta) {
    final next = (behavior[slug] ?? 0.0) + delta;
    behavior[slug] = next > _kBehaviorCap ? _kBehaviorCap : next;
  }

  if (allPlaces.isNotEmpty &&
      (activity.visitedPlaceIds.isNotEmpty || favPlaceIds.isNotEmpty)) {
    final byId = {for (final p in allPlaces) p.id: p};
    final behaviorIds = <String>{
      ...activity.visitedPlaceIds,
      ...favPlaceIds,
    };
    for (final id in behaviorIds) {
      final p = byId[id];
      if (p == null) continue;
      // Kategori-öncelikli slug çözümü (metin + AR dahil).
      for (final slug
          in PersonalizationEngine.resolvePlaceInterests(p, categoryInterests)) {
        bumpBehavior(slug, _kBehaviorStep);
      }
    }
  }

  // Tamamlanan rotalar → 'routes' ilgisini güçlendir.
  if (activity.completedRouteIds.isNotEmpty) {
    bumpBehavior('routes', _kBehaviorStep * activity.completedRouteIds.length);
  }

  // ── 3) Birleştir: açık seçim davranışı ezer (1.0) ────────────────────
  final weights = <String, double>{...behavior};
  for (final slug in explicit) {
    weights[slug] = 1.0;
  }

  if (weights.isEmpty) return PersonalizationProfile.empty;
  return PersonalizationProfile(Map.unmodifiable(weights));
});
