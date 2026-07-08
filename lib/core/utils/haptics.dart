import 'package:flutter/services.dart';

/// Merkezi dokunsal geri bildirim yardımcısı.
///
/// Tüm uygulama genelinde tutarlı titreşim yoğunlukları kullanılmasını sağlar.
///
/// **Kullanım örnekleri:**
/// ```dart
/// // Puan toplandı
/// Haptics.success();
///
/// // Hata / başarısız QR tarama
/// Haptics.error();
///
/// // Gezinti sekmeleri arası geçiş
/// Haptics.light();
///
/// // Pull-to-refresh tetiklendi
/// Haptics.selection();
/// ```
class Haptics {
  Haptics._();

  /// Başarılı işlemler için orta şiddetli titreşim.
  ///
  /// Önerilen kullanım: puan toplama, OTP doğrulama, QR tarama başarısı.
  static Future<void> success() => HapticFeedback.mediumImpact();

  /// Hata durumları için ağır titreşim.
  ///
  /// Önerilen kullanım: QR tarama hatası, hata snackbar, form hatası.
  static Future<void> error() => HapticFeedback.heavyImpact();

  /// Seçim/geçiş için hafif klik hissi.
  ///
  /// Önerilen kullanım: pull-to-refresh tetikleme, çip/filtre seçimi.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// Hafif buton dokunuşları için minimal titreşim.
  ///
  /// Önerilen kullanım: nav bar geçişleri, scale-tap wrapper, ikon butonlar.
  static Future<void> light() => HapticFeedback.lightImpact();
}
