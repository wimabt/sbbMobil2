import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/services/ar_capability_service.dart';

/// Şartname §6.8.3.10 — AR girişlerinde tek noktadan **kontrollü davranış**.
///
/// AR Viewer ve QR-AR Scanner ekranları açılmadan önce bu kapı:
///   1. Cihaz AR destekliyor mu?
///   2. Kamera izni verilmiş mi?
///   3. (Opsiyonel) Konum izni + GPS doğruluğu yeterli mi?
///
/// Engelleyici bir sorun varsa kullanıcıya **anlaşılır yönlendirme** ve
/// **Ayarlara Git / Yeniden Dene** butonları gösterir. Her şey yolundaysa
/// child widget render edilir.
class ArReadinessGate extends ConsumerWidget {
  const ArReadinessGate({
    super.key,
    required this.child,
    this.requireLocation = false,
    this.titleWhenBlocked = 'AR Hazırlığı',
  });

  final Widget child;

  /// Geospatial AR senaryolarında `true`. QR-tetiklemeli viewer için `false`
  /// yeterli (kamera + cihaz desteği kontrol edilir).
  final bool requireLocation;

  final String titleWhenBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(arReadinessProvider(requireLocation));
    return async.when(
      loading: () => _LoadingScaffold(title: titleWhenBlocked),
      error: (e, _) => _BlockedScaffold(
        title: titleWhenBlocked,
        icon: Icons.error_outline_rounded,
        headline: 'AR durumu kontrol edilemedi',
        message: e.toString(),
        primaryLabel: 'Yeniden Dene',
        onPrimary: () => ref.invalidate(arReadinessProvider(requireLocation)),
      ),
      data: (report) {
        if (report.isReady) return child;
        return _buildBlocked(context, ref, report);
      },
    );
  }

  Widget _buildBlocked(
    BuildContext context,
    WidgetRef ref,
    ArCapabilityReport report,
  ) {
    switch (report.blockingIssue!) {
      case ArBlockingIssue.deviceNotSupported:
        return _BlockedScaffold(
          title: titleWhenBlocked,
          icon: Icons.no_photography_rounded,
          headline: 'Cihazınız AR desteklemiyor',
          message:
              'Artırılmış gerçeklik özelliği bu cihazda kullanılamıyor. '
              'AR içeriği yerine yerin detay sayfasındaki bilgi kartını ve '
              'fotoğrafları görüntüleyebilirsiniz.',
          primaryLabel: 'Geri Dön',
          onPrimary: () => Navigator.of(context).maybePop(),
        );
      case ArBlockingIssue.cameraDenied:
        final permanent =
            report.cameraPermission == PermissionStatus.permanentlyDenied;
        return _BlockedScaffold(
          title: titleWhenBlocked,
          icon: Icons.videocam_off_rounded,
          headline: 'Kamera izni gerekli',
          message:
              'AR deneyimi için telefonunuzun kamerasına erişmemiz gerekiyor. '
              '${permanent ? 'Lütfen ayarlardan izin verin.' : 'İzin penceresi açılınca "İzin Ver" seçeneğine dokunun.'}',
          primaryLabel: permanent ? 'Ayarlara Git' : 'İzin Ver',
          onPrimary: () async {
            if (permanent) {
              await openAppSettings();
            } else {
              await Permission.camera.request();
            }
            ref.invalidate(arReadinessProvider(requireLocation));
          },
          secondaryLabel: 'Geri Dön',
          onSecondary: () => Navigator.of(context).maybePop(),
        );
      case ArBlockingIssue.locationDenied:
        final permanent =
            report.locationPermission == LocationPermission.deniedForever;
        return _BlockedScaffold(
          title: titleWhenBlocked,
          icon: Icons.location_disabled_rounded,
          headline: 'Konum izni gerekli',
          message:
              'Konum tabanlı AR içeriklerinin doğru gösterilebilmesi için '
              'konum izni gerekiyor.${permanent ? ' Lütfen ayarlardan izin verin.' : ''}',
          primaryLabel: permanent ? 'Ayarlara Git' : 'İzin Ver',
          onPrimary: () async {
            if (permanent) {
              await Geolocator.openAppSettings();
            } else {
              await Geolocator.requestPermission();
            }
            ref.invalidate(arReadinessProvider(requireLocation));
          },
          secondaryLabel: 'Geri Dön',
          onSecondary: () => Navigator.of(context).maybePop(),
        );
      case ArBlockingIssue.locationServiceOff:
        return _BlockedScaffold(
          title: titleWhenBlocked,
          icon: Icons.location_off_rounded,
          headline: 'Konum servisleri kapalı',
          message:
              'Cihazınızın konum servisleri kapalı görünüyor. AR içeriklerinin '
              'doğru tetiklenebilmesi için lütfen konum servislerini açın.',
          primaryLabel: 'Konum Ayarlarını Aç',
          onPrimary: () async {
            await Geolocator.openLocationSettings();
            ref.invalidate(arReadinessProvider(requireLocation));
          },
          secondaryLabel: 'Geri Dön',
          onSecondary: () => Navigator.of(context).maybePop(),
        );
      case ArBlockingIssue.gpsAccuracyLow:
        return _BlockedScaffold(
          title: titleWhenBlocked,
          icon: Icons.gps_not_fixed_rounded,
          headline: 'GPS doğruluğu yetersiz',
          message:
              'Şu anki konum doğruluğunuz AR içeriği için yeterli değil '
              '(${report.gpsAccuracyMeters?.toStringAsFixed(0) ?? '?'} m). '
              'Açık bir alanda durup birkaç saniye bekleyin ve tekrar deneyin. '
              'Pusulanın kalibre olması için telefonu sekiz şeklinde hareket ettirebilirsiniz.',
          primaryLabel: 'Tekrar Dene',
          onPrimary: () =>
              ref.invalidate(arReadinessProvider(requireLocation)),
          secondaryLabel: 'Geri Dön',
          onSecondary: () => Navigator.of(context).maybePop(),
        );
    }
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _BlockedScaffold extends StatelessWidget {
  const _BlockedScaffold({
    required this.title,
    required this.icon,
    required this.headline,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final IconData icon;
  final String headline;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(title: Text(title), elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                icon,
                size: 72,
                color: isDark
                    ? AppColors.neonBlue
                    : theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      secondaryLabel!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
