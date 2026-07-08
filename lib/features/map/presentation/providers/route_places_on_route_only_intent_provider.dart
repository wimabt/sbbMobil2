import 'package:flutter_riverpod/flutter_riverpod.dart';

class RouteStopsFilterIntent {
  const RouteStopsFilterIntent({
    required this.placeIds,
    this.routeTitle,
  });

  final Set<String> placeIds;
  final String? routeTitle;
}

/// When set, `MapScreen` should show ONLY the route stops (places) specified
/// by `placeIds`. It also controls the bottom bar UI (show route title + X).
final routePlacesOnRouteOnlyIntentProvider = NotifierProvider<
    RoutePlacesOnRouteOnlyIntentNotifier, RouteStopsFilterIntent?>(
  RoutePlacesOnRouteOnlyIntentNotifier.new,
);

class RoutePlacesOnRouteOnlyIntentNotifier
    extends Notifier<RouteStopsFilterIntent?> {
  @override
  RouteStopsFilterIntent? build() => null;

  void set({
    required Set<String> placeIds,
    required String routeTitle,
  }) {
    state = RouteStopsFilterIntent(placeIds: placeIds, routeTitle: routeTitle);
  }

  void clear() => state = null;
}

