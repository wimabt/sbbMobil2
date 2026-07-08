/// Route model - Rota
/// API'den gelen Route modeline uygun
class Route {
  const Route({
    required this.id,
    required this.name,
    this.description,
    this.slug,
    this.cover,
    this.coverUrl,
    this.linkUrl,
    this.travelMode,
    this.distanceKm,
    this.durationMinutes,
    this.difficultyLevel,
    this.videoUrl,
    this.videos = const [],
    this.places = const [],
    // Mobile API alanları (flutter-integration.md §9)
    this.color,
    this.placeCount,
    this.completionPoints,
    this.bonusPoints,
    this.totalPossiblePoints,
    this.progress,
    this.externalId,
  });

  /// System B (NestJS Gamification) internal ID.
  /// Use for: route start, stop visit, progress, campaign API calls.
  final String id;

  /// System A (PHP CMS) content ID.
  /// Use for: fetching route details, stops, descriptions, static assets.
  /// Populated from `/api/v1/mobile/routes` response `external_id` field.
  final String? externalId;

  /// Returns the correct ID for CMS content API calls.
  /// Falls back to [id] when [externalId] is not yet resolved.
  String get cmsContentId => externalId ?? id;

  final String name;
  final String? description;
  final String? slug;
  /// Orijinal kapak görseli (yüksek çözünürlük) - genelde relative path
  final String? cover;
  /// Thumbnail / optimize edilmiş kapak URL'i (liste ekranı için)
  final String? coverUrl;
  final String? linkUrl;
  final String? travelMode;
  final double? distanceKm;
  final int? durationMinutes;
  final String? difficultyLevel;
  final String? videoUrl;
  final List<String> videos;
  final List<RoutePlace> places;

  // ─── Mobile API alanları (flutter-integration.md §9) ─────────────
  final String? color;              // Rota rengi (hex)
  final int? placeCount;            // Durak sayısı
  final int? completionPoints;      // Tamamlama puanı
  final int? bonusPoints;           // Tüm duraklar bonusu
  final int? totalPossiblePoints;   // Toplam kazanılabilecek puan
  final Map<String, dynamic>? progress; // İlerleme bilgisi

  factory Route.fromJson(Map<String, dynamic> json) {
    // Backend farklı alan isimleri kullanabilir: places, stops, route_places, waypoints
    List<RoutePlace> parsedPlaces = const [];
    
    // Önce places alanını kontrol et
    if (json['places'] != null && json['places'] is List && (json['places'] as List).isNotEmpty) {
      parsedPlaces = (json['places'] as List)
          .map((e) => RoutePlace.fromJson(e as Map<String, dynamic>))
          .toList();
    } 
    // Alternatif: stops
    else if (json['stops'] != null && json['stops'] is List && (json['stops'] as List).isNotEmpty) {
      parsedPlaces = (json['stops'] as List)
          .map((e) => RoutePlace.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    // Alternatif: route_places
    else if (json['route_places'] != null && json['route_places'] is List && (json['route_places'] as List).isNotEmpty) {
      parsedPlaces = (json['route_places'] as List)
          .map((e) => RoutePlace.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    // Alternatif: waypoints
    else if (json['waypoints'] != null && json['waypoints'] is List && (json['waypoints'] as List).isNotEmpty) {
      parsedPlaces = (json['waypoints'] as List)
          .map((e) => RoutePlace.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Route(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      slug: json['slug'] as String?,
      // Backend hem cover (orijinal) hem cover_url (thumbnail) gönderebilir
      cover: json['cover'] as String?,
      coverUrl: json['cover_url'] as String?,
      linkUrl: json['link_url'] as String?,
      travelMode: json['travel_mode'] as String?,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
      durationMinutes: json['duration_minutes'] as int?,
      difficultyLevel: json['difficulty_level'] as String?,
      videoUrl: json['video_url'] as String?,
      videos: json['videos'] != null
          ? List<String>.from(json['videos'] as List)
          : const [],
      places: parsedPlaces,
      // Mobile API alanları
      color: json['color'] as String?,
      placeCount: json['place_count'] as int?,
      completionPoints: json['completion_points'] as int?,
      bonusPoints: json['bonus_points'] as int?,
      totalPossiblePoints: int.tryParse(
            json['total_possible_points']?.toString() ?? '0',
          ) ??
          0,
      progress: json['progress'] as Map<String, dynamic>?,
      externalId: json['external_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'slug': slug,
      'cover': cover,
      'cover_url': coverUrl,
      'link_url': linkUrl,
      'travel_mode': travelMode,
      'distance_km': distanceKm,
      'duration_minutes': durationMinutes,
      'difficulty_level': difficultyLevel,
      'video_url': videoUrl,
      'videos': videos,
      'places': places.map((p) => p.toJson()).toList(),
      'color': color,
      'place_count': placeCount,
      'completion_points': completionPoints,
      'bonus_points': bonusPoints,
      'total_possible_points': totalPossiblePoints,
      'progress': progress,
      'external_id': externalId,
    };
  }

  Route copyWith({
    String? id,
    String? name,
    String? description,
    String? slug,
    String? cover,
    String? coverUrl,
    String? linkUrl,
    String? travelMode,
    double? distanceKm,
    int? durationMinutes,
    String? difficultyLevel,
    String? videoUrl,
    List<String>? videos,
    List<RoutePlace>? places,
    String? color,
    int? placeCount,
    int? completionPoints,
    int? bonusPoints,
    int? totalPossiblePoints,
    Map<String, dynamic>? progress,
    String? externalId,
  }) {
    return Route(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      slug: slug ?? this.slug,
      cover: cover ?? this.cover,
      coverUrl: coverUrl ?? this.coverUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      travelMode: travelMode ?? this.travelMode,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      videoUrl: videoUrl ?? this.videoUrl,
      videos: videos ?? this.videos,
      places: places ?? this.places,
      color: color ?? this.color,
      placeCount: placeCount ?? this.placeCount,
      completionPoints: completionPoints ?? this.completionPoints,
      bonusPoints: bonusPoints ?? this.bonusPoints,
      totalPossiblePoints: totalPossiblePoints ?? this.totalPossiblePoints,
      progress: progress ?? this.progress,
      externalId: externalId ?? this.externalId,
    );
  }
}

/// Route Place - Rota ile ilişkili yer
class RoutePlace {
  const RoutePlace({
    required this.id,
    this.externalId,
    this.name,
    this.lat,
    this.lng,
    this.imageUrl,
    this.order,
    // Mobile API alanları (flutter-integration.md §9)
    this.category,
    this.stopOrder,
    this.stopPoints,
    this.visited = false,
  });

  /// System B (Gamification) internal ID for this stop.
  /// Use for: visit POST calls to gamification backend.
  final String id;

  /// System A (CMS) content ID for this stop.
  /// Use for: fetching stop details, images, descriptions from CMS.
  final String? externalId;

  /// Returns the correct ID for CMS content API calls.
  String get cmsContentId => externalId ?? id;

  final String? name;
  final double? lat;
  final double? lng;
  final String? imageUrl;
  final int? order;

  // ─── Mobile API alanları ──────────────────────────────────────
  final String? category;   // Durak kategorisi
  final int? stopOrder;     // Durak sırası
  final int? stopPoints;    // Duraktan kazanılacak puan
  final bool visited;       // Ziyaret edildi mi

  factory RoutePlace.fromJson(Map<String, dynamic> json) {
    return RoutePlace(
      id: json['id'].toString(),
      externalId: json['external_id']?.toString(),
      name: json['name'] as String?,
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
      imageUrl: json['image_url'] as String?,
      order: json['order'] as int? ?? json['order_index'] as int?,
      category: json['category'] as String?,
      stopOrder: json['stop_order'] as int?,
      stopPoints: json['stop_points'] as int?,
      visited: json['visited'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'external_id': externalId,
      'name': name,
      'lat': lat,
      'lng': lng,
      'image_url': imageUrl,
      'order': order,
      'category': category,
      'stop_order': stopOrder,
      'stop_points': stopPoints,
      'visited': visited,
    };
  }
}
