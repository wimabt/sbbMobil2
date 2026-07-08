import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cihaz bütünlüğü servisi.
///
/// Root/jailbreak durumunu tespit eder. Tehlikeli cihazda
/// QR ödeme özelliği devre dışı bırakılır.
///
/// NOT: Bu servis SADECE Android ve iOS'ta çalışır.
/// Diğer platformlarda (web, desktop) güvenli varsayılır.
class DeviceIntegrityService {
  DeviceIntegrityService._();

  /// Cihazın root/jailbreak yapılmış olup olmadığını döner.
  ///
  /// `true` → tehlikeli, `false` → güvenli.
  static Future<bool> isCompromised() async {
    // Debug modunda hiçbir zaman engelleme yapmıyoruz.
    // Geliştirme süreci bloke olmasın.
    if (kDebugMode) return false;

    try {
      return await FlutterJailbreakDetection.jailbroken;
    } catch (e) {
      debugPrint('⚠️ [DeviceIntegrity] Tespit başarısız: $e');
      // Tespit edilemezse → güvenli varsay (hatalı engellemeyi önle)
      return false;
    }
  }

  /// Uygulama başlangıcında çağrılır.
  ///
  /// Cihaz tehlikeliyse kullanıcıya kapatılamaz uyarı gösterir.
  /// QR özelliği otomatik olarak kısıtlanır.
  static Future<void> checkAndWarn(BuildContext context) async {
    final compromised = await isCompromised();
    if (!compromised) return;

    if (!context.mounted) return;

    // Non-dismissible dialog — kullanıcı kapatamaz
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false, // Android geri tuşunu devre dışı bırak
        child: AlertDialog(
          icon: const Icon(Icons.security_rounded, size: 48, color: Colors.orange),
          title: const Text(
            'Güvenlik Uyarısı',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Cihazınız root/jailbreak yapılmış görünüyor.\n\n'
            'Güvenliğiniz için QR ödeme ve puan işlemleri '
            'bu cihazda kısıtlı modda çalışacaktır.\n\n'
            'Daha fazla bilgi için destek hattımızı arayın.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Anladım'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Riverpod Provider ────────────────────────────────────────────────────────

/// Cihazın tehlikeli olup olmadığını tutan async provider.
///
/// `true` → QR ödeme gibi riskli özellikler devre dışı bırakılır.
final deviceIntegrityProvider = FutureProvider<bool>((ref) async {
  return DeviceIntegrityService.isCompromised();
});
