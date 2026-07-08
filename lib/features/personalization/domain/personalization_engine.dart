import '../../../data/models/place.dart';
import 'interest_taxonomy.dart';
import 'personalization_profile.dart';

/// Şartname §6.4 — Kişiselleştirme skorlama motoru.
///
/// Tek kaynak: yer datası daima `placesProvider.allPlaces` cache'inden gelir.
/// Bu motor yalnızca **sıralama** yapar; içerik üretmez.
///
/// **Kategori-öncelikli eşleme:** `Place.category` serbest metni backend'de
/// lokalize değildir ve güvenilmez ("Attraction" gibi). Bu yüzden bir yerin
/// ilgi alanı slug'ları öncelikle `categoryId → ilgi` haritasından
/// ([categoryInterests]) çözülür; ardından etiket/ad metni ve AR modeli ek
/// sinyal olarak katılır. Böylece kullanıcının onboarding'de seçtiği ilgi
/// alanları doğrudan **kategorilerin içinden** yer önerisine dönüşür.
///
/// Skorlama heuristiği (profil ağırlığıyla ölçeklenir):
///   • İlgi eşleşmesi (kategori/etiket/ad)  →  +3 × ağırlık
///   • AR içeriği + `ar_qr` ilgisi          →  +4 × ağırlık
///   • `featured` bayrağı                    →  +1.5
///   • Yakınlık (< 5 km)                     →  0–2 lineer
///   • Daha önce ziyaret / tamamlanmış       →  −0.8
class PersonalizationEngine {
  const PersonalizationEngine._();

  /// Bir yerin ilgi alanı slug'larını çözer.
  ///
  /// [categoryInterests]: `categoryId → ilgi slug seti` (canlı kategorilerden
  /// türetilir; bkz. `categoryInterestMapProvider`). Boş geçilirse yalnızca
  /// metin + AR sinyaline düşer.
  static Set<String> resolvePlaceInterests(
    Place place,
    Map<int, Set<String>> categoryInterests,
  ) {
    final slugs = <String>{};

    // 1) Kategori eşlemesi (en güvenilir)
    final cid = place.categoryId;
    if (cid != null) {
      final mapped = categoryInterests[cid];
      if (mapped != null) slugs.addAll(mapped);
    }

    // 2) Metin sinyali (kategori etiketi + alt kategori + etiket + ad)
    slugs.addAll(InterestTaxonomy.slugsForText(
      '${place.category ?? ''} ${place.subcategories.join(' ')} ${place.tags.join(' ')} ${place.name}',
    ));

    // 3) AR sinyali
    if (place.hasArModel) slugs.add('ar_qr');

    return slugs;
  }

  /// Önceden çözülmüş [placeSlugs] ile bir yeri profile göre puanlar.
  /// Profil boşsa veya yerin ilgiyle bağı yoksa 0 döner.
  static double scorePlace(
    Place place,
    Set<String> placeSlugs,
    PersonalizationProfile profile,
    Map<String, String> distances,
  ) {
    if (profile.isEmpty || placeSlugs.isEmpty) return 0;

    var score = 0.0;
    for (final slug in placeSlugs) {
      final w = profile.weightFor(slug);
      if (w <= 0) continue;
      final base = (slug == 'ar_qr' && place.hasArModel) ? 4.0 : 3.0;
      score += base * w;
    }
    if (score == 0) return 0; // ilgiyle bağ yok → öneriden çıkar

    if (place.featured) score += 1.5;
    final km = parseKm(distances[place.id] ?? place.distance);
    if (km != null && km < 5.0) score += (5.0 - km) * 0.4;
    if (place.visited || place.claimed) score -= 0.8;
    return score;
  }

  /// Aday yer listesini profile göre **stable** yeniden sıralar.
  ///
  /// "Stable": profil skoru eşit olan (veya profil boş olan) öğelerde giriş
  /// sırası korunur. Böylece sunucunun popülerlik sinyali kaybolmaz; profil
  /// yalnızca eşitliği bozan ağırlık olarak devreye girer. Profil boşsa liste
  /// olduğu gibi döner (regresyon yok).
  static List<Place> rankByProfile(
    List<Place> candidates,
    PersonalizationProfile profile,
    Map<int, Set<String>> categoryInterests,
    Map<String, String> distances,
  ) {
    if (profile.isEmpty || candidates.length < 2) return candidates;
    final decorated = <_RankedPlace>[
      for (var i = 0; i < candidates.length; i++)
        _RankedPlace(
          candidates[i],
          i,
          scorePlace(
            candidates[i],
            resolvePlaceInterests(candidates[i], categoryInterests),
            profile,
            distances,
          ),
        ),
    ];
    decorated.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.index.compareTo(b.index); // eşitlikte orijinal sıra
    });
    return [for (final d in decorated) d.place];
  }

  /// Mesafe metnini ("1.2 km", "850 m") km cinsinden double'a çevirir.
  static double? parseKm(String? distance) {
    if (distance == null || distance.isEmpty) return null;
    final normalised = distance.toLowerCase().replaceAll(',', '.');
    final match =
        RegExp(r'(\d+(?:\.\d+)?)\s*(m|km)?').firstMatch(normalised);
    if (match == null) return null;
    final value = double.tryParse(match.group(1) ?? '');
    if (value == null) return null;
    final unit = match.group(2) ?? 'km';
    return unit == 'm' ? value / 1000.0 : value;
  }
}

class _RankedPlace {
  const _RankedPlace(this.place, this.index, this.score);
  final Place place;
  final int index;
  final double score;
}
