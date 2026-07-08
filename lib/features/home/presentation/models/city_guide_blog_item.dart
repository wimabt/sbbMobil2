/// Ana sayfa «Şehir Rehberi & Blog» kartı — API bağlandığında aynı alanlar doldurulur.
///
/// [imageUrl]: `http(s)://...` veya `assets/...`; boşsa yer tutucu gösterilir.
class CityGuideBlogItem {
  const CityGuideBlogItem({
    required this.id,
    required this.title,
    required this.categoryLabel,
    required this.imageUrl,
    required this.readTimeLabel,
    required this.dateLabel,
  });

  final String id;
  final String title;
  final String categoryLabel;
  final String imageUrl;
  /// Örn. `5 dk okuma` — sunucu veya l10n katmanında üretilir.
  final String readTimeLabel;
  /// Örn. `Bugün`, `12 Nis 2026`
  final String dateLabel;
}
