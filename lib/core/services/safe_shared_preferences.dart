import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android'in legacy `SharedPreferencesPlugin`'i bir StringList girdisi bozuk
/// olduğunda `getAllPrefs()` çağrısı sırasında tüm prefs okumasını bir
/// `java.io.EOFException` ile yere atıyor. Şanssız bir cihaz state'i (eski
/// kurulumdan kalan yarım yazılmış XML, çökme sonrası kesik kayıt, vb.)
/// uygulamanın tüm `SharedPreferences` erişimini kullanılamaz hale getirir.
///
/// Bu helper açılışta bir kez safe `getInstance()` denemesi yapar; bozulma
/// algılarsa native `MethodChannel` üzerinden Android tarafında
/// `Context.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)`
/// XML'ini sıfırlayıp retry eder. Path tahminine gerek yoktur.
///
/// Plugin'in singleton cache'i bir kez ısındıktan sonra repo içindeki 12+
/// `SharedPreferences.getInstance()` çağrısı zaten cache'den döner — bu
/// fix'i sadece bir yerde (main.dart'ta) uygulamak yeterli.
class SafeSharedPreferences {
  SafeSharedPreferences._();

  static const MethodChannel _channel =
      MethodChannel('com.smartsamsun.mobil/prefs_recovery');

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await SharedPreferences.getInstance();
      _initialized = true;
      return;
    } on PlatformException catch (e) {
      if (!_isCorruptionException(e)) rethrow;
      debugPrint(
        '⚠️ [SafeSharedPreferences] Corrupted prefs detected (${e.message}). '
        'Wiping legacy prefs via native channel and retrying.',
      );
      await _nativeClearPrefs();
    }
    // Plugin tarafında `_completer` hata anında null'lanıyor — yani sonraki
    // getInstance() platforma yeniden gider. Wipe sonrası tekrar dene.
    try {
      await SharedPreferences.getInstance();
      _initialized = true;
      debugPrint('✅ [SafeSharedPreferences] Recovery succeeded.');
    } catch (e) {
      debugPrint(
        '⚠️ [SafeSharedPreferences] Retry after wipe failed: $e. '
        'Subsequent prefs calls will keep failing until next launch.',
      );
      rethrow;
    }
  }

  static bool _isCorruptionException(PlatformException e) {
    final msg = e.message ?? '';
    return msg.contains('EOFException') ||
        msg.contains('ListEncoder') ||
        msg.contains('LegacySharedPreferencesPlugin');
  }

  static Future<void> _nativeClearPrefs() async {
    if (!Platform.isAndroid) return;
    try {
      final ok = await _channel.invokeMethod<bool>('clearFlutterPrefs');
      debugPrint('⚠️ [SafeSharedPreferences] Native clear committed=$ok');
    } catch (e) {
      debugPrint('⚠️ [SafeSharedPreferences] Native clear failed: $e');
    }
  }
}
