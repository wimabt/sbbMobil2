import '../../../data/models/models.dart';
import '../../../l10n/generated/app_localizations.dart';

/// CMS'den gelen "Sağlık Turizmi" kategorisini tanır (slug veya etiket).
bool isHealthTourismCategory(PlaceCategory cat) {
  final slug = cat.slug?.toLowerCase().replaceAll('-', '_');
  if (slug == 'health_tourism' || slug == 'saglik_turizmi') return true;
  final l = cat.label.toLowerCase();
  return l.contains('sağlık') && l.contains('turizm');
}

/// "Samsun'u Keşfet" ana sayfa kategorisi
bool isDiscoverSamsunCategory(PlaceCategory cat) {
  final slug = cat.slug?.toLowerCase().replaceAll('-', '_');
  if (slug == 'discover_samsun' ||
      slug == 'samsunu_kesfet' ||
      slug == 'samsun_kesfet' ||
      slug == 'kesfet_samsun') {
    return true;
  }
  final l = cat.label.toLowerCase();
  return l.contains('samsun') && (l.contains('keşfet') || l.contains('kesfet'));
}

/// Gastronomi
bool isGastronomyCategory(PlaceCategory cat) {
  final slug = cat.slug?.toLowerCase().replaceAll('-', '_');
  if (slug == 'gastronomy' || slug == 'gastronomi') return true;
  final l = cat.label.toLowerCase();
  return l.contains('gastronom');
}

/// Doğa ve parklar
bool isNatureParksCategory(PlaceCategory cat) {
  final slug = cat.slug?.toLowerCase().replaceAll('-', '_');
  if (slug == 'nature_parks' ||
      slug == 'nature_and_parks' ||
      slug == 'doga_park' ||
      slug == 'doga_ve_parklar') {
    return true;
  }
  final l = cat.label.toLowerCase();
  final hasDogal = l.contains('doğa') || l.contains('doga') || l.contains('nature');
  final hasPark = l.contains('park');
  return hasDogal && hasPark;
}

/// Plajlar
bool isBeachesCategory(PlaceCategory cat) {
  final slug = cat.slug?.toLowerCase().replaceAll('-', '_');
  if (slug == 'beaches' || slug == 'plajlar' || slug == 'plaj' || slug == 'sahil') {
    return true;
  }
  final l = cat.label.toLowerCase();
  return l.contains('plaj') || l.contains('sahil') || l.contains('beach');
}

/// Tarihi yer ve müzeler
bool isHistoricalMuseumsCategory(PlaceCategory cat) {
  final slug = cat.slug?.toLowerCase().replaceAll('-', '_');
  if (slug == 'historical_museums' ||
      slug == 'historic_sites' ||
      slug == 'tarihi_yer' ||
      slug == 'tarihi_yerler') {
    return true;
  }
  final l = cat.label.toLowerCase();
  final hasTarihi = l.contains('tarihi');
  final hasMuze = l.contains('müze') || l.contains('muze');
  return hasTarihi && hasMuze;
}

/// Chip ve kart rozetlerinde gösterilecek metin (Yerler ekranı için).
String displayPlacesCategoryLabel(PlaceCategory cat, AppLocalizations l10n) {
  if (isHealthTourismCategory(cat)) {
    return l10n.placesCategoryHealthTourismLabel;
  }
  if (isDiscoverSamsunCategory(cat)) {
    return l10n.placesCategoryDiscoverSamsunLabel;
  }
  if (isGastronomyCategory(cat)) {
    return l10n.placesCategoryGastronomyLabel;
  }
  if (isHistoricalMuseumsCategory(cat)) {
    return l10n.placesCategoryHistoricalMuseumsLabel;
  }
  if (isNatureParksCategory(cat)) {
    return l10n.placesCategoryNatureParksLabel;
  }
  if (isBeachesCategory(cat)) {
    return l10n.placesCategoryBeachesLabel;
  }
  return cat.label;
}

/// Mekanın kategori rozet metni.
String displayPlacesCategoryLabelForPlace(
  Place place,
  List<PlaceCategory> categories,
  AppLocalizations l10n,
) {
  if (place.categoryId == null) {
    return place.category ?? '';
  }
  final category = categories.firstWhere(
    (cat) => cat.id == place.categoryId.toString(),
    orElse: () => const PlaceCategory(id: '', label: ''),
  );
  if (category.id.isEmpty) {
    return place.category ?? '';
  }
  return displayPlacesCategoryLabel(category, l10n);
}
