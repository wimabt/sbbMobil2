import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api.dart';
import '../../core/services/geofence_service.dart';
import '../../core/services/log_service.dart';

/// `mobile_pending_changes.md` B2 — Geofence bölgelerini backend'den çeker.
///
/// Strateji:
///   * **In-memory cache** (5 dk) — hızlı tekrar erişim için.
///   * **SharedPreferences cache** — offline ilk açılış için son başarılı
///     response saklanır.
///   * **Hardcoded fallback** (`SamsunGeofenceZones.zones`) — hiçbir cache
///     yoksa ve ağ başarısızsa kullanılır. Mevcut davranışla geriye uyumlu.
///
/// `active=false` zone'lar parse sırasında elenir.
class GeofenceZonesRepository {
  GeofenceZonesRepository(this._client);

  final ApiClient _client;

  static const Duration _kMemoryTtl = Duration(minutes: 5);
  static const String _kCacheKey = 'geofence_zones_cache_v1';
  static const String _kCacheTimestampKey = 'geofence_zones_cache_ts_v1';

  List<GeofenceZone>? _memoryCache;
  DateTime? _memoryCacheAt;

  /// Backend'den (veya cache'ten) zone listesini al.
  /// [forceRefresh] true ise memory cache atlanır.
  Future<List<GeofenceZone>> getZones({
    String lang = 'tr',
    bool forceRefresh = false,
  }) async {
    // 1) In-memory cache (hızlı yol)
    if (!forceRefresh &&
        _memoryCache != null &&
        _memoryCacheAt != null &&
        DateTime.now().difference(_memoryCacheAt!) < _kMemoryTtl) {
      return _memoryCache!;
    }

    // 2) Network fetch
    try {
      final response = await _client.get(
        ApiEndpoints.geofenceZones,
        queryParameters: {'lang': lang},
      );

      final raw = response.data;
      final List<dynamic> zonesJson;
      if (raw is Map<String, dynamic>) {
        // Hem `{ zones: [...] }` hem `{ data: { zones: [...] } }` formatlarını yakala.
        final payload = (raw['data'] is Map<String, dynamic>)
            ? raw['data'] as Map<String, dynamic>
            : raw;
        zonesJson = (payload['zones'] as List?) ?? const [];
      } else if (raw is List) {
        zonesJson = raw;
      } else {
        throw StateError('Beklenmeyen response formatı');
      }

      final zones = zonesJson
          .whereType<Map<String, dynamic>>()
          .map(GeofenceZone.fromJson)
          .where((z) => z.active && z.id.isNotEmpty)
          .toList(growable: false);

      _memoryCache = zones;
      _memoryCacheAt = DateTime.now();
      await _persistCache(zonesJson);

      if (kDebugMode) {
        debugPrint('[GeofenceZones] fetched ${zones.length} zone(s) from API');
      }
      return zones;
    } on DioException catch (e) {
      LogService.w(
        'GeofenceZones fetch failed: ${e.message}',
        tag: 'GeofenceZones',
      );
    } catch (e) {
      LogService.w('GeofenceZones parse failed: $e', tag: 'GeofenceZones');
    }

    // 3) Offline cache
    final cached = await _loadPersistedCache();
    if (cached.isNotEmpty) {
      _memoryCache = cached;
      _memoryCacheAt = DateTime.now();
      return cached;
    }

    // 4) Hardcoded fallback — backend hiç hazır değilken davranış kırılmasın.
    LogService.w(
      'GeofenceZones: falling back to hardcoded SamsunGeofenceZones.zones',
      tag: 'GeofenceZones',
    );
    return SamsunGeofenceZones.zones;
  }

  Future<void> _persistCache(List<dynamic> rawJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheKey, jsonEncode(rawJson));
      await prefs.setInt(
        _kCacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      LogService.w('GeofenceZones cache write failed: $e', tag: 'GeofenceZones');
    }
  }

  Future<List<GeofenceZone>> _loadPersistedCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(GeofenceZone.fromJson)
          .where((z) => z.active && z.id.isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      LogService.w('GeofenceZones cache read failed: $e', tag: 'GeofenceZones');
      return const [];
    }
  }
}

final geofenceZonesRepositoryProvider =
    Provider<GeofenceZonesRepository>((ref) {
  // Geofence sbbMobilBackend'te (auth/mobil) — CMS değil. Bu yüzden
  // authApiClientProvider (AuthStaff baseUrl). apiClientProvider (CMS) yanlış
  // backend'e gider → admin'de oluşturulan bölgeler app'e hiç ulaşmaz.
  return GeofenceZonesRepository(ref.watch(authApiClientProvider));
});
