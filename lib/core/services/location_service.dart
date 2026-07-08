import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Location service for getting user's current location
/// Safely handles iOS/Android differences and potential plugin errors
class LocationService {
  LocationService._();

  // ─── Mock / Override desteği (debug mode) ──────────────────────────
  // Fiziksel cihazda test ederken sahte konum ayarlamak için kullanılır.
  // Production build'de bu alan her zaman null kalır.
  static LatLng? _mockLocation;

  /// Debug: Sahte konum ayarla. null geçersen gerçek GPS'e geri döner.
  static void setMockLocation(LatLng? location) {
    _mockLocation = location;
  }

  /// Debug: Mevcut mock konum (null = gerçek GPS kullanılıyor).
  static LatLng? get mockLocation => _mockLocation;

  /// Check if location services are enabled
  /// Returns false on any error (safer for iOS)
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } on PlatformException catch (e) {
      debugPrint('⚠️ [LocationService] Platform error checking location service: $e');
      return false;
    } catch (e) {
      debugPrint('⚠️ [LocationService] Error checking location service: $e');
      return false;
    }
  }

  /// Check location permissions
  /// Returns denied on any error (safer for iOS)
  static Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } on PlatformException catch (e) {
      debugPrint('⚠️ [LocationService] Platform error checking permission: $e');
      return LocationPermission.denied;
    } catch (e) {
      debugPrint('⚠️ [LocationService] Error checking permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Request location permissions
  /// Returns denied on any error (safer for iOS)
  static Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } on PlatformException catch (e) {
      debugPrint('⚠️ [LocationService] Platform error requesting permission: $e');
      return LocationPermission.denied;
    } catch (e) {
      debugPrint('⚠️ [LocationService] Error requesting permission: $e');
      return LocationPermission.denied;
    }
  }

  // Son başarılı GPS konumu + zamanı (proximity timer'lar arası paylaşım)
  static LatLng? _cachedLocation;
  static DateTime? _cachedAt;

  /// Son başarılı GPS konumu (cache). Proximity timer'lar arasında paylaşılır.
  static LatLng? get cachedLocation => _cachedLocation;

  /// Get current location
  /// Returns null if permission denied, location unavailable, or any error occurs
  /// Safe to call on iOS - will not crash
  static Future<LatLng?> getCurrentLocation() async {
    if (_mockLocation != null) {
      // Mock konum aktifken cache'i de güncelle, böylece cachedLocation
      // her zaman getCurrentLocation() ile tutarlı olur.
      _cachedLocation = _mockLocation;
      _cachedAt = DateTime.now();
      return _mockLocation;
    }
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 [LocationService] Location services disabled');
        return _cachedLocation;
      }

      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          return _cachedLocation;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _cachedLocation;
      }

      // 15s timeout cold start'ı yavaşlatıyordu. Önce hızlı bir
      // getLastKnownPosition deneyelim (anında cached); başarısızsa
      // kısa timeout (5s) ile gerçek GPS sorgusu yap.
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null &&
          DateTime.now().difference(lastKnown.timestamp).inMinutes < 2) {
        final cached = LatLng(lastKnown.latitude, lastKnown.longitude);
        _cachedLocation = cached;
        _cachedAt = DateTime.now();
        // Arka planda taze konum almaya devam et — bir sonraki çağrıda kullanılır.
        unawaited(_warmRefresh());
        return cached;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      // Production'da mock konum reddedilir; debug'da uyarı verilir ama kabul edilir.
      if (position.isMocked) {
        if (kReleaseMode) {
          return _cachedLocation;
        }
      }

      // Accuracy filtresi: 150m'den kötüyse güvenilir değil, cache'e düş.
      // Debug/test modda devre dışı — mock veya gerçek GPS ile test edilebilsin.
      if (kReleaseMode && position.accuracy > 150) {
        debugPrint('⚠️ [LocationService] Poor accuracy: '
            '${position.accuracy.toStringAsFixed(0)}m — falling back to cache');
        return _recentCacheOrNull();
      }

      final loc = LatLng(position.latitude, position.longitude);
      _cachedLocation = loc;
      _cachedAt = DateTime.now();
      return loc;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [LocationService] Platform error: $e');
      return _recentCacheOrNull();
    } on TimeoutException catch (e) {
      debugPrint('⚠️ [LocationService] Timeout: $e');
      return _recentCacheOrNull();
    } catch (e) {
      debugPrint('⚠️ [LocationService] Error: $e');
      return _recentCacheOrNull();
    }
  }

  /// Cached lastKnown anında döndü; arka planda taze fix almaya çalış.
  /// Başarılı olursa _cachedLocation güncellenir, bir sonraki çağrıda kullanılır.
  static Future<void> _warmRefresh() async {
    try {
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (fresh.isMocked && kReleaseMode) return;
      _cachedLocation = LatLng(fresh.latitude, fresh.longitude);
      _cachedAt = DateTime.now();
    } catch (_) {
      // Sessizce — kullanıcı zaten cached konumu aldı.
    }
  }

  /// Timeout/hata durumunda son 120 sn içindeki cache'i döndür.
  /// Bina içinde GPS fix 60 saniyeden uzun sürebilir; 120 sn daha güvenli.
  static LatLng? _recentCacheOrNull() {
    if (_cachedLocation != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!).inSeconds < 120) {
      return _cachedLocation;
    }
    return null;
  }

  /// Get last known location (cached)
  /// Returns null on any error - safe for iOS
  static Future<LatLng?> getLastKnownLocation() async {
    if (_mockLocation != null) {
      _cachedLocation = _mockLocation;
      _cachedAt = DateTime.now();
      return _mockLocation;
    }
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        return LatLng(position.latitude, position.longitude);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [LocationService] Platform error getting last location: $e');
      return null;
    } catch (e) {
      debugPrint('⚠️ [LocationService] Error getting last location: $e');
      return null;
    }
  }
}
