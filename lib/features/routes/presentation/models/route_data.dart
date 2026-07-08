class TourRoute {
  const TourRoute({
    required this.id,
    required this.image,
    required this.title,
    required this.description,
    required this.category,
    required this.duration,
    required this.distance,
    required this.difficulty,
    required this.stops,
    required this.points,
    this.travelMode,
  });

  final String id;
  final String image;
  final String title;
  final String description;
  final String category;
  final String duration;
  final String distance;
  final String difficulty;
  final int stops;
  final int points;
  /// CMS `travel_mode` (ör. walking) — liste kartında ikon için.
  final String? travelMode;
}

class RouteCategory {
  const RouteCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final dynamic icon;
}

