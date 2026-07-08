import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Route data returned from OSRM.
/// Contains decoded polyline points, distance in km, and duration in minutes.
class RouteData {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;

  const RouteData({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });

  /// Factory: builds [RouteData] from raw OSRM values.
  /// OSRM returns distance in **meters** and duration in **seconds**.
  factory RouteData.fromOsrm({
    required List<LatLng> points,
    required double distanceMeters,
    required double durationSeconds,
  }) {
    return RouteData(
      points: points,
      distanceKm: distanceMeters / 1000.0,
      durationMinutes: durationSeconds / 60.0,
    );
  }
}

/// Service that fetches driving routes from OSRM (Open Source Routing Machine).
///
/// Uses the free public demo server by default.
/// Returns `null` on any error so the caller never crashes.
class OsrmService {
  OsrmService({String? baseUrl})
      // HTTPS zorunlu: rota sorguları kullanıcı konumu içerir (§10.4.2).
      : _baseUrl = baseUrl ?? 'https://router.project-osrm.org';

  final String _baseUrl;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Fetch a driving route between [origin] and [dest].
  ///
  /// Returns decoded [RouteData] or `null` if the request fails / times out.
  Future<RouteData?> getRoute(LatLng origin, LatLng dest) async {
    try {
      // OSRM expects lon,lat order
      final url = '$_baseUrl/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${dest.longitude},${dest.latitude}'
          '?overview=full&geometries=polyline';

      final response = await _dio.get(url);

      if (response.statusCode != 200 || response.data == null) {
        debugPrint('⚠️ [OsrmService] Non-200 response: ${response.statusCode}');
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as String?;
      if (code != 'Ok') {
        debugPrint('⚠️ [OsrmService] OSRM code: $code');
        return null;
      }

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        debugPrint('⚠️ [OsrmService] No routes returned');
        return null;
      }

      final route = routes[0] as Map<String, dynamic>;
      final geometry = route['geometry'] as String?;
      final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;

      if (geometry == null || geometry.isEmpty) {
        debugPrint('⚠️ [OsrmService] Empty geometry');
        return null;
      }

      // Decode the encoded polyline string
      final decoded = PolylinePoints().decodePolyline(geometry);
      final points = decoded
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      if (points.isEmpty) {
        debugPrint('⚠️ [OsrmService] Decoded polyline is empty');
        return null;
      }

      return RouteData.fromOsrm(
        points: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
    } on DioException catch (e) {
      debugPrint('⚠️ [OsrmService] Dio error: ${e.type} – ${e.message}');
      return null;
    } catch (e) {
      debugPrint('⚠️ [OsrmService] Unexpected error: $e');
      return null;
    }
  }

  /// Birden fazla durak için sıralı güzergah hesaplar (§6.5.2 — itinerary).
  ///
  /// `waypoints` liste sırası ziyaret sırasıdır. En az 2 nokta gereklidir.
  /// Tek bir OSRM isteği ile tüm `via` waypoint'leri verilir; tek polyline +
  /// toplam km/dk geri döner.
  Future<RouteData?> getRouteMultiStop(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;
    try {
      final coords = waypoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final url = '$_baseUrl/route/v1/driving/$coords'
          '?overview=full&geometries=polyline';

      final response = await _dio.get(url);
      if (response.statusCode != 200 || response.data == null) {
        debugPrint(
            '⚠️ [OsrmService] Multi-stop non-200: ${response.statusCode}');
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as String?;
      if (code != 'Ok') {
        debugPrint('⚠️ [OsrmService] Multi-stop OSRM code: $code');
        return null;
      }

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final geometry = route['geometry'] as String?;
      final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;
      if (geometry == null || geometry.isEmpty) return null;

      final decoded = PolylinePoints().decodePolyline(geometry);
      final points =
          decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
      if (points.isEmpty) return null;

      return RouteData.fromOsrm(
        points: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
    } on DioException catch (e) {
      debugPrint(
          '⚠️ [OsrmService] Multi-stop Dio error: ${e.type} – ${e.message}');
      return null;
    } catch (e) {
      debugPrint('⚠️ [OsrmService] Multi-stop unexpected: $e');
      return null;
    }
  }
}
