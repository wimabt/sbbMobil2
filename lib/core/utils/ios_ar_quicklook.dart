import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../services/log_service.dart';

const _tag = 'IosArQuickLook';

/// iOS **AR Quick Look** köprüsü (native `AppDelegate.swift`).
///
/// iOS AR Quick Look yalnızca `.usdz`/`.reality` açar; içeriğimiz `.glb`
/// (Android Scene Viewer için). Native taraf verilen `.glb`'yi cihazda
/// GLTFSceneKit + SceneKit ile `.usdz`'ye çevirip (bir kez, sonra cache) AR
/// Quick Look ile sunar — Android'deki otomatik-yerleştirme deneyiminin iOS
/// eşdeğeri. Bu sınıf yalnızca ince bir MethodChannel sarmalayıcısıdır.
class IosArQuickLook {
  IosArQuickLook._();

  static const MethodChannel _channel =
      MethodChannel('com.smartsamsun.mobil/ar_quicklook');

  /// Bu platformda AR Quick Look köprüsü kullanılabilir mi? (Yalnız iOS.)
  static bool get isPlatformSupported => Platform.isIOS;

  /// `.glb` modelini cihazda `.usdz`'ye çevirip AR Quick Look ile açar.
  ///
  /// Başarı durumunda `true` döner (önizleme sunuldu). Dönüşüm/indirme/sunum
  /// başarısızsa `false` döner — çağıran fallback'e düşebilir.
  static Future<bool> present(String glbUrl, {String? title}) async {
    if (!Platform.isIOS) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('present', {
        'url': glbUrl,
        'title': title,
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      LogService.w('AR Quick Look açılamadı: ${e.code} ${e.message}', tag: _tag);
      return false;
    } catch (e) {
      LogService.w('AR Quick Look beklenmeyen hata: $e', tag: _tag);
      return false;
    }
  }
}
