/// Gastronomy model - Yöresel Lezzetler
/// API kılavuzundaki Gastronomy modeline uygun
class Gastronomy {
  const Gastronomy({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.videoUrl,
    this.relatedPlaces = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? videoUrl;
  final List<RelatedPlace> relatedPlaces;

  factory Gastronomy.fromJson(Map<String, dynamic> json) {
    String? resolveUrl(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
      if (raw.startsWith('/')) {
        return 'https://kesfetpanel.smartsamsun.com$raw';
      }
      return 'https://kesfetpanel.smartsamsun.com/$raw';
    }

    return Gastronomy(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      description: (json['description'] ??
              json['description_tr'] ??
              json['description_en']) as String?,
      imageUrl: resolveUrl(json['image_url'] as String?),
      videoUrl: resolveUrl(json['video_url'] as String?),
      relatedPlaces: (json['related_places'] as List<dynamic>?)
              ?.map((e) => RelatedPlace.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'related_places': relatedPlaces.map((e) => e.toJson()).toList(),
    };
  }

  Gastronomy copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? videoUrl,
    List<RelatedPlace>? relatedPlaces,
  }) {
    return Gastronomy(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      relatedPlaces: relatedPlaces ?? this.relatedPlaces,
    );
  }
}

/// Related Place - Yöresel lezzetin satıldığı/sunulduğu mekanlar
class RelatedPlace {
  const RelatedPlace({
    required this.id,
    required this.name,
    this.imageUrl,
    this.district,
    this.rating,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final String? district;
  final double? rating;

  factory RelatedPlace.fromJson(Map<String, dynamic> json) {
    return RelatedPlace(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      district: json['district'] as String? ?? json['address_short'] as String?,
      rating: (json['rating'] != null)
          ? (json['rating'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'district': district,
      'rating': rating,
    };
  }
}
