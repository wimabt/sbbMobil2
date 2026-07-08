import 'package:flutter/material.dart';

/// ╔══════════════════════════════════════════════════════════════════════╗
/// ║  GEÇİCİ — YAYINDAN ÖNCE KALDIRILACAK                                   ║
/// ║  Backend, production DIŞINDA doğrulama/step-up kodunu yanıtta          ║
/// ║  `dev_code` alanıyla döner (gerçek SMS/e-posta geçidi yok). Bu widget  ║
/// ║  o kodu ekranda gösterir ki cihazda uçtan uca test edilebilsin —       ║
/// ║  login ekranındaki "Test OTP" gösterimiyle aynı amaç.                  ║
/// ║                                                                        ║
/// ║  KALDIRMA: bu dosyayı sil + `DevCodeBanner(...)` çağrılarını sil       ║
/// ║  (account_screen.dart, change_contact_flows.dart) + backend'de         ║
/// ║  `dev_code` dönüşünü kaldır (account-contact.routes.js `devCode`).     ║
/// ╚══════════════════════════════════════════════════════════════════════╝
class DevCodeBanner extends StatelessWidget {
  const DevCodeBanner({super.key, required this.code});

  /// Gösterilecek kod. null/boş ise hiçbir şey çizmez (prod'da dev_code gelmez).
  final String? code;

  @override
  Widget build(BuildContext context) {
    final c = code;
    if (c == null || c.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withAlpha(18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.primary.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(Icons.bug_report_outlined,
                size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Test kodu: $c',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
