import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../places/presentation/places_category_display.dart';
import '../../places/presentation/providers/places_provider.dart';

/// Şartname §6.4 — `categoryId → ilgi alanı slug seti` haritası.
///
/// Onboarding'de seçilen ilgi alanlarını, ana sayfadaki **gerçek kategorilerin**
/// içine bağlar. `Place.category` serbest metni güvenilmez olduğu için eşleme,
/// canlı `placesProvider.categories` listesi üzerinde [places_category_display]
/// predikatları ile yapılır:
///
///   • `historic` → Tarihi Yerler ve Müzeler
///   • `culture`  → Samsun'u Keşfet
///   • `food`     → Gastronomi
///   • `nature`   → Doğa ve Parklar  +  Plajlar
///
/// `events` / `routes` / `recipes` / `ar_qr` yer kategorisine karşılık gelmez;
/// bunlar ayrı sinyallerle (AR modeli, rota davranışı) puanlanır.
///
/// Kategoriler henüz yüklenmemişse boş harita döner; bu durumda motor metin +
/// AR sinyaline düşer (graceful degrade). Login durumundan bağımsız çalışır.
final categoryInterestMapProvider =
    Provider.autoDispose<Map<int, Set<String>>>((ref) {
  final categories = ref.watch(placesProvider.select((s) => s.categories));
  final map = <int, Set<String>>{};
  for (final cat in categories) {
    final id = int.tryParse(cat.id);
    if (id == null) continue;
    final slugs = <String>{};
    if (isHistoricalMuseumsCategory(cat)) slugs.add('historic');
    if (isDiscoverSamsunCategory(cat)) slugs.add('culture');
    if (isGastronomyCategory(cat)) slugs.add('food');
    if (isNatureParksCategory(cat)) slugs.add('nature');
    if (isBeachesCategory(cat)) slugs.add('nature');
    // Sağlık Turizmi → ilgi taksonomisinde karşılığı yok, atla.
    if (slugs.isNotEmpty) map[id] = slugs;
  }
  return map;
});
