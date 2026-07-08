import 'place.dart';

/// PlaceSummary model - Liste ve Harita görünümleri için optimize edilmiş model
/// API: /places/summary endpoint'inden dönen veriyi temsil eder
class PlaceSummary {
  const PlaceSummary({
    required this.id,
    required this.name,
    this.externalId,
    this.description,
    this.categoryId,
    this.categoryName,
    this.lat,
    this.lng,
    this.imageUrl,
    this.thumbnailUrl,
    this.rating,
    this.reviewCount,
    this.featured = false,
    this.distanceMeters,
    this.distanceFormatted,
    this.distanceType,
  });

  /// System B (Gamification) internal ID.
  final String id;

  /// System A (CMS) content ID.
  final String? externalId;

  /// Returns the correct ID for CMS content API calls.
  String get cmsContentId => externalId ?? id;

  final String name;
  final String? description;
  final int? categoryId;
  final String? categoryName; // Kategori label'ı (API'den gelebilir veya client'ta resolve edilir)
  final double? lat;
  final double? lng;
  final String? imageUrl;
  final String? thumbnailUrl;
  final double? rating;
  final int? reviewCount;
  final bool featured;
  
  // Mesafe bilgisi (server-side hesaplanmış)
  final int? distanceMeters;
  final String? distanceFormatted;
  final String? distanceType; // "straight_line" veya "driving"

  /// Formatlanmış mesafe string'i döndürür
  /// Önce server'dan gelen formatted değeri kullanır, yoksa meters'dan hesaplar
  String? get distance {
    if (distanceFormatted != null && distanceFormatted!.isNotEmpty) {
      return distanceFormatted;
    }
    if (distanceMeters != null) {
      if (distanceMeters! < 1000) {
        return '$distanceMeters m';
      } else {
        final km = distanceMeters! / 1000;
        if (km < 10) {
          return '${km.toStringAsFixed(1)} km';
        } else {
          return '${km.round()} km';
        }
      }
    }
    return null;
  }

  factory PlaceSummary.fromJson(Map<String, dynamic> json) {
    return PlaceSummary(
      id: json['id'].toString(),
      externalId: json['external_id']?.toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      categoryId: json['category_id'] != null 
          ? (json['category_id'] is int 
              ? json['category_id'] as int 
              : int.tryParse(json['category_id'].toString()))
          : null,
      categoryName: json['category_name'] as String? ?? json['category'] as String?,
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
      imageUrl: json['image_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      reviewCount: json['review_count'] as int?,
      featured: json['featured'] == true,
      distanceMeters: json['distance_meters'] as int?,
      distanceFormatted: json['distance_formatted'] as String?,
      distanceType: json['distance_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'external_id': externalId,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'category_name': categoryName,
      'lat': lat,
      'lng': lng,
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'rating': rating,
      'review_count': reviewCount,
      'featured': featured,
      'distance_meters': distanceMeters,
      'distance_formatted': distanceFormatted,
      'distance_type': distanceType,
    };
  }

  PlaceSummary copyWith({
    String? id,
    String? externalId,
    String? name,
    String? description,
    int? categoryId,
    String? categoryName,
    double? lat,
    double? lng,
    String? imageUrl,
    String? thumbnailUrl,
    double? rating,
    int? reviewCount,
    bool? featured,
    int? distanceMeters,
    String? distanceFormatted,
    String? distanceType,
  }) {
    return PlaceSummary(
      id: id ?? this.id,
      externalId: externalId ?? this.externalId,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      featured: featured ?? this.featured,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      distanceFormatted: distanceFormatted ?? this.distanceFormatted,
      distanceType: distanceType ?? this.distanceType,
    );
  }

  /// PlaceSummary'yi Place'e dönüştürür (liste UI'ı için geriye uyumluluk)
  Place toPlace() {
    return Place(
      id: id,
      externalId: externalId,
      name: name,
      description: description,
      categoryId: categoryId,
      category: categoryName,
      lat: lat,
      lng: lng,
      imageUrl: thumbnailUrl ?? imageUrl, // Thumbnail varsa kullan
      rating: rating,
      reviewCount: reviewCount,
      featured: featured,
      distance: distance, // Hesaplanmış mesafe
    );
  }
}
