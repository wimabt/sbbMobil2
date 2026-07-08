import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'geofence_service.dart' show GeofenceZone, GeofenceNotificationStrings;
import 'log_service.dart';

/// Native (OS-level) geofencing köprüsü.
///
/// ╔══════════════════════════════════════════════════════════════════════╗
/// ║ Neden native? WorkManager polling (15 dk + Doze) arka planda atıl     ║
/// ║ kalıyordu. OS'un event-tabanlı geofencing'i (Android GeofencingClient,║
/// ║ iOS CLLocationManager region monitoring) bölgeye girince ANINDA,      ║
/// ║ uygulama KAPALI/Doze'da olsa bile tetiklenir; pil dostudur.           ║
/// ╠══════════════════════════════════════════════════════════════════════╣
/// ║ KRİTİK: App öldürülmüşken Flutter motoru çalışmaz → bildirimi native  ║
/// ║ taraf üretir. Bu yüzden bölge içerikleri (başlık/mesaj/payload, aktif ║
/// ║ dilde) kayıt anında native'e geçilir ve orada saklanır.               ║
/// ║ Bölgeler ADMIN panelden gelir (GeofenceZonesRepository).              ║
/// ╚══════════════════════════════════════════════════════════════════════╝
class NativeGeofenceService {
  NativeGeofenceService._();
  static final NativeGeofenceService instance = NativeGeofenceService._();

  static const MethodChannel _channel =
      MethodChannel('com.smartsamsun.mobil/geofence');

  /// Bildirime dokunulduğunda native'in ilettiği deep-link payload akışı.
  /// `{target, id}` taşır; `geofence_handler.dart` bunu rotaya çevirir.
  final StreamController<Map<String, dynamic>> _tapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get taps => _tapController.stream;

  bool _handlerInstalled = false;

  /// Native → Dart çağrılarını dinler (tap olayları). İlk kullanımda kurulur.
  void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onGeofenceTap') {
        try {
          final raw = call.arguments;
          final map = raw is String
              ? jsonDecode(raw) as Map<String, dynamic>
              : Map<String, dynamic>.from(raw as Map);
          _tapController.add(Map<String, dynamic>.from(map));
        } catch (e) {
          LogService.w('onGeofenceTap parse failed: $e', tag: 'NativeGeofence');
        }
      }
      return null;
    });
  }

  /// Native tarafının açılışta bekleyen (app kapalıyken dokunulmuş) bir tap
  /// payload'u varsa onu çeker. Açılışta bir kez çağrılır.
  Future<void> drainPendingTap() async {
    _ensureHandler();
    try {
      final raw = await _channel.invokeMethod<String>('consumePendingTap');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _tapController.add(Map<String, dynamic>.from(map));
      }
    } on PlatformException catch (e) {
      LogService.w('consumePendingTap failed: ${e.message}', tag: 'NativeGeofence');
    } catch (_) {/* yok */}
  }

  /// Arka plan ("Her zaman") konum iznini ister.
  /// iOS: `requestAlwaysAuthorization`. Android: foreground sonrası background
  /// escalation (11+'da sistem ayarına yönlendirir). Sonuç bool döner.
  Future<bool> requestAlwaysPermission() async {
    _ensureHandler();
    try {
      final res = await _channel.invokeMethod<bool>('requestAlwaysPermission');
      return res ?? false;
    } on PlatformException catch (e) {
      LogService.w('requestAlwaysPermission failed: ${e.message}',
          tag: 'NativeGeofence');
      return false;
    }
  }

  /// Admin-tanımlı bölgeleri OS geofence/region olarak kaydeder.
  ///
  /// Her bölge için aktif dildeki başlık + gövde + deep-link payload native'e
  /// geçilir; native bunları saklayıp tetiklenince (app kapalı olsa bile)
  /// bildirimi kendisi gösterir.
  Future<void> registerZones(List<GeofenceZone> zones, String lang) async {
    _ensureHandler();
    final payload = zones
        .where((z) => z.active && z.id.isNotEmpty)
        .map((z) => <String, dynamic>{
              'id': z.id,
              'lat': z.lat,
              'lng': z.lng,
              'radius': z.radius,
              'title': GeofenceNotificationStrings.welcomeTitle(lang, z.name),
              'body': z.messageFor(lang),
              // deeplinkId yoksa tap yalnız uygulamayı açar (deep link yok).
              if (z.deeplinkId != null && z.deeplinkId!.isNotEmpty)
                'deeplinkId': z.deeplinkId,
            })
        .toList(growable: false);

    try {
      await _channel.invokeMethod<void>('registerZones', <String, dynamic>{
        'zones': jsonEncode(payload),
        'lang': lang,
        'channelId': 'location_alerts',
        'channelName': GeofenceNotificationStrings.channelName(lang),
        'channelDesc': GeofenceNotificationStrings.channelDescription(lang),
        'cooldownHours': 24,
      });
      LogService.s('Native geofences registered: ${payload.length}',
          tag: 'NativeGeofence');
    } on PlatformException catch (e) {
      LogService.e('registerZones failed: ${e.message}', tag: 'NativeGeofence');
    }
  }

  /// Tüm izlemeyi kaldırır (servis kapatılınca).
  Future<void> clearZones() async {
    try {
      await _channel.invokeMethod<void>('clearZones');
      LogService.i('Native geofences cleared', tag: 'NativeGeofence');
    } on PlatformException catch (e) {
      LogService.w('clearZones failed: ${e.message}', tag: 'NativeGeofence');
    }
  }

  /// Halen izlenen bölge sayısı (teşhis/durum için).
  Future<int> monitoredCount() async {
    try {
      final n = await _channel.invokeMethod<int>('monitoredCount');
      return n ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
