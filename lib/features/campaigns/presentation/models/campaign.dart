import 'package:flutter/material.dart';

/// Kampanya UI modeli.
///
/// `docs/mobile_camp.md`'de tanımlı `GET /api/v1/mobile/campaigns`
/// yanıtından türetilir. Her kayıt aslında bir **yer** (`type=place`)
/// veya **rota** (`type=route`) temsil eder.
class Campaign {
  const Campaign({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.points,
    required this.claimed,
    required this.progress,
    required this.target,
    required this.reward,
    required this.icon,
    required this.color,
    this.visitedPlaceIds = const [],
    this.externalPlaceId,
    this.externalRouteId,
    this.imageUrl,
    this.daysLeft,
    this.campaignName,
    this.campaignStatus,
    this.routeDistanceKm,
    this.durationMinutes,
  });

  final String id;
  final String type; // "place" | "route"
  final String title;
  final String description;
  final int points;
  final bool claimed;

  /// Route için: visited/total, Place için: 0/1 veya 1/1.
  final int progress;
  final int target;

  /// UI'da gösterilen ödül metni (örn. "25 Puan").
  final String reward;

  final IconData icon;
  final Color color;

  /// Route kampanyalarında, kullanıcının ziyaret ettiği durak ID'leri.
  /// `GET /api/v1/mobile/campaigns` → `progress.visited_place_ids`
  final List<String> visitedPlaceIds;
  /// Place kampanyalarında CMS (content panel) tarafındaki yer ID'si.
  /// `external_place_id` alanından gelir.
  final String? externalPlaceId;

  /// Route kampanyalarında CMS tarafındaki rota ID'si.
  /// Profil paneli `external_id` alanından gelir.
  final String? externalRouteId;

  final String? imageUrl;

  /// Place kampanyaları için bitiş tarihine göre kalan gün.
  final int? daysLeft;

  /// Place kampanyaları için isim ve status ("active|upcoming|expired").
  final String? campaignName;
  final String? campaignStatus;

  /// Route kampanyaları için mesafe ve süre.
  final double? routeDistanceKm;
  final int? durationMinutes;

  double get progressPercent => target == 0 ? 0 : progress / target;

  bool get isRoute => type == 'route';

  /// Tamamlanmış sayılması için:
  /// - place: claimed == true
  /// - route: claimed == true veya progress == target
  bool get isCompleted => claimed || (isRoute && target > 0 && progress >= target);

  /// Backend `GET /api/v1/mobile/campaigns` cevabından UI modelini üretir.
  factory Campaign.fromMobileJson(Map<String, dynamic> json) {
    final type = (json['type'] as String? ?? 'place').toLowerCase();

    // Place kampanyalarında `id` genelde place id'dir.
    // Route kampanyalarında ise backend bazen `id`'yi kampanya id'si,
    // gerçek rota id'sini ise `route_info.route_id` gibi başka alanda dönebiliyor.
    // Bu yüzden route için öncelikle route id'yi arıyoruz.
    final rawId = json['id']?.toString() ?? '';
    final routeInfo = json['route_info'] as Map<String, dynamic>?;
    final routeIdCandidate =
        type == 'route'
            ? (routeInfo?['route_id'] ??
                routeInfo?['id'] ??
                json['route_id'] ??
                json['route'] is Map<String, dynamic>
                    ? (json['route'] as Map<String, dynamic>)['id']
                    : null)
            : null;
    final id = (type == 'route' && routeIdCandidate != null)
        ? routeIdCandidate.toString()
        : rawId;
    final externalPlaceId = json['external_place_id']?.toString();
    final externalRouteId = type == 'route'
        ? (json['external_id']?.toString() ??
            routeInfo?['external_id']?.toString())
        : null;

    final name = json['name'] as String? ?? '';
    final description = json['description'] as String? ?? '';
    final image = json['image'] as String?;
    final colorHex = (json['color'] as String?) ?? '#1976D2';

    final points = _asInt(json['points']) ?? 0;
    final claimed = json['claimed'] as bool? ?? false;

    // Place kampanyaları için kampanya alanları
    final campaignJson =
        json['campaign'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final campaignName = campaignJson['name'] as String?;
    final campaignStatus = campaignJson['status'] as String?;
    final endIso = campaignJson['end'] as String?;

    // Route kampanyaları için progress & route_info
    final progressJson =
        json['progress'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final routeInfoJson =
        json['route_info'] as Map<String, dynamic>? ?? <String, dynamic>{};

    int progress;
    int target;
    List<String> visitedPlaceIds = const [];
    if (type == 'route') {
      final visited = _asInt(progressJson['visited']) ?? 0;
      final total = _asInt(progressJson['total']) ?? 0;
      progress = visited;
      target = total == 0 ? 1 : total;
      visitedPlaceIds = List<String>.from(
        (progressJson['visited_place_ids'] as List?)
                ?.map((e) => e.toString()) ??
            const [],
      );
    } else {
      progress = claimed ? 1 : 0;
      target = 1;
    }

    final routeDistanceKm = _asDouble(routeInfoJson['distance_km']);
    final durationMinutes = _asInt(routeInfoJson['duration_minutes']);

    final reward = points > 0 ? '$points Puan' : '';

    final icon = type == 'route' ? Icons.alt_route_rounded : Icons.place_outlined;

    return Campaign(
      id: id,
      type: type,
      title: name,
      description: description,
      points: points,
      claimed: claimed,
      progress: progress,
      target: target,
      reward: reward,
      icon: icon,
      color: _parseColor(colorHex),
      visitedPlaceIds: visitedPlaceIds,
      externalPlaceId: externalPlaceId,
      externalRouteId: externalRouteId,
      imageUrl: image,
      daysLeft: _calculateDaysLeft(endIso),
      campaignName: campaignName,
      campaignStatus: campaignStatus,
      routeDistanceKm: routeDistanceKm,
      durationMinutes: durationMinutes,
    );
  }

  static Color _parseColor(String hex) {
    var cleaned = hex.trim();
    if (cleaned.isEmpty) {
      return const Color(0xFF1976D2);
    }
    if (cleaned.startsWith('#')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) {
      return const Color(0xFF1976D2);
    }
    return Color(value);
  }

  /// Backend bazen sayısal alanları string olarak döndürebildiği için
  /// hem `num` hem `String` kaynakları güvenli biçimde `int`'e çevirir.
  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed?.toInt();
    }
    return null;
  }

  /// Sayısal/string kaynakları güvenli biçimde `double`'a çevirir.
  static double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed?.toDouble();
    }
    return null;
  }

  static int? _calculateDaysLeft(String? endDateIso) {
    if (endDateIso == null) return null;
    final end = DateTime.tryParse(endDateIso);
    if (end == null) return null;
    final diff = end.difference(DateTime.now()).inDays;
    if (diff < 0) return 0;
    return diff;
  }
}


