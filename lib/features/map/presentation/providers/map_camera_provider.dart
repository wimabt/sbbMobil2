import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Persists the map camera state across tab switches for the entire app session.
///
/// **Problem solved:**
/// `MapScreen` is a `ConsumerStatefulWidget` inside a `ShellRoute`. Every time
/// the user switches away from the map tab and comes back, `initState` re-runs,
/// the `_didMoveToUserLocation` flag resets, and the camera re-animates to the
/// user's GPS position — destroying whatever region the user was exploring.
///
/// **Industry-standard approach (Google Maps, Apple Maps, Uber):**
/// 1. Remember the last camera position and restore it when the map is re-opened.
/// 2. Auto-center on the user's location *only once* per app session.
/// 3. Let the user explicitly tap "My Location" to go back to their position.
final mapCameraProvider =
    NotifierProvider<MapCameraNotifier, MapCameraState>(MapCameraNotifier.new);

class MapCameraState {
  const MapCameraState({
    this.lastCameraPosition,
    this.didInitialMoveToUser = false,
  });

  /// The last saved camera position (target + zoom).
  final CameraPosition? lastCameraPosition;

  /// Whether we already animated the camera to the user's GPS position
  /// at least once during this app session.
  final bool didInitialMoveToUser;

  MapCameraState copyWith({
    CameraPosition? lastCameraPosition,
    bool? didInitialMoveToUser,
  }) {
    return MapCameraState(
      lastCameraPosition: lastCameraPosition ?? this.lastCameraPosition,
      didInitialMoveToUser: didInitialMoveToUser ?? this.didInitialMoveToUser,
    );
  }
}

class MapCameraNotifier extends Notifier<MapCameraState> {
  @override
  MapCameraState build() => const MapCameraState();

  /// Save the current camera position so it can be restored later.
  void savePosition(CameraPosition position) {
    state = state.copyWith(lastCameraPosition: position);
  }

  /// Mark that the initial "fly to my location" has been performed.
  void markInitialMoveDone() {
    if (!state.didInitialMoveToUser) {
      state = state.copyWith(didInitialMoveToUser: true);
    }
  }
}
