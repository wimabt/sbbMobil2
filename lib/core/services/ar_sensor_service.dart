import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// backend_ar_todo.md AR4 + Şartname §6.8.3.5 — geospatial AR için
/// **sensör füzyonu**: GPS + kompas (manyetometre) + ivmeölçer (pitch için)
/// okumalarını tek noktada birleştirir. Mobil tarafa düşen tüm doğruluk
/// yönetimi (kalibrasyon uyarısı, smoothing, düşük doğruluk filtreleme)
/// buradan yapılır.
class ArSensorReading {
  const ArSensorReading({
    required this.lat,
    required this.lng,
    required this.locationAccuracyM,
    required this.altitudeM,
    required this.altitudeAccuracyM,
    required this.headingDeg,
    required this.compassAccuracyDeg,
    required this.devicePitchDeg,
    required this.timestamp,
  });

  final double lat;
  final double lng;

  /// GPS yüksekliği (deniz seviyesine göre metre). §6.8.3.2 "Gerekirse yükseklik
  /// bilgisi" — POI altitude_m ile farkı, dikey konumlandırma (elevation açısı)
  /// için kullanılır. GPS dikey doğruluğu yatay doğruluktan zayıftır; bu yüzden
  /// [altitudeAccuracyM] ile güvenilirlik [hasReliableAltitude] üzerinden süzülür.
  final double altitudeM;

  /// GPS yükseklik doğruluğu (metre). 0/negatif = bilinmiyor.
  final double altitudeAccuracyM;

  /// Geolocator'dan dönen GPS doğruluğu (metre). Şartname §6.8.3.10
  /// "hedef noktanın doğruluk sınırları içinde tespit edilememesi" maddesi
  /// için ana sinyal.
  final double locationAccuracyM;

  /// Pusula heading (0-360°, true north). `null` ise sensör henüz veri vermedi.
  final double? headingDeg;

  /// Pusula doğruluğu (°). Düşükse kullanıcıyı kalibrasyona yönlendiririz.
  /// `flutter_compass` bunu `CompassEvent.accuracy` ile döner.
  final double? compassAccuracyDeg;

  /// Cihaz pitch açısı (-90° = yere bakar, 0° = ufka bakar, +90° = gökyüzüne
  /// bakar). Portrait modda ivmeölçerin (y, z) bileşenlerinden hesaplanır.
  /// `null` ise sensör henüz veri vermedi. Şartname §6.8.3.7 — POI'lerin
  /// altitude_m değerine göre ekranda dikey konumlanması için kullanılır.
  final double? devicePitchDeg;

  final DateTime timestamp;

  bool get hasHeading => headingDeg != null;
  bool get hasPitch => devicePitchDeg != null;

  /// GPS yüksekliği dikey konumlandırma için yeterince güvenilir mi?
  /// (Doğruluk biliniyor ve ≤ 30 m.) Değilse elevation açısı hesaplanmaz,
  /// kart mesafe-tabanlı dikey konuma düşer.
  bool get hasReliableAltitude =>
      altitudeAccuracyM > 0 && altitudeAccuracyM <= 30.0;

  /// §6.8.3.10 — GPS doğruluğu yeterli mi? 50 m'den iyi olmalı.
  bool get hasGoodGps => locationAccuracyM <= 50.0;

  /// §6.8.3.10 — Pusula kalibre mi? `null` → bilinmiyor (uyarı verme), küçük
  /// değerler iyi, büyük değerler kalibrasyon gerektiriyor (~30°+ tehlikeli).
  bool get hasGoodCompass =>
      compassAccuracyDeg == null || compassAccuracyDeg! <= 30.0;
}

class ArSensorService {
  ArSensorService();

  StreamSubscription<Position>? _posSub;
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  Position? _lastPos;
  CompassEvent? _lastCompass;
  double? _smoothedPitchDeg;

  // ── GPS konum yumuşatma (low-pass + büyük sıçramada snap) ───────────────
  // Ham GPS lat/lng saniyede birkaç metre zıplıyor → AR modeli "geziyor".
  // Küçük gürültüyü düşük-geçiren filtreyle süzeriz; gerçek (büyük) hareket
  // gelince anında takip ederiz ("ani değişimler olmadığı sürece sabit").
  double? _smLat;
  double? _smLng;
  double? _smAlt;

  /// 0..1 — yüksek = daha çok yumuşatma (daha stabil, daha yavaş tepki).
  static const double _gpsSmoothing = 0.82;

  /// Bu mesafeden (m) büyük sıçrama = gerçek hareket → yumuşatmayı atla, snap.
  static const double _gpsSnapM = 12.0;

  /// Pitch için low-pass filter alpha (0..1). Yüksek = daha çok smoothing
  /// (daha stabil ama daha yavaş tepki). 0.85 = yavaş el sallamasını süzer
  /// ama amaca yönelik kafa çevirmeyi <100ms takip eder.
  static const double _pitchSmoothing = 0.85;

  /// Emit throttle (sensors_plus ~60Hz). 80ms = ~12Hz: AR overlay için görsel
  /// olarak hâlâ akıcı ama UI thread'deki rebuild/repaint yükü 20Hz'e göre
  /// belirgin azalır (batarya + akıcılık).
  DateTime _lastEmitAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _emitMinInterval = Duration(milliseconds: 80);

  final StreamController<ArSensorReading> _ctrl =
      StreamController<ArSensorReading>.broadcast();

  /// Birleşik akış. Hem GPS hem kompas update'inde yeni bir okuma yayınlar.
  Stream<ArSensorReading> get stream => _ctrl.stream;

  bool _started = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    // GPS akışı — 2m hareket sonrası güncelle.
    try {
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        ),
      ).listen((pos) {
        _lastPos = pos;
        _updateSmoothedPosition(pos);
        _emit();
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint('[ArSensor] position stream failed: $e\n$st');
    }

    // Kompas akışı.
    try {
      final stream = FlutterCompass.events;
      if (stream != null) {
        _compassSub = stream.listen((event) {
          _lastCompass = event;
          _emit();
        });
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[ArSensor] compass stream failed: $e\n$st');
    }

    // İvmeölçer akışı — pitch hesaplamak için. Telefon hareketsizken raw
    // accelerometer = yerçekimi vektörü; pitch'i bundan türetiyoruz.
    // Throttle: 50ms (20Hz UI için yeterli, batarya dostu).
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval, // ~50Hz
      ).listen(_onAccelerometer);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ArSensor] accelerometer stream failed: $e\n$st');
      }
    }
  }

  /// Portrait modda cihaz pitch hesabı.
  ///
  /// Android konvansiyonu: cihaz portrait, ekran kullanıcıya bakar:
  ///   • +x = sağ kenar
  ///   • +y = üst kenar
  ///   • +z = ekrandan dışarı (kullanıcıya doğru)
  ///
  /// Yerçekimi vektörü (cihaz duruyorken raw accelerometer):
  ///   • Cihaz dik (kamera ufka): a = (0, +g, 0) → pitch = 0
  ///   • Cihaz öne eğik (kamera yere): a = (0, +g·cos α, +g·sin α) → pitch = -α
  ///   • Cihaz geriye eğik (kamera gökyüzü): a = (0, +g·cos α, -g·sin α) → pitch = +α
  ///
  /// Formül: pitch_deg = -atan2(z, y) (radyandan dereceye)
  void _onAccelerometer(AccelerometerEvent e) {
    final raw = -math.atan2(e.z, e.y) * 180.0 / math.pi;
    // Low-pass filter: dramatik el titremesini süzer, gerçek bakış değişimini
    // korur.
    _smoothedPitchDeg = _smoothedPitchDeg == null
        ? raw
        : _pitchSmoothing * _smoothedPitchDeg! + (1 - _pitchSmoothing) * raw;
    _emit();
  }

  /// Ham GPS okumasını yumuşatılmış lat/lng/alt'a işler.
  void _updateSmoothedPosition(Position pos) {
    if (_smLat == null || _smLng == null) {
      _smLat = pos.latitude;
      _smLng = pos.longitude;
      _smAlt = pos.altitude;
      return;
    }
    final jump = haversineDistanceM(
      lat1: _smLat!,
      lng1: _smLng!,
      lat2: pos.latitude,
      lng2: pos.longitude,
    );
    if (jump > _gpsSnapM) {
      // Gerçek hareket → yumuşatmayı atla, direkt takip et.
      _smLat = pos.latitude;
      _smLng = pos.longitude;
      _smAlt = pos.altitude;
    } else {
      const a = _gpsSmoothing;
      _smLat = a * _smLat! + (1 - a) * pos.latitude;
      _smLng = a * _smLng! + (1 - a) * pos.longitude;
      _smAlt = a * (_smAlt ?? pos.altitude) + (1 - a) * pos.altitude;
    }
  }

  void _emit() {
    // Dispose sonrası bekleyen (buffered) bir sensör olayı tetikleyebilir;
    // kapalı StreamController'a add → "Cannot add new events after close" çöker.
    if (_disposed || _ctrl.isClosed) return;
    final pos = _lastPos;
    if (pos == null) return;
    // Throttle: ivmeölçer 50Hz patlatıyor, UI 20Hz'le yetinir.
    final now = DateTime.now();
    if (now.difference(_lastEmitAt) < _emitMinInterval) return;
    _lastEmitAt = now;

    final compass = _lastCompass;
    _ctrl.add(
      ArSensorReading(
        lat: _smLat ?? pos.latitude,
        lng: _smLng ?? pos.longitude,
        locationAccuracyM: pos.accuracy,
        altitudeM: _smAlt ?? pos.altitude,
        altitudeAccuracyM: pos.altitudeAccuracy,
        headingDeg: _normalizeHeading(compass?.heading),
        compassAccuracyDeg: compass?.accuracy,
        devicePitchDeg: _smoothedPitchDeg,
        timestamp: now,
      ),
    );
  }

  static double? _normalizeHeading(double? raw) {
    if (raw == null) return null;
    // flutter_compass nadiren negatif değer döner — 0-360 aralığına sok.
    var h = raw % 360;
    if (h < 0) h += 360;
    return h;
  }

  Future<void> stop() async {
    await _posSub?.cancel();
    await _compassSub?.cancel();
    await _accelSub?.cancel();
    _posSub = null;
    _compassSub = null;
    _accelSub = null;
    _started = false;
  }

  void dispose() {
    _disposed = true;
    // Abonelikleri SENKRON iptal et (stop() async; await edilmezse close
    // önce çalışır ve bekleyen olaylar kapalı controller'a düşer). cancel()
    // çağrısı iptali hemen başlatır; buffered olaylar için _emit guard'ı var.
    _posSub?.cancel();
    _compassSub?.cancel();
    _accelSub?.cancel();
    _posSub = null;
    _compassSub = null;
    _accelSub = null;
    _started = false;
    _ctrl.close();
  }
}

/// AR sahnesi açıldığında oluşturulan, kapanınca dispose edilen servis.
final arSensorServiceProvider = Provider.autoDispose<ArSensorService>((ref) {
  final svc = ArSensorService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// UI'nın watch edebileceği canlı sensör akışı.
final arSensorStreamProvider =
    StreamProvider.autoDispose<ArSensorReading>((ref) {
  final svc = ref.watch(arSensorServiceProvider);
  // Provider devreye girer girmez start et.
  svc.start();
  return svc.stream;
});

// ─── Geometri yardımcıları — eşleştirme motoru için ─────────────────

/// İki nokta arasındaki büyük çember mesafesini metre olarak döner (Haversine).
double haversineDistanceM({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  const r = 6371000.0; // dünya yarıçapı (m)
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

/// Bir A noktasından B noktasına bakan true-north tabanlı yön açısı (0-360°).
double bearingDeg({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  final lat1 = _deg2rad(fromLat);
  final lat2 = _deg2rad(toLat);
  final dLng = _deg2rad(toLng - fromLng);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  var brng = math.atan2(y, x);
  brng = _rad2deg(brng);
  return (brng + 360) % 360;
}

/// İki bearing arasındaki en kısa fark, [-180, 180] aralığında.
double shortestAngleDeltaDeg(double a, double b) {
  var diff = (b - a + 540) % 360 - 180;
  return diff;
}

double _deg2rad(double deg) => deg * math.pi / 180.0;
double _rad2deg(double rad) => rad * 180.0 / math.pi;
