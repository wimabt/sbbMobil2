import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Şartname §6.8.3.10 + §6.8.3.5 — AR oturumu başlamadan önce
/// cihaz / izin / sensör hazırlığını tek noktada özetler.
///
/// Mobil tarafta tam **markerless geospatial AR** henüz yok; bu servis,
/// hazır olan **QR-tetiklemeli AR viewer** akışı için pragmatik bir kapı:
///   • Cihaz AR'ı destekliyor mu? (platform kontrolü — Android ≥ N veya iOS)
///   • Kamera izni verildi mi?
///   • Konum izni verildi mi? GPS doğruluğu yeterli mi (< 50 m)?
///   • Pusula kalibrasyonu uyarısı (placeholder — sensör paketi eklenince
///     gerçek bir okuma yapılacak, şimdilik bilinmiyor olarak işaretliyor)
///
/// Daha sonra geospatial AR feature'ı geldiğinde `flutter_compass` + GPS
/// accuracy ile entegre edilebilir; çağıran taraf kodu değişmez.
class ArCapabilityService {
  const ArCapabilityService();

  Future<ArCapabilityReport> check({bool requireLocation = false}) async {
    final supported = _isPlatformSupported();
    if (!supported) {
      return const ArCapabilityReport(
        deviceSupported: false,
        cameraPermission: PermissionStatus.denied,
        locationPermission: LocationPermission.denied,
        gpsServiceEnabled: false,
        gpsAccuracyMeters: null,
        compassCalibrated: null,
        blockingIssue: ArBlockingIssue.deviceNotSupported,
      );
    }

    // §6.8.3.10 madde 2: kamera izni
    final camStatus = await _cameraPermissionStatus();

    // §6.8.3.10 madde 3: konum izni (yalnız gerekli olduğunda)
    LocationPermission locPerm = LocationPermission.denied;
    bool serviceEnabled = false;
    double? accuracy;
    if (requireLocation) {
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        locPerm = await Geolocator.checkPermission();
        if (serviceEnabled &&
            (locPerm == LocationPermission.always ||
                locPerm == LocationPermission.whileInUse)) {
          // Mevcut son konumu çek; veriyi engellememek için 2s timeout.
          try {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 2),
              ),
            );
            accuracy = pos.accuracy;
          } catch (_) {
            // timeout — sessiz geç
          }
        }
      } catch (e, st) {
        if (kDebugMode) debugPrint('[ArCapability] location check failed: $e\n$st');
      }
    }

    ArBlockingIssue? blocker;
    if (camStatus.isDenied || camStatus.isPermanentlyDenied) {
      blocker = ArBlockingIssue.cameraDenied;
    } else if (requireLocation &&
        (locPerm == LocationPermission.denied ||
            locPerm == LocationPermission.deniedForever)) {
      blocker = ArBlockingIssue.locationDenied;
    } else if (requireLocation && !serviceEnabled) {
      blocker = ArBlockingIssue.locationServiceOff;
    } else if (requireLocation &&
        accuracy != null &&
        accuracy > _kPoorGpsAccuracyMeters) {
      blocker = ArBlockingIssue.gpsAccuracyLow;
    }

    return ArCapabilityReport(
      deviceSupported: true,
      cameraPermission: camStatus,
      locationPermission: locPerm,
      gpsServiceEnabled: serviceEnabled,
      gpsAccuracyMeters: accuracy,
      compassCalibrated: null,
      blockingIssue: blocker,
    );
  }

  /// iOS'ta bir kez `granted` görüldüyse probe tekrarlanmaz. iOS, kamera izni
  /// Ayarlar'dan değiştirildiğinde uygulamayı zaten sonlandırdığı için
  /// bellek-içi cache güvenlidir.
  static PermissionStatus? _iosCameraStatusCache;

  /// Kamera izni durumu.
  ///
  /// iOS'ta permission_handler KULLANILMAZ: eklentinin iOS tarafı, Podfile
  /// post_install'a gömülen derleme-zamanı `PERMISSION_CAMERA=1` makrosuna
  /// bağımlıdır ve makro binary'ye girmediğinde hem `status` hem `request`,
  /// kullanıcı izni vermiş olsa bile sabit `denied` döndürür — sistem izin
  /// penceresi hiç açılmaz, uygulama Ayarlar'da Kamera satırı alamaz. Bunun
  /// yerine kamera eklentisinin native isteği kullanılır:
  /// `CameraController.initialize()` → `AVCaptureDevice.requestAccess`
  /// (makro gerektirmez; izin sorulmamışsa sistem penceresini kendisi açar).
  Future<PermissionStatus> _cameraPermissionStatus() async {
    if (!Platform.isIOS) {
      // Android: AR sayfasına GİRİŞTE kamera izni yoksa OS iznini OTOMATİK
      // iste (iOS zaten aşağıdaki kamera probe'u ile otomatik soruyor). Böylece
      // kullanıcı önce engel ekranındaki butona basmak zorunda kalmaz; sistem
      // penceresi doğrudan açılır. Kalıcı reddedilmişse `request()` pencere
      // açmadan `permanentlyDenied` döner → gate "Ayarlara Git" gösterir.
      // `check()` her AR girişinde yeniden çalıştığı için, izin verilene kadar
      // her seferinde tekrar sorulur (kullanıcının istediği davranış).
      final status = await Permission.camera.status;
      if (status.isGranted ||
          status.isPermanentlyDenied ||
          status.isRestricted) {
        return status;
      }
      return Permission.camera.request();
    }

    if (_iosCameraStatusCache == PermissionStatus.granted) {
      return PermissionStatus.granted;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        // Simülatör vb. — kamera donanımı yok.
        return PermissionStatus.denied;
      }
      final probe = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: false,
      );
      try {
        await probe.initialize();
        _iosCameraStatusCache = PermissionStatus.granted;
        return PermissionStatus.granted;
      } on CameraException catch (e) {
        if (e.code.startsWith('CameraAccess')) {
          // Kullanıcı reddetti (veya Ekran Süresi kısıtı). iOS sistem
          // penceresini bir daha göstermez → kullanıcı Ayarlar'a yönlenmeli.
          return PermissionStatus.permanentlyDenied;
        }
        rethrow;
      } finally {
        await probe.dispose();
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[ArCapability] camera probe failed: $e\n$st');
      return PermissionStatus.denied;
    }
  }

  static bool _isPlatformSupported() {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid || Platform.isIOS) return true;
    } catch (_) {
      // Non-mobil platformlar
    }
    return false;
  }

  static const double _kPoorGpsAccuracyMeters = 50.0;
}

/// AR oturumu öncesi cihaz/izin/sensör durumunun anlık özeti.
@immutable
class ArCapabilityReport {
  const ArCapabilityReport({
    required this.deviceSupported,
    required this.cameraPermission,
    required this.locationPermission,
    required this.gpsServiceEnabled,
    required this.gpsAccuracyMeters,
    required this.compassCalibrated,
    required this.blockingIssue,
  });

  final bool deviceSupported;
  final PermissionStatus cameraPermission;
  final LocationPermission locationPermission;
  final bool gpsServiceEnabled;

  /// Metre cinsinden GPS doğruluğu. Bilinmiyorsa `null`.
  final double? gpsAccuracyMeters;

  /// Pusula kalibrasyon durumu. Sensör paketi entegre edilmeden bilinmez
  /// (placeholder; geospatial AR sprintinde dolacak).
  final bool? compassCalibrated;

  /// AR'ın başlatılmasını engelleyen ilk kritik sorun. `null` → hazır.
  final ArBlockingIssue? blockingIssue;

  bool get isReady => blockingIssue == null;
}

/// Engelleyici durum kategorileri. UI bunlara karşılık gelen mesaj +
/// aksiyon (Ayarlara Git / Yeniden Dene) gösterir.
enum ArBlockingIssue {
  deviceNotSupported,
  cameraDenied,
  locationDenied,
  locationServiceOff,
  gpsAccuracyLow,
}

final arCapabilityServiceProvider = Provider<ArCapabilityService>((ref) {
  return const ArCapabilityService();
});

/// Çağıran widget'lar `requireLocation` belirtip family olarak watch edebilir.
final arReadinessProvider = FutureProvider.autoDispose
    .family<ArCapabilityReport, bool>((ref, requireLocation) {
  return ref
      .read(arCapabilityServiceProvider)
      .check(requireLocation: requireLocation);
});
