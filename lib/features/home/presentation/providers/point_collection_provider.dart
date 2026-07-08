import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/routing/deep_link_validator.dart';
import '../../../../core/services/point_collection_service.dart';
import '../../../../core/services/route_id_resolver.dart';
import '../../../../data/models/models.dart';
import '../../../campaigns/presentation/providers/campaigns_provider.dart';
import '../../../places/presentation/providers/places_provider.dart';
import '../../../routes/presentation/providers/route_gamification_provider.dart';
import '../../../routes/presentation/providers/routes_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import 'nearby_points_provider.dart';
import 'points_provider.dart';

/// Notification channel sabitleri
const _kChannelId = 'points_proximity';
const _kChannelName = 'Puan Bildirimleri';
const _kChannelDesc = 'Yakındaki puanlı mekanlar için bildirimler';

/// Mekan puan toplama state'leri — place ID bazında.
///
/// Basit ve Riverpod 3.x uyumlu: Tek bir Notifier altında
/// her place ID için ayrı [PointCollectionState] saklanır.
class PointCollectionNotifier extends Notifier<Map<String, PointCollectionState>> {
  final Map<String, Timer> _timers = {};
  final Map<String, RoutePlace> _routeStopCache = {};
  final Set<String> _notifiedPlaces = {};

  FlutterLocalNotificationsPlugin? _notifications;

  final _navigationController = StreamController<String>.broadcast();

  /// Bildirime tıklandığında yayınlanan place ID stream'i.
  Stream<String> get navigationStream => _navigationController.stream;

  @override
  Map<String, PointCollectionState> build() {
    _disposed = false;

    ref.listen<AuthState>(authProvider, (prev, next) {
      final prevUserId = prev?.user?.id;
      final nextUserId = next.user?.id;
      if (prev?.status != next.status || prevUserId != nextUserId) {
        // Sadece timer + state sıfırla. `_disposed` burada true yapılmamalı:
        // Notifier.build() tekrar çalışmadığı için kalıcı olarak tüm _update'ler
        // atlanır (log: SKIPPED: disposed).
        _cancelTimersAndCaches();
        _notifiedPlaces.clear();
        state = {};
      }
    });
    ref.onDispose(() {
      // Provider yok edilirken async callback'lerin state yazmasını engelle.
      _disposed = true;
      _cancelTimersAndCaches();
      _navigationController.close();
    });
    return {};
  }

  void _cancelTimersAndCaches() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _routeStopCache.clear();
  }

  Future<FlutterLocalNotificationsPlugin> _ensureNotifications() async {
    if (_notifications != null) return _notifications!;

    _notifications = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notifications!.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    const androidChannel = AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDesc,
      importance: Importance.high,
      playSound: true,
    );

    await _notifications!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    return _notifications!;
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final raw = data['place_id'];
      final placeId = raw?.toString().trim();
      if (placeId != null &&
          placeId.isNotEmpty &&
          DeepLinkValidator.isValidRouteSegmentId(placeId) &&
          !_navigationController.isClosed) {
        _navigationController.add(placeId);
      }
    } catch (_) {}
  }

  /// Belirli bir mekanın state'ini getir (yoksa varsayılan).
  PointCollectionState forPlace(String placeId) =>
      state[placeId] ?? const PointCollectionState();

  /// Mekan bilgisi ile proximity kontrolünü başlat.
  /// Kampanya durumuna göre early-exit yapar (mobile_campaign.md §3.1).
  /// Her çağrıda claimed/campaign durumu yeniden değerlendirilir.
  void startProximityCheck(Place place) {
    // Points/gamification feature flag — hiçbir timer/notification kurulmasın.
    if (!FeatureFlags.pointsEnabled) return;
    if (place.points == null || place.points == 0) return;

    // Kampanya/claimed kontrolleri HER ZAMAN çalışır — stale timer varsa durdurulur
    final campaign = place.campaign;
    final current = state[place.id];

    if (campaign != null) {
      if (campaign.isUpcoming) {
        _cancelTimer(place.id);
        if (current?.status != PointCollectionStatus.campaignUpcoming) {
          _update(place.id, PointCollectionState(
            status: PointCollectionStatus.campaignUpcoming,
            availablePoints: place.points,
          ));
        }
        return;
      }
      if (campaign.isExpired) {
        _cancelTimer(place.id);
        if (current?.status != PointCollectionStatus.campaignExpired) {
          _update(place.id, PointCollectionState(
            status: PointCollectionStatus.campaignExpired,
            availablePoints: place.points,
          ));
        }
        return;
      }
    }

    if (place.isPointsClaimed) {
      _cancelTimer(place.id);
      if (current?.status != PointCollectionStatus.alreadyCollected) {
        _update(place.id, PointCollectionState(
          status: PointCollectionStatus.alreadyCollected,
          availablePoints: place.points,
        ));
      }
      return;
    }

    if (_timers.containsKey(place.id)) return;

    _checkOnce(place);

    _scheduleNextPlaceProximityCheck(place);
  }

  /// Mekan için adaptif interval hesapla.
  /// Kullanıcı yaklaştıkça daha sık kontrol et.
  Duration _placeIntervalFor(PointCollectionState s) {
    switch (s.status) {
      case PointCollectionStatus.tooFar:
        return const Duration(seconds: 12);
      case PointCollectionStatus.nearby:
        return const Duration(seconds: 5);
      case PointCollectionStatus.withinRange:
        return const Duration(seconds: 3);
      case PointCollectionStatus.collecting:
      case PointCollectionStatus.collected:
      case PointCollectionStatus.alreadyCollected:
        return const Duration(days: 365);
      case PointCollectionStatus.velocityAnomaly:
        return const Duration(seconds: 30);
      default:
        return const Duration(seconds: 8);
    }
  }

  void _scheduleNextPlaceProximityCheck(Place place) {
    _cancelTimer(place.id);

    final current = state[place.id];
    if (current != null &&
        (current.status == PointCollectionStatus.collecting ||
            current.status == PointCollectionStatus.collected ||
            current.status == PointCollectionStatus.alreadyCollected)) {
      return;
    }

    final interval = _placeIntervalFor(current ?? const PointCollectionState());

    _timers[place.id] = Timer(interval, () async {
      if (_disposed) return;
      try {
        await _checkOnce(place);
      } finally {
        if (!_disposed && !place.isPointsClaimed) {
          _scheduleNextPlaceProximityCheck(place);
        }
      }
    });
  }

  void _cancelTimer(String placeId) {
    _timers[placeId]?.cancel();
    _timers.remove(placeId);
  }

  Future<void> _checkOnce(Place place) async {
    try {
      final service = ref.read(pointCollectionServiceProvider);
      final result = await service.checkPlaceProximity(place: place);
      final current = state[place.id];
      if (current != null &&
          (current.status == PointCollectionStatus.collecting ||
              current.status == PointCollectionStatus.collected ||
              current.status == PointCollectionStatus.alreadyCollected)) {
        return;
      }

      final previousStatus = current?.status;
      if (result.status == PointCollectionStatus.withinRange &&
          previousStatus != PointCollectionStatus.withinRange &&
          !_notifiedPlaces.contains(place.id) &&
          !place.isPointsClaimed) {
        _notifiedPlaces.add(place.id);
        _showProximityNotification(place);
      }

      debugPrint(
        '\u{1f4cd} [PointCollection] _checkOnce key=${place.id} '
        '${previousStatus?.name ?? "null"} \u2192 ${result.status.name} '
        'dist=${result.distanceMeters?.toStringAsFixed(0)}m pts=${result.availablePoints}',
      );
      _update(place.id, result);
    } catch (e) {
      debugPrint('[PointCollection] proximity check error: $e');
    }
  }

  Future<void> _showProximityNotification(Place place) async {
    try {
      final plugin = await _ensureNotifications();

      const androidDetails = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: _kChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = jsonEncode({'place_id': place.id});

      await plugin.show(
        place.id.hashCode,
        'Puan Kazanabilirsiniz!',
        '${place.name} — +${place.points} puan toplamak için tıklayın',
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[PointCollection] Failed to show notification: $e');
    }
  }

  /// Mekan puanını topla.
  /// [placeId] MUST be the System B gamification internal ID (`Place.id`).
  Future<void> collectPlace(String placeId) async {
    if (!FeatureFlags.pointsEnabled) return;
    final current = state[placeId];
    if (current == null || !current.canCollect) return;

    _update(placeId, current.copyWith(
      status: PointCollectionStatus.collecting,
    ));

    final service = ref.read(pointCollectionServiceProvider);
    final result = await service.collectPlacePoints(placeId: placeId);

    _update(placeId, result);

    if (result.status == PointCollectionStatus.collected) {
      _timers[placeId]?.cancel();
      _timers.remove(placeId);
      ref.invalidate(pointsBalanceProvider);
      // places verisini yenile → claimed=true olarak güncellenir.
      // nearbyPointPlacesProvider da yenilenir → ana sayfada banner kaybolur.
      ref.invalidate(nearbyPointPlacesProvider);
      // placesProvider enrich'i tetikle (claimed durumu güncellensin)
      _refreshPlacesEnrichment();
    }
  }

  /// Rota durağı puanını topla.
  /// [routeId] and [placeId] MUST be System B gamification internal IDs.
  Future<void> collectRouteStop({
    required int routeId,
    required String placeId,
  }) async {
    if (!FeatureFlags.pointsEnabled) return;
    final key = '$routeId:$placeId';
    final current = state[key] ??
        const PointCollectionState(status: PointCollectionStatus.tooFar);

    // Anti-spam: zaten collecting/collected/alreadyCollected ise tekrar istek atma.
    if (current.status == PointCollectionStatus.collecting ||
        current.status == PointCollectionStatus.collected ||
        current.status == PointCollectionStatus.alreadyCollected) {
      return;
    }
    // withinRange değilse collect yapma
    if (!current.canCollect) return;

    _update(key, current.copyWith(
      status: PointCollectionStatus.collecting,
    ));

    final service = ref.read(pointCollectionServiceProvider);
    final result = await service.collectRouteStopPoints(
      routeId: routeId,
      placeId: placeId,
    );

    _update(key, result);

    if (result.status == PointCollectionStatus.collected) {
      // Timer'ı durdur ve cache'den kaldır — tekrar proximity check yapmasın
      _cancelTimer(key);
      _routeStopCache.remove(key);

      ref.invalidate(pointsBalanceProvider);
      ref.invalidate(nearbyPointPlacesProvider);

      // Rota gamification/progress verileri tüm uygulamada tazelensin.
      // routeGamificationProvider ve routeDetailProvider key olarak CMS ID
      // kullandığı için hem mobile hem CMS ID ile invalidate etmek gerekir.
      final routeIdStr = routeId.toString();
      final resolver = ref.read(routeIdResolverProvider.notifier);
      final cmsId = resolver.toCmsId(routeIdStr);

      ref.invalidate(routeGamificationProvider(routeIdStr));
      ref.invalidate(routeDetailProvider(routeIdStr));
      // CMS ID farklıysa onu da invalidate et
      if (cmsId != routeIdStr) {
        ref.invalidate(routeGamificationProvider(cmsId));
        ref.invalidate(routeDetailProvider(cmsId));
      }
      ref.invalidate(routesProvider);
      ref.invalidate(campaignsProvider);
      // placesProvider enrich'i tetikle
      _refreshPlacesEnrichment();
    }
  }

  /// Places verisini yeniden enrich et (claimed/visited güncellensin).
  /// Küçük gecikme ile çağırılır: backend'in visit kaydını commit etmesi için zaman tanınır.
  void _refreshPlacesEnrichment() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_disposed) return;
      try {
        final placesNotifier = ref.read(placesProvider.notifier);
        placesNotifier.refresh();
      } catch (e) {
        debugPrint('⚠️ [PointCollection] _refreshPlacesEnrichment error: $e');
      }
    });
  }

  /// Rota durağı state'ini getir.
  PointCollectionState forRouteStop(int routeId, String placeId) {
    final key = '$routeId:$placeId';
    return state[key] ?? const PointCollectionState();
  }

  /// Rota durağı için anlık proximity kontrolü yap.
  /// Yerlerdeki `checkPlaceProximity` mantığının aynısını, RoutePlace için uygular.
  Future<void> updateRouteStopProximity({
    required int routeId,
    required RoutePlace stop,
  }) async {
    if (!FeatureFlags.pointsEnabled) return;
    if (stop.stopPoints == null || stop.stopPoints == 0) return;

    final key = '$routeId:${stop.id}';

    // Zaten toplandıysa kontrol yapma
    final current = state[key];
    if (current != null &&
        (current.status == PointCollectionStatus.collecting ||
            current.status == PointCollectionStatus.collected ||
            current.status == PointCollectionStatus.alreadyCollected)) {
      return;
    }

    try {
      final service = ref.read(pointCollectionServiceProvider);
      final result = await service.checkRouteStopProximity(
        stop: stop,
        routeId: routeId,
      );

      _update(key, result);
    } catch (e) {
      debugPrint('[PointCollection] route stop proximity error: $e');
    }
  }

  /// Rota durağı için periyodik proximity kontrolü başlat.
  /// Adaptif interval:
  /// - tooFar: 8s
  /// - nearby: 4s
  /// - withinRange: 3s
  void startRouteStopProximityCheck({
    required int routeId,
    required RoutePlace stop,
  }) {
    if (!FeatureFlags.pointsEnabled) return;
    if (stop.stopPoints == null || stop.stopPoints == 0) return;

    final key = '$routeId:${stop.id}';
    _routeStopCache[key] = stop;

    if (stop.visited) {
      _cancelTimer(key);
      final current = state[key];
      if (current?.status != PointCollectionStatus.alreadyCollected) {
        _update(key, PointCollectionState(
          status: PointCollectionStatus.alreadyCollected,
          availablePoints: stop.stopPoints,
        ));
      }
      _routeStopCache.remove(key);
      return;
    }

    // Zaten collecting/collected ise dokunma
    final current = state[key];
    if (current != null &&
        (current.status == PointCollectionStatus.collecting ||
            current.status == PointCollectionStatus.collected ||
            current.status == PointCollectionStatus.alreadyCollected)) {
      return;
    }

    if (_timers.containsKey(key)) return;

    _scheduleNextRouteStopProximityCheck(key: key, routeId: routeId);
  }

  /// Rota durağı için timer'ı iptal et (sayfa kapatılınca).
  void stopRouteStopProximityCheck({required int routeId, required String placeId}) {
    final key = '$routeId:$placeId';
    _cancelTimer(key);
    _routeStopCache.remove(key);
  }

  /// Normal place detail ekranı kapandığında proximity timer'ını durdur.
  ///
  /// `startProximityCheck(place)` içinde timer key'i `place.id` kullanılarak
  /// oluşturulduğu için aynı id ile iptal edilir.
  void stopProximityCheck({required String placeId}) {
    _cancelTimer(placeId);
    _notifiedPlaces.remove(placeId);
  }

  bool _disposed = false;

  void _update(String key, PointCollectionState newState) {
    if (_disposed) {
      if (kDebugMode) {
        debugPrint('⚠️ [PointCollection] _update($key) SKIPPED: provider disposed');
      }
      return;
    }
    try {
      final updated = Map<String, PointCollectionState>.from(state);
      updated[key] = newState;
      state = updated;
    } catch (e) {
      debugPrint('⚠️ [PointCollection] _update($key) suppressed: $e');
    }
  }

  Duration _routeStopIntervalFor(PointCollectionState s) {
    switch (s.status) {
      case PointCollectionStatus.tooFar:
        return const Duration(seconds: 8);
      case PointCollectionStatus.nearby:
        return const Duration(seconds: 4);
      case PointCollectionStatus.withinRange:
        return const Duration(seconds: 3);
      case PointCollectionStatus.collecting:
      case PointCollectionStatus.collected:
      case PointCollectionStatus.alreadyCollected:
        return const Duration(days: 365);
      case PointCollectionStatus.error:
        return const Duration(seconds: 10);
      case PointCollectionStatus.velocityAnomaly:
        return const Duration(seconds: 30);
      default:
        return const Duration(seconds: 8);
    }
  }

  void _scheduleNextRouteStopProximityCheck({
    required String key,
    required int routeId,
  }) {
    // Eğer timer varsa önce iptal et (interval değişimi için)
    _cancelTimer(key);

    final stop = _routeStopCache[key];
    if (stop == null) return;

    final current = state[key];
    if (current != null &&
        (current.status == PointCollectionStatus.collecting ||
            current.status == PointCollectionStatus.collected ||
            current.status == PointCollectionStatus.alreadyCollected)) {
      _routeStopCache.remove(key);
      return;
    }

    final interval = _routeStopIntervalFor(current ?? const PointCollectionState());

    // İlk seferde gecikmesiz kontrol (snappy UX)
    if (current == null || current.status == PointCollectionStatus.noPoints) {
      // ignore: discarded_futures
      updateRouteStopProximity(routeId: routeId, stop: stop);
    }

    _timers[key] = Timer(interval, () async {
      if (_disposed || !_routeStopCache.containsKey(key)) return;
      try {
        await updateRouteStopProximity(routeId: routeId, stop: stop);
      } finally {
        if (!_disposed && _routeStopCache.containsKey(key)) {
          _scheduleNextRouteStopProximityCheck(key: key, routeId: routeId);
        }
      }
    });
  }

}

/// Ana puan toplama provider'ı.
final pointCollectionProvider =
    NotifierProvider<PointCollectionNotifier, Map<String, PointCollectionState>>(
  PointCollectionNotifier.new,
);
