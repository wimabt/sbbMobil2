import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';

/// Cached user location for the whole app session.
///
/// Purpose:
/// - Avoid re-requesting GPS / permissions every time user returns to Map.
/// - Provide a single source of truth for "origin" when drawing routes.
final userLocationProvider =
    NotifierProvider<UserLocationNotifier, LatLng?>(UserLocationNotifier.new);

class UserLocationNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  /// Returns cached location if present, otherwise fetches once and caches it.
  Future<LatLng?> getOrFetch() async {
    if (state != null) return state;

    final location = await LocationService.getCurrentLocation() ??
        await LocationService.getLastKnownLocation();

    if (location != null) {
      state = location;
    }

    return state;
  }

  /// Manually update cached location (e.g. after a successful fetch).
  void set(LatLng location) {
    state = location;
  }
}

