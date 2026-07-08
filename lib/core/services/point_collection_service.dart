import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/models/models.dart';
import '../config/feature_flags.dart';
import '../utils/distance_helper.dart';
import 'discovery_service.dart';
import 'location_service.dart';

/// Backend'in kabul ettiği maksimum mesafe (metre).
/// Backend Haversine ile 100m kontrol yapıyor (flutter-integration.md §10).
const double kPointAcceptanceRadiusMeters = 100.0;

/// UI'da "yakınsınız" bildirimi göstermek için kullanılan eşik.
const double kNearbyNotificationRadiusMeters = 300.0;

/// Bir mekanın puan toplama durumunu temsil eder.
enum PointCollectionStatus {
  /// Mekanın puanı yok
  noPoints,

  /// Kullanıcı çok uzakta (>300m)
  tooFar,

  /// Kullanıcı yakın ama henüz kabul sınırı dışında (100-300m)
  nearby,

  /// Kullanıcı kabul sınırı içinde (<100m) — puan toplanabilir
  withinRange,

  /// Puan zaten toplandı (bu kampanyada `claimed=true`)
  alreadyCollected,

  /// Kampanya henüz başlamadı
  campaignUpcoming,

  /// Kampanya sona erdi
  campaignExpired,

  /// Puan toplama işlemi devam ediyor
  collecting,

  /// Puan başarıyla toplandı (just now)
  collected,

  /// §2.7: Konum hız anomalisi tespit edildi (spoofing koruması)
  velocityAnomaly,

  /// Hata oluştu
  error,
}

/// Puan toplama sonucunu ve mesafe bilgisini taşır.
@immutable
class PointCollectionState {
  final PointCollectionStatus status;
  final double? distanceMeters;
  final int? availablePoints;
  final VisitResult? visitResult;
  final RouteVisitResult? routeVisitResult;
  final String? errorMessage;

  const PointCollectionState({
    this.status = PointCollectionStatus.noPoints,
    this.distanceMeters,
    this.availablePoints,
    this.visitResult,
    this.routeVisitResult,
    this.errorMessage,
  });

  PointCollectionState copyWith({
    PointCollectionStatus? status,
    double? distanceMeters,
    int? availablePoints,
    VisitResult? visitResult,
    RouteVisitResult? routeVisitResult,
    String? errorMessage,
  }) {
    return PointCollectionState(
      status: status ?? this.status,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      availablePoints: availablePoints ?? this.availablePoints,
      visitResult: visitResult ?? this.visitResult,
      routeVisitResult: routeVisitResult ?? this.routeVisitResult,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get canCollect => status == PointCollectionStatus.withinRange;
  bool get isNearby => status == PointCollectionStatus.nearby;

  String get formattedDistance {
    if (distanceMeters == null) return '';
    return DistanceHelper.formatDistance(distanceMeters!);
  }
}

/// Kullanıcının konumunu alıp mesafe hesaplayan ve puan toplama isteği gönderen servis.
class PointCollectionService {
  PointCollectionService(this._discoveryService);

  final DiscoveryService _discoveryService;

  /// Kullanıcının mekana olan mesafesini hesapla ve durumu belirle.
  /// Kampanya bazlı puan sistemi kurallarına göre çalışır.
  Future<PointCollectionState> checkPlaceProximity({
    required Place place,
  }) async {
    // Points/gamification feature flag.
    // Kapalıyken hiçbir mekan puan vermiyormuş gibi davran — UI nearby banner
    // ya da collect CTA göstermez.
    if (!FeatureFlags.pointsEnabled) {
      return const PointCollectionState(status: PointCollectionStatus.noPoints);
    }
    if (place.points == null || place.points == 0) {
      return const PointCollectionState(status: PointCollectionStatus.noPoints);
    }

    // Kampanya durumu kontrolleri (mobile_campaign.md §3.1)
    final campaign = place.campaign;
    if (campaign != null) {
      if (campaign.isUpcoming) {
        return PointCollectionState(
          status: PointCollectionStatus.campaignUpcoming,
          availablePoints: place.points,
        );
      }
      if (campaign.isExpired) {
        return PointCollectionState(
          status: PointCollectionStatus.campaignExpired,
          availablePoints: place.points,
        );
      }
    }

    // Puan bu kampanyada zaten alınmış mı? (claimed VEYA eski visited)
    if (place.isPointsClaimed) {
      return PointCollectionState(
        status: PointCollectionStatus.alreadyCollected,
        availablePoints: place.points,
      );
    }

    if (place.lat == null || place.lng == null) {
      return PointCollectionState(
        status: PointCollectionStatus.tooFar,
        availablePoints: place.points,
      );
    }

    final userLocation = await _getUserLocation();
    if (userLocation == null) {
      if (kDebugMode) {
        debugPrint('📍 [Proximity] ${place.name} (${place.id}): no user location');
      }
      return PointCollectionState(
        status: PointCollectionStatus.tooFar,
        availablePoints: place.points,
        errorMessage: _lastLocationError ?? 'Konum alınamadı',
      );
    }

    final distance = DistanceHelper.calculateHaversineDistance(
      userLocation,
      LatLng(place.lat!, place.lng!),
    );

    final status = _statusFromDistance(distance);
    if (kDebugMode) {
      debugPrint('📍 [Proximity] ${place.name}: ${distance.toStringAsFixed(0)}m → $status');
    }

    return PointCollectionState(
      status: status,
      distanceMeters: distance,
      availablePoints: place.points,
    );
  }

  /// Rota durağının mesafesini kontrol et.
  Future<PointCollectionState> checkRouteStopProximity({
    required RoutePlace stop,
    required int routeId,
  }) async {
    if (!FeatureFlags.pointsEnabled) {
      return const PointCollectionState(status: PointCollectionStatus.noPoints);
    }
    if (stop.stopPoints == null || stop.stopPoints == 0) {
      return const PointCollectionState(status: PointCollectionStatus.noPoints);
    }

    if (stop.visited) {
      return PointCollectionState(
        status: PointCollectionStatus.alreadyCollected,
        availablePoints: stop.stopPoints,
      );
    }

    if (stop.lat == null || stop.lng == null) {
      return PointCollectionState(
        status: PointCollectionStatus.tooFar,
        availablePoints: stop.stopPoints,
      );
    }

    final userLocation = await _getUserLocation();
    if (userLocation == null) {
      if (kDebugMode) {
        debugPrint('📍 [Proximity] RouteStop ${stop.name} (route=$routeId): no user location');
      }
      return PointCollectionState(
        status: PointCollectionStatus.tooFar,
        availablePoints: stop.stopPoints,
        errorMessage: _lastLocationError ?? 'Konum alınamadı',
      );
    }

    final distance = DistanceHelper.calculateHaversineDistance(
      userLocation,
      LatLng(stop.lat!, stop.lng!),
    );

    final status = _statusFromDistance(distance);
    if (kDebugMode) {
      debugPrint('📍 [Proximity] RouteStop ${stop.name}: ${distance.toStringAsFixed(0)}m → $status');
    }

    return PointCollectionState(
      status: status,
      distanceMeters: distance,
      availablePoints: stop.stopPoints,
    );
  }

  /// Mekan puanını topla (backend'e POST isteği gönder).
  /// [placeId] MUST be the System B gamification internal ID (`Place.id`).
  ///
  /// Proximity check sırasında alınan konumla aynı konumu backend'e göndermek
  /// için önce [LocationService.cachedLocation] tercih edilir. Böylece GPS drift
  /// nedeniyle proximity=OK ama collect=TOO_FAR sorunu önlenir.
  Future<PointCollectionState> collectPlacePoints({
    required String placeId,
  }) async {
    if (!FeatureFlags.pointsEnabled) {
      return const PointCollectionState(
        status: PointCollectionStatus.error,
        errorMessage: 'Puan sistemi şu anda devre dışı',
      );
    }
    try {
      // Önce cache'deki konumu tercih et (proximity check'te alınmıştı).
      // Cache yoksa yeni GPS oku.
      final userLocation = LocationService.cachedLocation
          ?? await _getUserLocation();
      if (userLocation == null) {
        return PointCollectionState(
          status: PointCollectionStatus.error,
          errorMessage: _lastLocationError ?? 'Konum alınamadı',
        );
      }

      if (kDebugMode) {
        debugPrint('📍 [PointCollection] collectPlacePoints using loc: '
            '${userLocation.latitude.toStringAsFixed(6)}, '
            '${userLocation.longitude.toStringAsFixed(6)}');
      }

      final result = await _discoveryService.visitPlace(
        placeId,
        userLocation.latitude,
        userLocation.longitude,
      );

      return PointCollectionState(
        status: PointCollectionStatus.collected,
        visitResult: result,
        availablePoints: result.pointsEarned,
        distanceMeters: result.distance?.toDouble(),
      );
    } catch (e) {
      debugPrint('🔥 [PointCollection] collectPlacePoints error: $e');
      return _buildErrorState(e);
    }
  }

  /// Rota durağı puanını topla.
  /// [routeId] and [placeId] MUST be System B gamification internal IDs.
  ///
  /// Proximity check sırasında alınan konumla aynı konumu backend'e göndermek
  /// için önce [LocationService.cachedLocation] tercih edilir.
  Future<PointCollectionState> collectRouteStopPoints({
    required int routeId,
    required String placeId,
  }) async {
    if (!FeatureFlags.pointsEnabled) {
      return const PointCollectionState(
        status: PointCollectionStatus.error,
        errorMessage: 'Puan sistemi şu anda devre dışı',
      );
    }
    try {
      final userLocation = LocationService.cachedLocation
          ?? await _getUserLocation();
      if (userLocation == null) {
        return PointCollectionState(
          status: PointCollectionStatus.error,
          errorMessage: _lastLocationError ?? 'Konum alınamadı',
        );
      }

      if (kDebugMode) {
        debugPrint('📍 [PointCollection] collectRouteStopPoints using loc: '
            '${userLocation.latitude.toStringAsFixed(6)}, '
            '${userLocation.longitude.toStringAsFixed(6)}');
      }

      final result = await _discoveryService.visitRouteStop(
        routeId,
        placeId,
        userLocation.latitude,
        userLocation.longitude,
      );

      return PointCollectionState(
        status: PointCollectionStatus.collected,
        routeVisitResult: result,
        availablePoints: result.pointsEarned,
        distanceMeters: result.distance?.toDouble(),
      );
    } catch (e) {
      debugPrint('🔥 [PointCollection] collectRouteStopPoints error: $e');
      return _buildErrorState(e);
    }
  }

  /// §2.7: Hata durumunu analiz ederek VELOCITY_ANOMALY için ayrı status döndürür.
  /// DioException response body'sindeki `error` alanını da kontrol eder.
  PointCollectionState _buildErrorState(Object e) {
    final errorCode = _extractErrorCode(e);

    if (errorCode == 'VELOCITY_ANOMALY') {
      return const PointCollectionState(
        status: PointCollectionStatus.velocityAnomaly,
        errorMessage:
            'Beklenmeyen bir konum değişikliği algılandı. '
            'Lütfen konumunuzu yenileyip tekrar deneyin.',
      );
    }
    return PointCollectionState(
      status: PointCollectionStatus.error,
      errorMessage: _parseError(e),
    );
  }

  /// DioException response body'sinden veya toString'den hata kodunu çıkarır.
  String _extractErrorCode(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final code = data['error'] as String? ?? data['code'] as String?;
        if (code != null) return code.toUpperCase();
      }
    }
    return e.toString().toUpperCase();
  }

  /// Verilen mesafeye göre statü belirle.
  static PointCollectionStatus statusFromDistance(double meters) {
    return _statusFromDistance(meters);
  }

  static PointCollectionStatus _statusFromDistance(double meters) {
    if (meters <= kPointAcceptanceRadiusMeters) {
      return PointCollectionStatus.withinRange;
    } else if (meters <= kNearbyNotificationRadiusMeters) {
      return PointCollectionStatus.nearby;
    }
    return PointCollectionStatus.tooFar;
  }

  /// §2.8.4: Konum izni reddedilmişse null döner ve `_lastLocationError`
  /// alanını set eder, böylece çağıran kod uygun mesajı gösterebilir.
  String? _lastLocationError;

  Future<LatLng?> _getUserLocation() async {
    _lastLocationError = null;

    // LocationService.getCurrentLocation() kendi içinde izin kontrolü,
    // cache yönetimi ve hata yakalama yapıyor. Ayrı bir Geolocator.checkPermission()
    // çağrısı race condition'a neden olabilir (özellikle Android'de geçici "denied"
    // dönüşleri); bu yüzden doğrudan LocationService'e delege ediyoruz.
    final loc = await LocationService.getCurrentLocation();
    if (loc != null) return loc;

    // getCurrentLocation null döndüyse, cachedLocation'ı kontrol et.
    // Mesafe göstergesi (OSRM) başarılı olduysa cache dolu olabilir.
    final cached = LocationService.cachedLocation;
    if (cached != null) {
      if (kDebugMode) {
        debugPrint('\u{1f4cd} [PointCollection] Using LocationService.cachedLocation');
      }
      return cached;
    }

    // Son care: platform lastKnown (eski olabilir)
    final last = await LocationService.getLastKnownLocation();
    if (last != null) {
      if (kDebugMode) {
        debugPrint('\u{1f4cd} [PointCollection] Fallback to platform lastKnown');
      }
      return last;
    }

    _lastLocationError =
        'Puan kazanmak için konum izni gereklidir. '
        'Lütfen ayarlardan konum iznini etkinleştirin.';
    return null;
  }

  String _parseError(Object e) {
    // Önce DioException status code'unu kontrol et
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 429) {
        return 'Çok hızlı istek gönderildi. Lütfen birkaç saniye bekleyip tekrar deneyin.';
      }
      if (statusCode == 400) {
        // Body'deki hata mesajını ayrıştır
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          final errorMsg = data['message'] as String? ?? data['error'] as String?;
          if (errorMsg != null) {
            return _parseErrorMessage(errorMsg);
          }
        }
      }
    }

    return _parseErrorMessage(e.toString());
  }

  String _parseErrorMessage(String msg) {
    final upper = msg.toUpperCase();

    if (upper.contains('VELOCITY_ANOMALY')) {
      return 'Beklenmeyen bir konum değişikliği algılandı. '
          'Lütfen konumunuzu yenileyip tekrar deneyin.';
    }
    if (upper.contains('TOO_FAR')) {
      return 'Mekana yeterince yakın değilsiniz (100m içinde olmalısınız)';
    }
    if (upper.contains('ALREADY_CLAIMED') || upper.contains('ALREADY_VISITED')) {
      return 'Bu mekanın puanı bu kampanyada zaten toplandı';
    }
    if (upper.contains('CAMPAIGN_NOT_STARTED')) {
      return 'Kampanya henüz başlamadı';
    }
    if (upper.contains('CAMPAIGN_EXPIRED')) {
      return 'Kampanya sona erdi';
    }
    if (upper.contains('DAILY_LIMIT')) {
      return 'Günlük puan toplama limitine ulaştınız';
    }
    if (upper.contains('NO_POINTS')) {
      return 'Bu mekan şu anda puan vermiyor';
    }
    if (upper.contains('401') || upper.contains('UNAUTHORIZED')) {
      return 'Giriş yapmanız gerekiyor';
    }
    if (upper.contains('429') || upper.contains('RATE')) {
      return 'Çok hızlı istek gönderildi. Lütfen birkaç saniye bekleyip tekrar deneyin.';
    }
    return 'Puan toplanamadı';
  }
}

/// Riverpod provider
final pointCollectionServiceProvider = Provider<PointCollectionService>((ref) {
  final discovery = ref.watch(discoveryServiceProvider);
  return PointCollectionService(discovery);
});
