import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/feature_flags.dart';

/// In-memory cache for raw gamification data fetched by [routeDetailProvider].
///
/// Key: route id (as passed to routeDetailProvider).
/// Value: raw Map from `GET /api/v1/mobile/routes/:id`.
///
/// This eliminates the duplicate API call that previously existed when
/// both routeDetailProvider and routeGamificationProvider independently
/// fetched the same endpoint.
class RouteGamificationCache extends Notifier<Map<String, Map<String, dynamic>>> {
  @override
  Map<String, Map<String, dynamic>> build() => {};

  void put(String id, Map<String, dynamic> data) {
    state = {...state, id: data};
  }

  void remove(String id) {
    state = Map.from(state)..remove(id);
  }
}

final routeGamificationCacheProvider =
    NotifierProvider<RouteGamificationCache, Map<String, Map<String, dynamic>>>(
  RouteGamificationCache.new,
);

/// Reads cached gamification data for a specific route.
///
/// Returns the raw gamification Map (stops, progress, points, etc.)
/// that was already fetched and cached by [routeDetailProvider].
/// Returns null if the data hasn't been fetched yet.
final routeGamificationProvider =
    Provider.family<Map<String, dynamic>?, String>((ref, id) {
  // Points/gamification feature flag — kapalıyken hiçbir rota için
  // gamification overlay'i (puan rozeti, ilerleme barı vs.) görünmesin.
  if (!FeatureFlags.pointsEnabled) return null;

  final cache = ref.watch(routeGamificationCacheProvider);
  final data = cache[id];
  if (data != null) return data;

  if (kDebugMode && cache.isNotEmpty) {
    debugPrint(
      '⚠️ [RouteGamification] Cache miss for id=$id '
      '(cached keys: ${cache.keys.toList()})',
    );
  }
  return null;
});
