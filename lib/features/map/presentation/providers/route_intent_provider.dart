import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A lightweight intent used to start navigation when arriving on the Map screen.
///
/// Used by non-map screens (e.g. Place Detail) to request:
/// - "Open map and draw route to this destination".
class RouteIntent {
  const RouteIntent({
    required this.destination,
    this.placeId,
  });

  final LatLng destination;
  final String? placeId;
}

/// When non-null, MapScreen will fetch a route to the destination and then clear it.
final routeIntentProvider =
    NotifierProvider<RouteIntentNotifier, RouteIntent?>(RouteIntentNotifier.new);

class RouteIntentNotifier extends Notifier<RouteIntent?> {
  @override
  RouteIntent? build() => null;

  void set(RouteIntent intent) {
    state = intent;
  }

  void clear() {
    state = null;
  }
}

