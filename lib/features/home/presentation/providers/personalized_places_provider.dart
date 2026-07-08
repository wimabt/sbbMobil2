import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/api_client.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/models/place.dart';
import '../../../../data/repositories/mobile_categories_repository.dart';
import '../../../personalization/domain/personalization_engine.dart';
import '../../../personalization/providers/category_interest_map_provider.dart';
import '../../../personalization/providers/personalization_profile_provider.dart';
import '../../../places/presentation/providers/place_detail_provider.dart';
import '../../../places/presentation/providers/places_provider.dart';
import '../widgets/featured_places_section.dart' show FeaturedPlace;

/// Şartname §6.4 — İlgi alanı + davranışa göre kişiselleştirilmiş yer önerileri
/// ("Sizin İçin").
///
/// Tek kaynak: `placesProvider.allPlaces` cache'i üzerinden çalışır. Birleşik
/// [personalizationProfileProvider] (açık ilgi + örtük davranış) ile yerleri
/// puanlayıp en yüksek skorlu ilk 10'u döner. Skorlama mantığı
/// [PersonalizationEngine]'de tek noktadadır; aynı motor home ekranındaki
/// "Popüler" bucket'ını da yeniden sıralar.
///
/// Profil boşsa (gerçek cold-start) boş liste döner → UI bölümü gizler.
final personalizedPlacesProvider =
    Provider.autoDispose<List<FeaturedPlace>>((ref) {
  final profile = ref.watch(personalizationProfileProvider);
  if (profile.isEmpty) return const <FeaturedPlace>[];

  final allPlaces = ref.watch(placesProvider.select((s) => s.allPlaces));
  if (allPlaces.isEmpty) return const <FeaturedPlace>[];

  final distances = ref.watch(placeDistancesProvider);
  final categoryNames = ref.watch(mobileCategoryNamesSyncProvider);
  final categoryInterests = ref.watch(categoryInterestMapProvider);
  final baseUrl = ApiConfig.current.baseUrl;

  final scored = <_Scored>[];
  for (final place in allPlaces) {
    final slugs =
        PersonalizationEngine.resolvePlaceInterests(place, categoryInterests);
    final score =
        PersonalizationEngine.scorePlace(place, slugs, profile, distances);
    if (score > 0) scored.add(_Scored(place, score));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));

  return scored.take(10).map((entry) {
    final p = entry.place;
    final resolved =
        buildImageUrl(p.imageUrl ?? '', baseUrl: baseUrl) ?? (p.imageUrl ?? '');
    return FeaturedPlace(
      id: p.id,
      title: p.name,
      category: resolveCategoryDisplayName(
        p.categoryId,
        p.category,
        categoryNames,
      ),
      distance: distances[p.id] ?? p.distance ?? '',
      image: resolved,
      points: p.points,
      visited: p.visited,
      claimed: p.claimed,
      campaignStatus: p.campaign?.status.value,
    );
  }).toList();
});

class _Scored {
  const _Scored(this.place, this.score);
  final Place place;
  final double score;
}
