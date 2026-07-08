import 'package:flutter/foundation.dart';

import '../../core/utils/image_url_helper.dart';

// ─── Campaign Meta ──────────────────────────────────────────────────

/// Kampanya bazlı puan sistemi metası.
///
/// API'den `campaign` objesi olarak döner:
/// ```json
/// { "name": "Mart Kampanyası", "start": "...", "end": "...", "status": "active" }
/// ```
@immutable
class CampaignMeta {
  const CampaignMeta({
    this.name,
    this.start,
    this.end,
    this.status = CampaignStatus.active,
  });

  final String? name;
  final DateTime? start;
  final DateTime? end;
  final CampaignStatus status;

  bool get isActive => status == CampaignStatus.active;
  bool get isUpcoming => status == CampaignStatus.upcoming;
  bool get isExpired => status == CampaignStatus.expired;

  factory CampaignMeta.fromJson(Map<String, dynamic> json) {
    return CampaignMeta(
      name: json['name'] as String?,
      start: json['start'] != null
          ? DateTime.tryParse(json['start'] as String)
          : null,
      end: json['end'] != null
          ? DateTime.tryParse(json['end'] as String)
          : null,
      status: CampaignStatus.fromString(json['status'] as String? ?? 'active'),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'start': start?.toIso8601String(),
        'end': end?.toIso8601String(),
        'status': status.value,
      };

  CampaignMeta copyWith({
    String? name,
    DateTime? start,
    DateTime? end,
    CampaignStatus? status,
  }) {
    return CampaignMeta(
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      status: status ?? this.status,
    );
  }
}

/// Kampanya durumu.
enum CampaignStatus {
  active('active'),
  upcoming('upcoming'),
  expired('expired');

  const CampaignStatus(this.value);
  final String value;

  factory CampaignStatus.fromString(String s) {
    return CampaignStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => CampaignStatus.active,
    );
  }
}

// ─── Place Model ────────────────────────────────────────────────────

/// Place model - Mekan
/// API kılavuzundaki Place modeline uygun
class Place {
  const Place({
    required this.id,
    required this.name,
    this.externalId,
    this.category,
    this.categoryId,
    this.description,
    this.subcategories = const [],
    this.tags = const [],
    this.lat,
    this.lng,
    this.imageUrl,
    this.photoUrls = const [],
    this.videoUrl,
    this.featured = false,
    this.rating,
    this.reviewCount,
    this.distance,
    this.address,
    this.openHours,
    this.phone,
    this.videoUrls = const [],
    this.notes,
    this.arModelUrl,
    this.arModelName,
    // Mobile API alanları
    this.points,
    this.markerIcon,
    this.markerColor,
    this.visitCount,
    this.visited = false,
    this.lastVisitedAt,
    // Kampanya bazlı puan sistemi (mobile_campaign.md)
    this.claimed = false,
    this.campaign,
  });

  /// System B (NestJS Gamification) internal ID.
  /// Use for: point collection, visit, check-in, wallet, campaign API calls.
  final String id;

  /// System A (PHP CMS) content ID.
  /// Use for: fetching descriptions, images, stops, static content.
  /// Populated from `/api/v1/mobile/places` response `external_id` field.
  final String? externalId;

  /// Returns the correct ID for CMS content API calls.
  /// Falls back to [id] when [externalId] is not yet resolved.
  String get cmsContentId => externalId ?? id;

  final String name;
  final String? description;
  final String? category;
  final int? categoryId;
  final List<String> subcategories;
  final List<String> tags;
  final double? lat;
  final double? lng;
  final String? imageUrl;
  final List<String> photoUrls;
  final String? videoUrl;
  final bool featured;
  final double? rating;
  final int? reviewCount;
  final String? distance;
  final String? address;
  final String? openHours;
  final String? phone;
  final List<String> videoUrls;
  final String? notes;
  final String? arModelUrl;
  final String? arModelName;

  bool get hasArModel => arModelUrl != null && arModelUrl!.isNotEmpty;

  // ─── Mobile API alanları ──────────────────────────────────────────
  final int? points;
  final String? markerIcon;
  final String? markerColor;
  final int? visitCount;
  final bool visited;            // Geriye dönük uyum (kampanya bağımsız)
  final DateTime? lastVisitedAt;

  // ─── Kampanya bazlı puan sistemi (mobile_campaign.md §2) ─────────
  /// Kullanıcı bu lokasyonun puanını mevcut kampanyada aldı mı?
  final bool claimed;
  /// Kampanya metası (name, start, end, status)
  final CampaignMeta? campaign;

  /// Puanı mevcut kampanyada toplanabilir mi?
  /// `!claimed && campaign.status == active && points > 0`
  bool get canCollectPoints =>
      !claimed &&
      (campaign?.isActive ?? true) &&
      points != null &&
      points! > 0;

  /// Puan bu kampanyada zaten alınmış mı?
  ///
  /// Sadece [claimed] kullanılır. [visited] / `last_visited_at` “bu mekanda
  /// bulundu” / görüntüleme izi olabilir; girişte true iken `claimed` false
  /// olduğu sürece puan toplama kartı gösterilmelidir.
  bool get isPointsClaimed => claimed;

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'].toString(),
      externalId: json['external_id']?.toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      categoryId: json['category_id'] != null 
          ? (json['category_id'] is int 
              ? json['category_id'] as int 
              : int.tryParse(json['category_id'].toString()))
          : null,
      subcategories: List<String>.from(json['subcategories'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      lat: (json['lat'] != null) ? (json['lat'] as num).toDouble() : null,
      lng: (json['lng'] != null) ? (json['lng'] as num).toDouble() : null,
      imageUrl: json['image_url'] as String? ?? json['image'] as String?,
      photoUrls: List<String>.from(
        json['photo_urls'] ?? json['photos'] ?? [],
      ),
      videoUrl: json['video_url'] as String? ?? json['video'] as String?,
      videoUrls: List<String>.from(json['videos'] ?? []),
      featured: json['featured'] == true,
      rating: (json['rating'] != null)
          ? (json['rating'] as num).toDouble()
          : null,
      reviewCount: json['review_count'] as int? ?? json['reviews'] as int?,
      distance: json['distance'] is int
          ? json['distance'].toString()
          : json['distance'] as String?,
      address: json['address'] as String?,
      openHours: json['open_hours'] as String? ?? json['hours'] as String?,
      phone: json['phone'] as String?,
      notes: json['info'] as String? ?? json['notes'] as String? ?? json['note'] as String? ?? json['note_text'] as String?,
      arModelUrl: _maybeRewriteUrl(json['ar_model_url'] as String? ?? json['arModelUrl'] as String?),
      arModelName: json['ar_model_name'] as String? ?? json['arModelName'] as String?,
      // Mobile API alanları
      points: _asInt(json['points']),
      markerIcon: json['marker_icon'] as String?,
      markerColor: json['marker_color'] as String?,
      visitCount: _asInt(json['visit_count']),
      visited: _asBool(json['visited']),
      lastVisitedAt: json['last_visited_at'] != null
          ? DateTime.tryParse(json['last_visited_at'].toString())
          : null,
      // Kampanya bazlı puan sistemi
      claimed: _asBool(json['claimed']),
      campaign: json['campaign'] is Map<String, dynamic>
          ? CampaignMeta.fromJson(json['campaign'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'external_id': externalId,
      'name': name,
      'description': description,
      'category': category,
      'subcategories': subcategories,
      'tags': tags,
      'lat': lat,
      'lng': lng,
      'image_url': imageUrl,
      'photo_urls': photoUrls,
      'video_url': videoUrl,
      'featured': featured,
      'rating': rating,
      'review_count': reviewCount,
      'distance': distance,
      'address': address,
      'open_hours': openHours,
      'phone': phone,
      'videos': videoUrls,
      'notes': notes,
      'ar_model_url': arModelUrl,
      'ar_model_name': arModelName,
      'points': points,
      'marker_icon': markerIcon,
      'marker_color': markerColor,
      'visit_count': visitCount,
      'visited': visited,
      'last_visited_at': lastVisitedAt?.toIso8601String(),
      'claimed': claimed,
      'campaign': campaign?.toJson(),
    };
  }

  Place copyWith({
    String? id,
    String? externalId,
    String? name,
    String? description,
    String? category,
    int? categoryId,
    List<String>? subcategories,
    List<String>? tags,
    double? lat,
    double? lng,
    String? imageUrl,
    List<String>? photoUrls,
    String? videoUrl,
    bool? featured,
    double? rating,
    int? reviewCount,
    String? distance,
    String? address,
    String? openHours,
    String? phone,
    List<String>? videoUrls,
    String? notes,
    String? arModelUrl,
    String? arModelName,
    int? points,
    String? markerIcon,
    String? markerColor,
    int? visitCount,
    bool? visited,
    DateTime? lastVisitedAt,
    bool? claimed,
    CampaignMeta? campaign,
  }) {
    return Place(
      id: id ?? this.id,
      externalId: externalId ?? this.externalId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      subcategories: subcategories ?? this.subcategories,
      tags: tags ?? this.tags,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      imageUrl: imageUrl ?? this.imageUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      featured: featured ?? this.featured,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      distance: distance ?? this.distance,
      address: address ?? this.address,
      openHours: openHours ?? this.openHours,
      phone: phone ?? this.phone,
      videoUrls: videoUrls ?? this.videoUrls,
      notes: notes ?? this.notes,
      arModelUrl: arModelUrl ?? this.arModelUrl,
      arModelName: arModelName ?? this.arModelName,
      points: points ?? this.points,
      markerIcon: markerIcon ?? this.markerIcon,
      markerColor: markerColor ?? this.markerColor,
      visitCount: visitCount ?? this.visitCount,
      visited: visited ?? this.visited,
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
      claimed: claimed ?? this.claimed,
      campaign: campaign ?? this.campaign,
    );
  }
}

/// Place Category - Mekan kategorisi
class PlaceCategory {
  const PlaceCategory({
    required this.id,
    required this.label,
    this.slug,
    this.icon,
    this.color,
    this.count,
    this.subcategories = const [],
  });

  final String id; // String olarak tutuyoruz (API'den int geliyor ama string'e çeviriyoruz)
  final String label; // API'den 'name' olarak geliyor
  final String? slug; // API'den 'slug' olarak geliyor
  final String? icon;
  final String? color; // API'den 'color' olarak geliyor
  final int? count; // API'den 'count' olarak geliyor (place sayısı)
  final List<PlaceCategory> subcategories;

  factory PlaceCategory.fromJson(Map<String, dynamic> json) {
    return PlaceCategory(
      id: json['id'].toString(),
      label: json['name'] as String? ?? json['label'] as String? ?? '',
      slug: json['slug'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      count: json['count'] as int?,
      subcategories: (json['subcategories'] as List?)
              ?.map((e) => PlaceCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

String? _maybeRewriteUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  return rewriteStorageUrl(url);
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = num.tryParse(value);
    return parsed?.toInt();
  }
  return null;
}

bool _asBool(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final s = value.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return false;
}
