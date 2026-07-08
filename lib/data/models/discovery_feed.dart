/// mobile_integ.md §3 — Sunucu kişiselleştirilmiş keşif feed'i.
///
/// **Yeni mimari (12 Mayıs 2026):** Discovery feed artık "ranking service"
/// olarak çalışır — içerik üretmez, sadece sıralı ID listesi döner. Mobil
/// taraf bu ID'leri `placesProvider.allPlaces` ve `routesProvider.routes`
/// önbelleklerinde lookup edip kartları kendisi render eder. Bu sayede:
///   • Kategori adı / görsel / lokalizasyon tutarsızlıkları biter
///     (eski "Attraction" bug'ı dahil)
///   • Payload ~80 KB'tan ~2 KB'a düşer (3G hedefi §15.2 için kritik)
///   • Tek kaynak ilkesi: yer datası sadece `/places` endpoint'inden gelir
///
/// "Öne Çıkanlar" bucket'ı kaldırıldı — bu görev CMS'in `place.featured`
/// alanı tarafından `homeFeaturedPlacesProvider` ile zaten yapılıyor.
class DiscoveryFeed {
  const DiscoveryFeed({
    required this.nearby,
    required this.popular,
    required this.newItems,
    required this.meta,
  });

  final List<DiscoveryFeedRef> nearby;
  final List<DiscoveryFeedRef> popular;
  final List<DiscoveryFeedRef> newItems;
  final DiscoveryFeedMeta meta;

  bool get isAllEmpty =>
      nearby.isEmpty && popular.isEmpty && newItems.isEmpty;

  factory DiscoveryFeed.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final meta = json['meta'] is Map<String, dynamic>
        ? DiscoveryFeedMeta.fromJson(json['meta'] as Map<String, dynamic>)
        : const DiscoveryFeedMeta();
    return DiscoveryFeed(
      nearby: _parseList(data['nearby']),
      popular: _parseList(data['popular']),
      newItems: _parseList(data['new']),
      meta: meta,
    );
  }

  static List<DiscoveryFeedRef> _parseList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map(DiscoveryFeedRef.tryParse)
        .whereType<DiscoveryFeedRef>()
        .toList();
  }
}

/// Discovery feed'in döndüğü tek bir referans: `(type, id)`.
/// Mobil bu çifti `placesProvider`/`routesProvider` üzerinde lookup eder.
///
/// Backend geriye uyumlu olmak için tam kart şeması (eski mimari) da
/// dönerse `tryParse` yine sadece `id` + `type` alanlarını okur, kalanı
/// görmezden gelir.
class DiscoveryFeedRef {
  const DiscoveryFeedRef({required this.type, required this.id});

  /// `place` | `route`
  final String type;
  final String id;

  bool get isPlace => type == 'place';
  bool get isRoute => type == 'route';

  static DiscoveryFeedRef? tryParse(Object? raw) {
    if (raw is Map<String, dynamic>) {
      final id = raw['id'];
      if (id == null) return null;
      return DiscoveryFeedRef(
        type: (raw['type'] as String?) ?? 'place',
        id: id.toString(),
      );
    }
    if (raw is num || raw is String) {
      return DiscoveryFeedRef(type: 'place', id: raw.toString());
    }
    return null;
  }
}

class DiscoveryFeedMeta {
  const DiscoveryFeedMeta({
    this.lang = 'tr',
    this.personalized = false,
    this.interests = const [],
    this.locationLat,
    this.locationLng,
    this.radiusKm,
  });

  final String lang;
  final bool personalized;
  final List<String> interests;
  final double? locationLat;
  final double? locationLng;
  final double? radiusKm;

  factory DiscoveryFeedMeta.fromJson(Map<String, dynamic> json) {
    final interests = json['interests'];
    final location = json['location'];
    return DiscoveryFeedMeta(
      lang: (json['lang'] as String?) ?? 'tr',
      personalized: json['personalized'] as bool? ?? false,
      interests: interests is List
          ? interests.map((e) => e.toString()).toList()
          : const [],
      locationLat: location is Map<String, dynamic>
          ? (location['lat'] as num?)?.toDouble()
          : null,
      locationLng: location is Map<String, dynamic>
          ? (location['lng'] as num?)?.toDouble()
          : null,
      radiusKm: location is Map<String, dynamic>
          ? (location['radius_km'] as num?)?.toDouble()
          : null,
    );
  }
}
