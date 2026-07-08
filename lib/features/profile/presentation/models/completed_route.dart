/// Completed route model for profile screen
class CompletedRoute {
  const CompletedRoute({
    required this.id,
    required this.name,
    required this.places,
    required this.distance,
    required this.date,
    this.cmsId,
  });

  /// Profil paneli (mobile) dahili route ID'si.
  final int id;

  /// CMS tarafındaki route ID'si (navigasyon için).
  /// Null ise [id] kullanılır.
  final String? cmsId;

  final String name;
  final int places;
  final String distance;
  final String date;

  /// Navigasyonda kullanılacak ID (CMS ID varsa o, yoksa profil paneli ID).
  String get navigationId => cmsId ?? id.toString();
}

