/// Alt kategori slug → görünen ad (TR/EN) eşlemesi.
///
/// **Neden cihazda?** CMS `/places` yanıtında alt kategoriler yalnızca slug
/// olarak gelir (ör. `yoresel-lezzet-duraklari`) ve slug'lar dilden bağımsızdır
/// (`lang=en` de aynı slug'ı döner). Etiket döndüren bir endpoint yok
/// (`/categories/{id}/subcategories` boş yanıt veriyor). Slug'dan otomatik
/// başlık üretmek Türkçe aksanları kaybettirir ("Yoresel Lezzet Duraklari"),
/// bu yüzden bilinen slug'lar burada elle eşlenir; bilinmeyenler için
/// de-slugify fallback kullanılır. Backend ileride etiket dönerse bu dosya
/// kaldırılıp API etiketi kullanılabilir.
library;

class SubcategoryLabels {
  SubcategoryLabels._();

  /// Bilinen slug → (TR, EN) etiketleri.
  static const Map<String, ({String tr, String en})> _labels = {
    'sivil-mimari-yapilar': (tr: 'Sivil Mimari Yapılar', en: 'Civil Architecture'),
    'oteller': (tr: 'Oteller', en: 'Hotels'),
    'dini-yapilar': (tr: 'Dini Yapılar', en: 'Religious Sites'),
    'tabiat-parki-kanyon-gol': (tr: 'Tabiat Parkı, Kanyon & Göl', en: 'Nature Park, Canyon & Lake'),
    'restoran-kafe': (tr: 'Restoran & Kafe', en: 'Restaurant & Cafe'),
    'muzeler': (tr: 'Müzeler', en: 'Museums'),
    'aktivite-spor': (tr: 'Aktivite & Spor', en: 'Activity & Sports'),
    'poliklinikler': (tr: 'Poliklinikler', en: 'Polyclinics'),
    'otopark': (tr: 'Otopark', en: 'Parking'),
    'kutuphane': (tr: 'Kütüphane', en: 'Library'),
    'eczane': (tr: 'Eczane', en: 'Pharmacy'),
    'selaleler': (tr: 'Şelaleler', en: 'Waterfalls'),
    'oren-yerleri': (tr: 'Ören Yerleri', en: 'Ancient Sites'),
    'taksi': (tr: 'Taksi', en: 'Taxi'),
    'yoresel-lezzet-duraklari': (tr: 'Yöresel Lezzet Durakları', en: 'Local Flavor Stops'),
    'sanat-merkezi': (tr: 'Sanat Merkezi', en: 'Art Center'),
    'ozel-hastaneler': (tr: 'Özel Hastaneler', en: 'Private Hospitals'),
    'eglence': (tr: 'Eğlence', en: 'Entertainment'),
    'alisveris': (tr: 'Alışveriş', en: 'Shopping'),
    'kaplica-ve-hamamlar': (tr: 'Kaplıca ve Hamamlar', en: 'Thermal Springs & Baths'),
    'kamu-hastaneleri': (tr: 'Kamu Hastaneleri', en: 'Public Hospitals'),
    'karavan-park': (tr: 'Karavan Park', en: 'Caravan Park'),
    'hastane': (tr: 'Hastane', en: 'Hospital'),
    'tiyatro': (tr: 'Tiyatro', en: 'Theater'),
    'turist-bilgilendirme-merkezi': (tr: 'Turist Bilgilendirme Merkezi', en: 'Tourist Information Center'),
    'tip-merkezleri': (tr: 'Tıp Merkezleri', en: 'Medical Centers'),
    'tip-fakultesi': (tr: 'Tıp Fakültesi', en: 'Medical Faculty'),
    'otogar': (tr: 'Otogar', en: 'Bus Terminal'),
    'opera': (tr: 'Opera', en: 'Opera'),
    'havalimani': (tr: 'Havalimanı', en: 'Airport'),
    'ilkadim': (tr: 'İlkadım', en: 'İlkadım'),
  };

  /// CMS'te bazı yerlerde slug yerine ham ad girilmiş ("Sivil Yapılar" gibi)
  /// veya aynı kavram için farklı slug kullanılmış. Bunlar burada kanonik
  /// slug'a katlanır; aksi halde aynı alt kategori iki ayrı chip üretir.
  static const Map<String, String> _aliases = {
    'sivil-yapilar': 'sivil-mimari-yapilar',
  };

  /// Ham API değerini kanonik slug'a çevirir.
  /// "Sivil Yapılar" → "sivil-yapilar" → alias → "sivil-mimari-yapilar".
  static String canonicalSlug(String raw) {
    final slug = _slugify(raw);
    return _aliases[slug] ?? slug;
  }

  /// Slug için görünen ad. Bilinmeyen slug'larda de-slugify fallback
  /// ("bilinmeyen-slug" → "Bilinmeyen Slug").
  static String label(String slug, {required bool isTr}) {
    final known = _labels[slug];
    if (known != null) return isTr ? known.tr : known.en;
    return _deslugify(slug);
  }

  static String _slugify(String text) {
    final lowered = text
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    return lowered
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static String _deslugify(String slug) {
    return slug
        .split('-')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
