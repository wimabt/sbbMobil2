import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_events.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/ar_cache_manager.dart';
import '../../../../core/services/ar_sensor_service.dart';
import '../../../../core/services/log_service.dart';
import '../../../../data/models/ar_point.dart';
import '../../../../data/repositories/ar_points_repository.dart';

/// §6.8.3.6 — Aynı anda kamera ekranında gösterilebilecek **azami AR öğesi**.
///
/// Çok sayıda yakın POI bulunduğunda ekranın okunamaz hale gelmesini önler;
/// `matches` (priority↓, mesafe↑) sıralı geldiği için ekranda öncelik verilmiş
/// ve en yakın içerikler öne çıkar. İleride backend/global ayardan parametrik
/// gelebilir — tek sabit değiştirilerek ayarlanır.
const int kMaxVisibleArItems = 5;

/// §6.8.3.6 çakışma/öncelik sıralaması: önce yüksek `priority`, eşitlikte en
/// yakın. Hem radar listesi hem kamera overlay'i bu sırayı kullanır.
int compareArMatchesByPriorityThenDistance(ArMatchedPoint a, ArMatchedPoint b) {
  final byPriority = b.point.priority.compareTo(a.point.priority); // azalan
  if (byPriority != 0) return byPriority;
  return a.distanceM.compareTo(b.distanceM); // artan
}

/// backend_ar_todo.md AR2/AR5 — geospatial AR sahnesinin tüm reaktif state'i.
///
/// Akış:
///   1. Sensör servisinden ilk GPS okumasını al → `/mobile/ar/points` çağır
///   2. Sensör güncellemelerine göre tüm noktalar için Haversine mesafesi
///      ve true-north bearing hesapla (matching engine)
///   3. Tetiklenen (radius + bearing tolerans içinde) noktalar değişince
///      analytics event'leri yayınla:
///        • giren noktalar → `ar_geo_triggered`
///        • çıkan noktalar → `ar_geo_dismissed`
///   4. Her ~3 dk veya kullanıcı 500m hareket ettiyse POI listesini tazele
@immutable
class ArGeoState {
  const ArGeoState({
    this.points = const [],
    this.matches = const [],
    this.sensor,
    this.isLoadingPoints = false,
    this.error,
    this.previewMode = false,
  });

  /// Backend'den gelen ham AR noktaları.
  final List<ArPoint> points;

  /// Sensör verisiyle eşleştirilmiş noktalar; (priority↓, mesafe↑) sıralı
  /// (§6.8.3.6 öncelik/çakışma sıralaması).
  final List<ArMatchedPoint> matches;

  /// En güncel sensör okuması (sensor.headingDeg, GPS doğruluk vs.).
  final ArSensorReading? sensor;

  final bool isLoadingPoints;
  final String? error;

  /// Backend response'unda `meta.preview == true` ise UI'da uyarı göstereceğiz.
  final bool previewMode;

  /// Şu an gerçekten "açılmış" durumda olan noktalar.
  Iterable<ArMatchedPoint> get triggered =>
      matches.where((m) => m.isTriggered);

  ArGeoState copyWith({
    List<ArPoint>? points,
    List<ArMatchedPoint>? matches,
    ArSensorReading? sensor,
    bool? isLoadingPoints,
    Object? error = _sentinel,
    bool? previewMode,
  }) {
    return ArGeoState(
      points: points ?? this.points,
      matches: matches ?? this.matches,
      sensor: sensor ?? this.sensor,
      isLoadingPoints: isLoadingPoints ?? this.isLoadingPoints,
      error: identical(error, _sentinel) ? this.error : error as String?,
      previewMode: previewMode ?? this.previewMode,
    );
  }

  static const _sentinel = Object();
}

class ArGeoController extends Notifier<ArGeoState> {
  StreamSubscription<ArSensorReading>? _sensorSub;
  String? _previewToken;

  // Son fetch'in yapıldığı konum — kullanıcı belirli mesafeden fazla
  // hareket ederse yeniden fetch tetikliyoruz.
  double? _lastFetchLat;
  double? _lastFetchLng;
  DateTime? _lastFetchAt;
  Set<String> _previouslyTriggered = const {};

  // Match yeniden-hesabı throttle'ı: sensör ~20Hz akıyor ama mesafe/bearing
  // yalnız GPS/heading anlamlı değişince değişir. Pitch (ivmeölçer) tiklerinde
  // pahalı Haversine+sort'u atlarız → AR'da belirgin CPU/rebuild tasarrufu.
  double? _lastMatchLat;
  double? _lastMatchLng;
  double? _lastMatchHeading;
  DateTime? _lastMatchAt;
  static const double _recomputeMoveMeters = 1.5;
  static const double _recomputeHeadingDeg = 1.5;
  static const Duration _recomputeMaxAge = Duration(milliseconds: 600);

  static const Duration _maxFetchAge = Duration(minutes: 3);
  static const double _refetchMoveMeters = 500.0;
  static const double _searchRadiusKm = 2.0;

  @override
  ArGeoState build() {
    final svc = ref.watch(arSensorServiceProvider);
    svc.start();

    // §6.8.3.9 prefetch — cache manager'ı controller yaşadığı sürece canlı tut
    // (autoDispose; watch olmazsa ref.read sonrası anında dispose olup prefetch
    // token'ını iptal edebilir). Ekran kapanınca onDispose → cancelPrefetch.
    ref.watch(arCacheManagerProvider);

    _sensorSub = svc.stream.listen(_onSensorReading);

    ref.onDispose(() {
      _sensorSub?.cancel();
    });

    return const ArGeoState();
  }

  /// Backoffice'ten alınan preview token; ileride deep-link veya QR ile
  /// gönderilebilir. Mevcut çağrılar otomatik bunu içerir.
  void setPreviewToken(String? token) {
    _previewToken = token;
    final s = state.sensor;
    if (s != null) {
      _fetchPoints(lat: s.lat, lng: s.lng, force: true);
    }
  }

  Future<void> refreshPoints() async {
    final s = state.sensor;
    if (s == null) return;
    await _fetchPoints(lat: s.lat, lng: s.lng, force: true);
  }

  void _onSensorReading(ArSensorReading reading) {
    state = state.copyWith(sensor: reading);

    final shouldFetch = _shouldFetch(reading);
    if (shouldFetch) {
      _fetchPoints(lat: reading.lat, lng: reading.lng);
    }

    if (state.points.isNotEmpty && _shouldRecompute(reading)) {
      _recomputeMatches(reading);
    }
  }

  /// Pahalı match yeniden-hesabı yalnız GPS/heading anlamlı değişince ya da
  /// belirli süre geçince çalışsın (pitch-only tiklerini atla).
  bool _shouldRecompute(ArSensorReading reading) {
    if (_lastMatchAt == null) return true;
    if (DateTime.now().difference(_lastMatchAt!) > _recomputeMaxAge) return true;
    if (_lastMatchLat != null && _lastMatchLng != null) {
      final moved = haversineDistanceM(
        lat1: _lastMatchLat!,
        lng1: _lastMatchLng!,
        lat2: reading.lat,
        lng2: reading.lng,
      );
      if (moved > _recomputeMoveMeters) return true;
    }
    final h = reading.headingDeg;
    if (h != null) {
      if (_lastMatchHeading == null) return true;
      if (shortestAngleDeltaDeg(_lastMatchHeading!, h).abs() >
          _recomputeHeadingDeg) {
        return true;
      }
    }
    return false;
  }

  bool _shouldFetch(ArSensorReading reading) {
    if (state.isLoadingPoints) return false;
    if (_lastFetchAt == null) return true;
    if (DateTime.now().difference(_lastFetchAt!) > _maxFetchAge) return true;
    if (_lastFetchLat != null && _lastFetchLng != null) {
      final moved = haversineDistanceM(
        lat1: _lastFetchLat!,
        lng1: _lastFetchLng!,
        lat2: reading.lat,
        lng2: reading.lng,
      );
      if (moved > _refetchMoveMeters) return true;
    }
    return false;
  }

  Future<void> _fetchPoints({
    required double lat,
    required double lng,
    bool force = false,
  }) async {
    if (state.isLoadingPoints && !force) return;
    state = state.copyWith(isLoadingPoints: true, error: null);
    try {
      final repo = ref.read(arPointsRepositoryProvider);
      final result = await repo.fetchNearby(
        lat: lat,
        lng: lng,
        radiusKm: _searchRadiusKm,
        previewToken: _previewToken,
      );
      _lastFetchLat = lat;
      _lastFetchLng = lng;
      _lastFetchAt = DateTime.now();
      state = state.copyWith(
        points: result.points,
        previewMode: result.preview,
        isLoadingPoints: false,
      );
      // Yeni POI listesi geldi; mevcut sensör verisiyle hemen eşleştir.
      final s = state.sensor;
      if (s != null) _recomputeMatches(s);
      // §6.8.3.9 — bölgeye girildi: yakındaki 3B modelleri proaktif önbelleğe al
      // (kamera açıldığında bekleme süresini azaltır). Fire-and-forget.
      _prefetchNearbyModels(result.points, s);
    } catch (e, st) {
      LogService.w('ArGeo fetchPoints failed: $e', tag: 'ArGeo');
      if (kDebugMode) debugPrint('$st');
      state = state.copyWith(
        isLoadingPoints: false,
        error: e.toString(),
      );
    }
  }

  /// §6.8.3.9 — Yakındaki POI'lerin 3B modellerini proaktif önbelleğe alır.
  /// Sensör varsa en yakın POI önce indirilir (kamera ilk o yöne çevrildiğinde
  /// hazır olsun). Fire-and-forget; hata UI'ı etkilemez.
  void _prefetchNearbyModels(List<ArPoint> points, ArSensorReading? reading) {
    final candidates =
        points.where((p) => (p.modelUrl ?? '').isNotEmpty).toList();
    if (candidates.isEmpty) return;
    if (reading != null) {
      candidates.sort((a, b) {
        final da = haversineDistanceM(
            lat1: reading.lat, lng1: reading.lng, lat2: a.lat, lng2: a.lng);
        final db = haversineDistanceM(
            lat1: reading.lat, lng1: reading.lng, lat2: b.lat, lng2: b.lng);
        return da.compareTo(db);
      });
    }
    final refs = [
      for (final p in candidates) ArModelRef(url: p.modelUrl!, id: p.id),
    ];
    unawaited(
      ref.read(arCacheManagerProvider).prefetchModels(refs).catchError((e) {
        LogService.w('AR prefetch error: $e', tag: 'ArGeo');
        return 0;
      }),
    );
  }

  void _recomputeMatches(ArSensorReading reading) {
    // Throttle referanslarını güncelle (bu hesap fiilen yapıldı).
    _lastMatchLat = reading.lat;
    _lastMatchLng = reading.lng;
    _lastMatchHeading = reading.headingDeg;
    _lastMatchAt = DateTime.now();

    final points = state.points;
    if (points.isEmpty) {
      state = state.copyWith(matches: const []);
      _previouslyTriggered = const {};
      return;
    }
    final heading = reading.headingDeg;
    final matches = <ArMatchedPoint>[];
    for (final p in points) {
      final dist = haversineDistanceM(
        lat1: reading.lat,
        lng1: reading.lng,
        lat2: p.lat,
        lng2: p.lng,
      );
      final bearing = bearingDeg(
        fromLat: reading.lat,
        fromLng: reading.lng,
        toLat: p.lat,
        toLng: p.lng,
      );
      final delta = heading == null
          ? 180.0 // heading yoksa eşleşmedi say
          : shortestAngleDeltaDeg(heading, bearing).abs();
      final inRadius = dist >= p.minDistanceM && dist <= p.radiusM;
      // POI bearing'i null ise her açıdan görünür; aksi halde
      // cihaz kullanıcıya hangi yöne baktığı (heading), POI'ye giden bearing
      // ile karşılaştırılır. Tolerans hem POI bearing toleransını hem da
      // kullanıcı bakış açısını kapsar.
      final bearingMatch = heading != null && delta <= p.bearingTolDeg;

      // §6.8.3.2 + §6.8.3.7 — POI altitude_m + güvenilir GPS yüksekliği varsa
      // dikey yükselme (elevation) açısını hesapla: atan2(Δyükseklik, mesafe).
      // Pozitif = POI yukarıda. Kamera overlay'i bunu cihaz pitch'i ile
      // birleştirip kartı dikey konumlandırır.
      var elevationDeg = 0.0;
      var hasElevation = false;
      final poiAlt = p.altitudeM;
      if (poiAlt != null && reading.hasReliableAltitude) {
        final altDiff = poiAlt - reading.altitudeM;
        elevationDeg =
            math.atan2(altDiff, dist < 1 ? 1 : dist) * 180.0 / math.pi;
        hasElevation = true;
      }

      matches.add(ArMatchedPoint(
        point: p,
        distanceM: dist,
        bearingFromUserDeg: bearing,
        headingDeltaDeg: delta,
        inRadius: inRadius,
        inBearingTolerance: bearingMatch,
        elevationAngleDeg: elevationDeg,
        hasElevationData: hasElevation,
      ));
    }
    // §6.8.3.6 — öncelik (priority) + yakınlık sıralaması. Yönetim panelinden
    // öne çıkarılan (yüksek priority) içerik üstte; eşit priority'de en yakın.
    matches.sort(compareArMatchesByPriorityThenDistance);
    state = state.copyWith(matches: matches);

    // Analytics — triggered set'i değiştiyse event yay
    final nowTriggered = matches
        .where((m) => m.isTriggered)
        .map((m) => m.point.id)
        .toSet();
    final newlyTriggered = nowTriggered.difference(_previouslyTriggered);
    final newlyDismissed = _previouslyTriggered.difference(nowTriggered);
    final analytics = ref.read(analyticsServiceProvider);
    for (final id in newlyTriggered) {
      final m = matches.firstWhere((x) => x.point.id == id);
      analytics.track(AnalyticsEvents.arGeoTriggered, properties: {
        'ar_point_id': id,
        'distance_m': m.distanceM.round(),
        'bearing_match': true,
      });
    }
    for (final id in newlyDismissed) {
      analytics.track(AnalyticsEvents.arGeoDismissed, properties: {
        'ar_point_id': id,
      });
    }
    _previouslyTriggered = nowTriggered;
  }

  /// Aksiyon butonu tıklamasını analytics'e iletir; UI handle ediyor.
  void trackAction(ArPoint point, ArPointAction action) {
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvents.arActionTapped,
      properties: {
        'ar_point_id': point.id,
        'action': action.action,
        ...action.params.map((k, v) => MapEntry('p_$k', v)),
      },
    );
  }
}

/// Notifier'ı autoDispose yapmak Riverpod 3'te `NotifierProvider.autoDispose`
/// ile ifade ediliyor; class tarafı `Notifier` olarak kalır. Çağıran ekran
/// yığından çıkınca subscription/stream'ler `ref.onDispose` ile kapanır.
final arGeoControllerProvider =
    NotifierProvider.autoDispose<ArGeoController, ArGeoState>(
  ArGeoController.new,
);
