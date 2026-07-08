import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../design/design_tokens.dart';

/// İzin türü — her biri için ayrı açıklama metni gösterilir.
enum PrePermissionKind { location, locationBackground, notification, camera }

/// §10.6.3 — Konum, kamera ve bildirim izinleri **istenmeden önce** ne için
/// kullanılacağını açıklayan ön-izin (pre-permission) sayfası.
///
/// OS izin dialog'undan önce gösterilir; kullanıcı "İzin Ver" derse çağıran
/// taraf gerçek OS iznini ister, "Şimdi Değil" derse istek hiç tetiklenmez.
/// Böylece kullanıcı bağlamı önceden anlar ve "kalıcı ret" riski azalır.
class PrePermissionSheet {
  const PrePermissionSheet._();

  /// Açıklamayı gösterir. `true` → kullanıcı devam etmek istiyor (OS izni
  /// istenebilir), `false` → vazgeçti.
  static Future<bool> show(BuildContext context, PrePermissionKind kind) async {
    final spec = _specFor(context.l10n, kind);
    final result = await showModalBottomSheet<bool>(
      context: context,
      // Shell'in alt navbar'ı + ortadaki floating harita butonu sheet'in üstünde
      // kalmasın diye root navigator'da aç (sheet ve scrim navbar'ı kapatır).
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (ctx) => _PrePermissionBody(spec: spec),
    );
    return result ?? false;
  }

  static _PermissionSpec _specFor(AppLocalizations l10n, PrePermissionKind kind) {
    switch (kind) {
      case PrePermissionKind.location:
        return _PermissionSpec(
          icon: Icons.near_me_rounded,
          title: l10n.permLocationTitle,
          description: l10n.permLocationDesc,
          bullets: [
            l10n.permLocationBullet1,
            l10n.permLocationBullet2,
            l10n.permLocationBullet3,
          ],
        );
      case PrePermissionKind.locationBackground:
        return _PermissionSpec(
          icon: Icons.my_location_rounded,
          title: l10n.permLocationBgTitle,
          description: l10n.permLocationBgDesc,
          bullets: [
            l10n.permLocationBgBullet1,
            l10n.permLocationBgBullet2,
            l10n.permLocationBgBullet3,
          ],
        );
      case PrePermissionKind.notification:
        return _PermissionSpec(
          icon: Icons.notifications_active_rounded,
          title: l10n.permNotifTitle,
          description: l10n.permNotifDesc,
          bullets: [
            l10n.permNotifBullet1,
            l10n.permNotifBullet2,
            l10n.permNotifBullet3,
          ],
        );
      case PrePermissionKind.camera:
        return _PermissionSpec(
          icon: Icons.photo_camera_rounded,
          title: l10n.permCameraTitle,
          description: l10n.permCameraDesc,
          bullets: [
            l10n.permCameraBullet1,
            l10n.permCameraBullet2,
            l10n.permCameraBullet3,
          ],
        );
    }
  }
}

class _PermissionSpec {
  const _PermissionSpec({
    required this.icon,
    required this.title,
    required this.description,
    required this.bullets,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> bullets;
}

class _PrePermissionBody extends StatelessWidget {
  const _PrePermissionBody({required this.spec});

  final _PermissionSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent =
        isDark ? AppColors.brandGreenBright : theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              ),
              child: Icon(spec.icon, size: 34, color: accent),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            spec.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            spec.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final b in spec.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      b,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              child: Text(
                context.l10n.btnGrantPermission,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                context.l10n.btnNotNow,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: theme.hintColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
