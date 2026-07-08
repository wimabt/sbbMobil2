/// Şartname §6.4 — Kişiselleştirme taksonomisi.
///
/// Onboarding'de toplanan ilgi alanı slug'ları ile yer (place) metadata'sı
/// arasındaki **tek kaynak** eşleme. Hem profil türetiminde (davranış → slug)
/// hem de skorlama motorunda (slug → yer) kullanılır; böylece kelime listesi
/// iki yere dağılmaz.
///
/// Slug seti, [OnboardingScreen]'deki `_kInterests` ile birebir aynıdır:
///   historic · culture · nature · food · events · routes · ar_qr · recipes
class InterestTaxonomy {
  const InterestTaxonomy._();

  /// Onboarding'de sunulan kanonik ilgi alanı slug'ları.
  static const List<String> all = [
    'historic',
    'culture',
    'nature',
    'food',
    'events',
    'routes',
    'ar_qr',
    'recipes',
  ];

  /// Slug → anahtar kelime listesi (küçük harf, TR + EN).
  ///
  /// Yer kategorisi / alt kategori / etiket / ad metni bu kelimelerle eşleşirse
  /// ilgili slug tetiklenir. `routes` / `recipes` / `ar_qr` için yer metninde
  /// güvenilir sinyal yoktur; bunlar ayrı yollarla puanlanır:
  ///   • `ar_qr`  → `place.hasArModel`
  ///   • `routes` → tamamlanan rota davranışı
  ///   • `recipes`→ tarif favorileri (gelecek faz)
  static const Map<String, List<String>> keywords = {
    'historic': [
      'historic',
      'tarih',
      'museum',
      'müze',
      'muze',
      'antik',
      'heritage',
      'ören',
      'oren',
      'kale',
      'castle',
      'ruin',
      'anıt',
      'anit',
    ],
    'culture': [
      'culture',
      'kültür',
      'kultur',
      'sanat',
      'theater',
      'tiyatro',
      'gallery',
      'galeri',
      'art',
    ],
    'nature': [
      'park',
      'nature',
      'doğa',
      'doga',
      'beach',
      'plaj',
      'forest',
      'orman',
      'göl',
      'gol',
      'şelale',
      'selale',
      'waterfall',
      'mağara',
      'magara',
      'sahil',
    ],
    'food': [
      'food',
      'restaurant',
      'restoran',
      'yeme',
      'gastronomi',
      'gastronomy',
      'cafe',
      'kafe',
      'lokanta',
      'meyhane',
    ],
    'events': [
      'event',
      'etkinlik',
      'festival',
      'concert',
      'konser',
      'fuar',
    ],
    'routes': <String>[],
    'recipes': <String>[],
    'ar_qr': <String>[],
  };

  /// Serbest metinden (kategori + alt kategori + etiket) eşleşen slug'ları çıkarır.
  static Set<String> slugsForText(String haystack) {
    final hay = haystack.toLowerCase();
    final out = <String>{};
    keywords.forEach((slug, kws) {
      if (kws.isNotEmpty && kws.any(hay.contains)) out.add(slug);
    });
    return out;
  }
}
