import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Ekran koruma mixin'i.
///
/// Android'de `FLAG_SECURE` bayrağını ekleyerek ekran görüntüsü alınmasını
/// ve ekran kaydını engeller. iOS'ta efektif değildir (sistem kısıtlaması).
///
/// **Kullanım:**
/// ```dart
/// class _QrScreenState extends ConsumerState<QrScreen>
///     with SecureScreenMixin<QrScreen> { ... }
/// ```
///
/// Uygulandığı ekranlar:
/// - QR ödeme alt sayfası [UserQrModal] (token / ödeme)
/// - OTP giriş ekranı (geçici doğrulama kodu)
///
/// Profil ana ekranı kasıtlı olarak dışarıda: ekran görüntüsü kullanılabilir.
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  static const MethodChannel _channel =
      MethodChannel('com.smartsamsun.mobil/secure_screen');

  @override
  void initState() {
    super.initState();
    _applySecureFlag();
  }

  @override
  void dispose() {
    _clearSecureFlag();
    super.dispose();
  }

  Future<void> _applySecureFlag() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('enable');
    } catch (e) {
      debugPrint('⚠️ [SecureScreen] FLAG_SECURE eklenemedi: $e');
    }
  }

  Future<void> _clearSecureFlag() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('disable');
    } catch (e) {
      debugPrint('⚠️ [SecureScreen] FLAG_SECURE temizlenemedi: $e');
    }
  }
}
