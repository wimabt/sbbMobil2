import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/services/osrm_service.dart';

/// Riverpod provider for the active navigation route.
///
/// State is nullable: `null` means no route is currently active.
final routeNavigationProvider =
    NotifierProvider<RouteNavigationNotifier, RouteData?>(
  RouteNavigationNotifier.new,
);

class RouteNavigationNotifier extends Notifier<RouteData?> {
  final OsrmService _osrmService = OsrmService();

  @override
  RouteData? build() => null;

  /// Set an active route polyline without calling OSRM.
  ///
  /// Used by "Route detail" screens to show route-related place filtering.
  void setRouteFromPoints({
    required List<LatLng> points,
    double distanceKm = 0,
    double durationMinutes = 0,
  }) {
    if (points.isEmpty) return;
    state = RouteData(
      points: points,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
    );
  }

  /// Fetch a driving route from [origin] to [dest] via OSRM.
  /// Updates state on success; leaves it unchanged on failure.
  Future<void> fetchRoute(LatLng origin, LatLng dest) async {
    final routeData = await _osrmService.getRoute(origin, dest);
    if (routeData != null) {
      state = routeData;
    }
  }

  /// Clear the active route (hides polyline & info pill).
  void clearRoute() {
    state = null;
  }
}
