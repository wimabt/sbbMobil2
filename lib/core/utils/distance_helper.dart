import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';

/// Distance calculation helper
/// Supports: Haversine (straight line) and OSRM (driving distance)
class DistanceHelper {
  DistanceHelper._();

  /// Calculate distance using Haversine formula (straight line distance)
  /// Returns distance in meters
  static double calculateHaversineDistance(
    LatLng point1,
    LatLng point2,
  ) {
    const earthRadius = 6371000.0; // meters

    final lat1 = point1.latitude * math.pi / 180;
    final lat2 = point2.latitude * math.pi / 180;
    final dLat = (point2.latitude - point1.latitude) * math.pi / 180;
    final dLng = (point2.longitude - point1.longitude) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calculate driving distance using OSRM (Open Source Routing Machine)
  /// Returns distance in meters, or null if error
  /// 
  /// Public server: https://router.project-osrm.org (free, rate limited)
  /// HTTPS zorunlu: rota sorguları kullanıcı konumu içerir; düz metin
  /// taşınmamalı (§10.4.2). Release ağ yapılandırması cleartext'i zaten engeller.
  static Future<double?> calculateOSRMDistance({
    required LatLng origin,
    required LatLng destination,
    String? osrmBaseUrl,
  }) async {
    try {
      final baseUrl = osrmBaseUrl ?? 'https://router.project-osrm.org';
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ));

      // OSRM Route API: /route/v1/{profile}/{coordinates}
      final url = '$baseUrl/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=false&alternatives=false&steps=false';
      
      final response = await dio.get(url);
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0] as Map<String, dynamic>;
          final distance = route['distance'] as num?;
          
          if (distance != null) {
            return distance.toDouble();
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('⚠️ [DistanceHelper] OSRM error: $e');
      return null;
    }
  }

  /// Calculate driving distance - fallback to Haversine if OSRM fails
  static Future<double> calculateDrivingDistance({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final osrmDistance = await calculateOSRMDistance(
      origin: origin,
      destination: destination,
    );
    
    if (osrmDistance != null) {
      return osrmDistance;
    }
    
    // Fallback: Haversine (kuş uçuşu)
    debugPrint('⚠️ [DistanceHelper] OSRM failed, using Haversine');
    return calculateHaversineDistance(origin, destination);
  }

  /// Format distance in meters to human-readable string
  /// Examples: "150 m", "1.2 km", "5.5 km"
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      final km = distanceInMeters / 1000;
      if (km < 10) {
        return '${km.toStringAsFixed(1)} km';
      } else {
        return '${km.round()} km';
      }
    }
  }

  /// Calculate driving distances for multiple places using OSRM Table API
  /// Returns `Map<String, double>` where key is placeId and value is distanceInMeters
  /// 
  /// This is efficient - single API call for all destinations
  static Future<Map<String, double>> calculateDistancesForPlaces({
    required LatLng origin,
    required Map<String, LatLng> places,
    bool useHaversineFallback = true,
  }) async {
    // OSRM Table API ile toplu hesaplama
    final osrmResults = await calculateDistancesUsingTable(
      origin: origin,
      places: places,
    );
    
    // Tüm sonuçlar geldiyse direkt dön
    if (osrmResults.length == places.length) {
      return osrmResults;
    }
    
    // Eksik olanlar için Haversine fallback
    if (useHaversineFallback) {
      final results = Map<String, double>.from(osrmResults);
      final missingIds = places.keys.where((id) => !results.containsKey(id));
      
      if (missingIds.isNotEmpty) {
        debugPrint('⚠️ [DistanceHelper] OSRM returned ${osrmResults.length}/${places.length}, using Haversine for ${missingIds.length}');
        
        for (final id in missingIds) {
          results[id] = calculateHaversineDistance(origin, places[id]!);
        }
      }
      
      return results;
    }
    
    return osrmResults;
  }

  /// Calculate distances using OSRM Table API
  /// Efficient batch calculation - single request for multiple destinations
  static Future<Map<String, double>> calculateDistancesUsingTable({
    required LatLng origin,
    required Map<String, LatLng> places,
    String? osrmBaseUrl,
  }) async {
    if (places.isEmpty) return {};
    
    try {
      final baseUrl = osrmBaseUrl ?? 'https://router.project-osrm.org';
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));
      
      // Build coordinates: origin;dest1;dest2;...
      final coordinates = [
        '${origin.longitude},${origin.latitude}',
        ...places.values.map((latLng) => '${latLng.longitude},${latLng.latitude}'),
      ].join(';');
      
      // OSRM Table API with distance annotation (not duration!)
      final url = '$baseUrl/table/v1/driving/$coordinates'
          '?sources=0&annotations=distance';
      final response = await dio.get(url);
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final code = data['code'] as String?;
        
        if (code != 'Ok') {
          debugPrint('⚠️ [DistanceHelper] OSRM code: $code');
          return {};
        }
        
        final distances = data['distances'] as List?;
        
        if (distances != null && distances.isNotEmpty) {
          final originDistances = distances[0] as List;
          final results = <String, double>{};
          
          // Origin at index 0, destinations start at index 1
          int index = 1;
          for (final entry in places.entries) {
            if (index < originDistances.length) {
              final distance = originDistances[index] as num?;
              if (distance != null && distance > 0) {
                results[entry.key] = distance.toDouble();
              }
            }
            index++;
          }
          
          return results;
        }
      }
      
      return {};
    } catch (e) {
      debugPrint('⚠️ [DistanceHelper] OSRM Table API error: $e');
      return {};
    }
  }
}
