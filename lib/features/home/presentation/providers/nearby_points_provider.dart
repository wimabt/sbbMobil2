import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/point_collection_service.dart';
import '../../../../core/utils/distance_helper.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../places/presentation/providers/places_provider.dart';

/// Yakındaki puanlı mekanları temsil eden model.
@immutable
class NearbyPointPlace {
  final String placeId;
  final String placeName;
  final int points;
  final double distanceMeters;
  final PointCollectionStatus status;

  const NearbyPointPlace({
    required this.placeId,
    required this.placeName,
    required this.points,
    required this.distanceMeters,
    required this.status,
  });

  String get formattedDistance => DistanceHelper.formatDistance(distanceMeters);
}

/// Kullanıcının yakınındaki puanlı mekanları periyodik olarak tarayan provider.
///
/// Scaffold veya home ekranda dinlenerek Banner gösterilir.
/// Sadece giriş yapılmışsa ve puanlı mekanlar varsa çalışır.
final nearbyPointPlacesProvider =
    FutureProvider.autoDispose<List<NearbyPointPlace>>((ref) async {
  // Points/gamification feature flag — kapalıyken konum/timer çalıştırma.
  if (!FeatureFlags.pointsEnabled) {
    return const [];
  }

  final authState = ref.watch(authProvider);
  if (authState.status != AuthStatus.authenticated) {
    return const [];
  }

  final userLocation = await LocationService.getCurrentLocation() ??
      await LocationService.getLastKnownLocation();

  if (userLocation == null) return const [];

  final placesState = ref.watch(placesProvider);
  final allPlaces = placesState.allPlaces;

  final nearby = <NearbyPointPlace>[];

  for (final place in allPlaces) {
    if (place.points == null || place.points == 0) continue;
    // Kampanya bazlı kontrol: claimed VEYA eski visited — her iki durumda da atla
    if (place.isPointsClaimed) continue;
    // Kampanya aktif değilse yakınlık kontrolü yapma
    if (place.campaign != null && !place.campaign!.isActive) continue;
    if (place.lat == null || place.lng == null) continue;

    final distance = DistanceHelper.calculateHaversineDistance(
      userLocation,
      LatLng(place.lat!, place.lng!),
    );

    if (distance <= kNearbyNotificationRadiusMeters) {
      nearby.add(NearbyPointPlace(
        placeId: place.id,
        placeName: place.name,
        points: place.points!,
        distanceMeters: distance,
        status: PointCollectionService.statusFromDistance(distance),
      ));
    }
  }

  nearby.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

  // 30 saniyede bir yenile
  final timer = Timer(const Duration(seconds: 30), () {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  return nearby;
});
