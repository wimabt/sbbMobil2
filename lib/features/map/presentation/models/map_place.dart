import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a place on the map that can be clustered.
class MapPlace {
  MapPlace({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.categoryId,
    this.categorySlug,
    this.categoryIcon,
    required this.rating,
    required this.distance,
    required this.address,
    required this.position,
    this.imageUrl,
    this.phone,
    this.isOpen,
  });

  final String id;
  final String title;
  final String? description;
  final String? category;
  final String? categoryId; // Category ID for filtering
  final String? categorySlug; // Maki icon slug (for backward compatibility)
  final String? categoryIcon; // Icon string from API (e.g., "maki:restaurant", "fontawesome:hospital")
  final double rating;
  final String distance;
  final String address;
  final LatLng position;
  final String? imageUrl;
  final String? phone;
  final bool? isOpen;

  /// Create a copy of MapPlace with modified fields
  MapPlace copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? categoryId,
    String? categorySlug,
    String? categoryIcon,
    double? rating,
    String? distance,
    String? address,
    LatLng? position,
    String? imageUrl,
    String? phone,
    bool? isOpen,
  }) {
    return MapPlace(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category ?? '',
      categoryId: categoryId ?? this.categoryId,
      categorySlug: categorySlug ?? this.categorySlug,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      rating: rating ?? this.rating,
      distance: distance ?? this.distance,
      address: address ?? this.address,
      position: position ?? this.position,
      imageUrl: imageUrl ?? this.imageUrl,
      phone: phone ?? this.phone,
      isOpen: isOpen ?? this.isOpen,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapPlace && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MapPlace(id: $id, title: $title, category: $category)';
}
