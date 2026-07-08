import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/permissions/pre_permission_sheet.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/notification_prefs_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/geofence_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/providers/auth_provider.dart';

/// Uygulamanın **tek** ayar gövdesi. Eskiden hem profilde inline hem de ayrı
/// `/settings` ekranında ayrı ayrı kodlanan ayarlar burada birleştirildi; artık
/// yalnızca [SettingsScreen] (sağ üst dişli) bunu render eder. Profil ekranı
/// sadece kimlik + istatistik + "içeriklerim" kısayollarını gösterir.
///
/// iOS 18 / Material Design 3 inspired — dark mode optimized.
///
/// Tema seçimi ve Çıkış Yap, kullanıcı isteğiyle Profil ekranına taşındı
/// ([ProfilePreferences]); burada yalnızca hesap yönetimi ve gizlilik
/// tercihleri kalır.
///
/// Structure:
///   1. Unified card with Account, Language, Notifications, Legal
///   2. Notification sheet içinde Analitik (KVKK) opt-out
///   3. Hesabımı Sil (KVKK)
class SettingsSection extends ConsumerWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // ── Section label: Settings ──
          _SectionLabel(label: l10n.lblSettings),
          const SizedBox(height: 10),
          const _SettingsCard(),

          const SizedBox(height: 24),

          // ── Hesabımı Sil — KVKK §14.4.2 + App Store 5.1.1 zorunluluğu ──
          const _DeleteAccountButton(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Section label — uppercase, subtle, letter-spaced
// ═══════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: isDark
              ? AppColors.textSecondaryDark.withAlpha(180)
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Settings Card — Unified rounded container with inset dividers
// 60px row height, stroke icons left, chevrons right
// ═══════════════════════════════════════════════════════════════════════

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final localeState = ref.watch(localeProvider);

    // Favoriler/Gezi Planları "içeriklerim" olarak profile taşındı (net ayrım);
    // burada sadece gerçek tercih/yönetim öğeleri kalır.
    final items = [
      _SettingsItemData(
        icon: Icons.manage_accounts_outlined,
        label: l10n.accountTitle,
        onTap: () => context.push('/account'),
      ),
      _SettingsItemData(
        icon: Icons.language_rounded,
        label: l10n.lblLanguage,
        subtitle: '${localeState.flagEmoji} ${localeState.languageName}',
        onTap: () => _showLanguageSheet(context, ref),
      ),
      _SettingsItemData(
        icon: Icons.notifications_outlined,
        label: l10n.lblNotifications,
        onTap: () => _showNotificationSheet(context, ref),
      ),
      // §10.6.3 / §14.2.3 — Aydınlatma, Açık Rıza, Gizlilik, Kullanım Koşulları
      _SettingsItemData(
        icon: Icons.gavel_rounded,
        label: l10n.settingsLegal,
        subtitle: l10n.settingsLegalSubtitle,
        onTap: () => context.push('/legal'),
      ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: Colors.white.withAlpha(10), width: 1)
            : null,
        boxShadow: isDark ? null : AppElevation.level1,
      ),
      child: Column(
        children: List.generate(items.length * 2 - 1, (index) {
          if (index.isOdd) {
            return _buildInsetDivider(isDark);
          }
          final itemIndex = index ~/ 2;
          final item = items[itemIndex];
          final isFirst = itemIndex == 0;
          final isLast = itemIndex == items.length - 1;
          return _buildSettingsRow(
            context: context,
            item: item,
            isDark: isDark,
            isFirst: isFirst,
            isLast: isLast,
          );
        }),
      ),
    );
  }

  Widget _buildSettingsRow({
    required BuildContext context,
    required _SettingsItemData item,
    required bool isDark,
    required bool isFirst,
    required bool isLast,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        splashColor: isDark
            ? AppColors.neonBlue.withAlpha(12)
            : theme.colorScheme.primary.withAlpha(12),
        highlightColor: isDark
            ? AppColors.neonBlue.withAlpha(6)
            : theme.colorScheme.primary.withAlpha(6),
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // ── Icon container ──
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(10)
                        : theme.colorScheme.surfaceContainerHighest
                            .withAlpha(180),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: isDark
                        ? Colors.white.withAlpha(210)
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 14),

                // ── Label + optional subtitle ──
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : null,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor.withAlpha(160),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Chevron ──
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark
                      ? Colors.white.withAlpha(50)
                      : theme.hintColor.withAlpha(100),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Inset divider — does not touch edges
  Widget _buildInsetDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 66, right: 16),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: isDark
            ? Colors.white.withAlpha(10)
            : Colors.black.withAlpha(12),
      ),
    );
  }

  // ── Language Bottom Sheet ──
  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localeState = ref.read(localeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle indicator
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(30)
                      : Colors.black.withAlpha(25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.languageSheetTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _LanguageTile(
                flag: '🇹🇷',
                name: 'Türkçe',
                locale: const Locale('tr'),
                isSelected: localeState.isTurkish,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _LanguageTile(
                flag: '🇬🇧',
                name: 'English',
                locale: const Locale('en'),
                isSelected: localeState.isEnglish,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notification Bottom Sheet ──
  void _showNotificationSheet(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      // Kök navigator'da aç: aksi halde sheet shell'in branch navigator'ında
      // çizilir ve ortadaki harita FAB'ı + alt bar üstünde kalır.
      useRootNavigator: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NotificationSheet(isDark: isDark),
    );
  }
}

class _SettingsItemData {
  const _SettingsItemData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;
}

// ═══════════════════════════════════════════════════════════════════════
// Language Tile — used in bottom sheet
// ═══════════════════════════════════════════════════════════════════════

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile({
    required this.flag,
    required this.name,
    required this.locale,
    required this.isSelected,
    required this.isDark,
  });

  final String flag;
  final String name;
  final Locale locale;
  final bool isSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(localeProvider.notifier).setLocale(locale);
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.neonBlue.withAlpha(20)
                    : theme.colorScheme.primaryContainer.withAlpha(120))
                : (isDark
                    ? Colors.white.withAlpha(6)
                    : theme.colorScheme.surfaceContainerHighest
                        .withAlpha(100)),
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: isDark
                        ? AppColors.neonBlue.withAlpha(60)
                        : theme.colorScheme.primary.withAlpha(80),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color:
                      isDark ? AppColors.neonBlue : theme.colorScheme.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Notification Sheet — Bottom sheet with toggles
// ═══════════════════════════════════════════════════════════════════════

class _NotificationSheet extends ConsumerWidget {
  const _NotificationSheet({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pushState = ref.watch(notificationProvider);
    final pushNotifier = ref.read(notificationProvider.notifier);
    final prefs = ref.watch(notificationPrefsProvider);
    final prefsNotifier = ref.read(notificationPrefsProvider.notifier);
    final geofenceState = ref.watch(geofenceProvider).value ?? const GeofenceState();
    final geofenceNotifier = ref.read(geofenceProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle indicator
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(30)
                    : Colors.black.withAlpha(25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.notifSheetTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // §7.4.2 — Genel push (master switch + permission)
            // Değer KALICI kullanıcı tercihini (prefs.general) yansıtır; anlık
            // izin okuması (hasPushPermission) bir an false dönünce anahtarın
            // "kendi kendine kapanmasını" önler. OS izni onChanged'de istenir.
            _buildToggleRow(
              context: context,
              icon: Icons.notifications_active_outlined,
              title: context.l10n.notifGeneralTitle,
              subtitle: context.l10n.notifGeneralSubtitle,
              value: prefs.general,
              onChanged: (enabled) async {
                // Kapatma her zaman serbest.
                if (!enabled) {
                  await prefsNotifier.setGeneral(false);
                  return;
                }
                // Açılıyor → GERÇEK OS iznini garanti et. Eski davranışta izin
                // reddedilse (veya kalıcı reddedildiği için sistem diyaloğu hiç
                // çıkmasa) bile setGeneral(true) çağrılıp toggle "açık/izin
                // verildi" görünüyordu ama bildirim gelmiyordu. Artık izin
                // fiilen alınmadıkça toggle açılmaz.
                var granted = pushState.hasPushPermission;
                if (!granted) {
                  // §10.6.3 — OS izninden önce açıklama göster.
                  final proceed = await PrePermissionSheet.show(
                      context, PrePermissionKind.notification);
                  if (!proceed) return;
                  granted = await pushNotifier.requestPushPermission();
                }
                if (!granted) {
                  // İzin verilmedi → toggle'ı açma, sistem ayarlarına yönlendir
                  // (Android'de kalıcı reddedilmişse OS diyaloğu bir daha çıkmaz).
                  if (context.mounted) {
                    _showNotificationPermissionDialog(context);
                  }
                  return;
                }
                await prefsNotifier.setGeneral(true);
              },
            ),
            const SizedBox(height: 10),

            // §7.4.2 — Kampanya bildirimleri
            _buildToggleRow(
              context: context,
              icon: Icons.campaign_outlined,
              title: context.l10n.notifCampaignsTitle,
              subtitle: context.l10n.notifCampaignsSubtitle,
              value: prefs.campaigns,
              enabled: prefs.general && pushState.hasPushPermission,
              onChanged: (enabled) => prefsNotifier.setCampaigns(enabled),
            ),
            const SizedBox(height: 10),

            // §7.4.2 — Etkinlik bildirimleri
            _buildToggleRow(
              context: context,
              icon: Icons.event_outlined,
              title: context.l10n.notifEventsTitle,
              subtitle: context.l10n.notifEventsSubtitle,
              value: prefs.events,
              enabled: prefs.general && pushState.hasPushPermission,
              onChanged: (enabled) => prefsNotifier.setEvents(enabled),
            ),
            const SizedBox(height: 10),

            // §7.4.2 — Lokasyon bazlı (geofence) — kendi servisinde
            _buildToggleRow(
              context: context,
              icon: Icons.near_me_outlined,
              title: context.l10n.notifNearbyTitle,
              subtitle: context.l10n.notifNearbySubtitle,
              value: geofenceState.isEnabled,
              onChanged: (enabled) async {
                if (enabled) {
                  // §10.6.3 — arka plan konum izninden önce açıklama göster.
                  final proceed = await PrePermissionSheet.show(
                      context, PrePermissionKind.locationBackground);
                  if (!proceed) return;
                  final success = await geofenceNotifier.enable();
                  if (!success && context.mounted) {
                    _showPermissionDialog(context);
                  }
                } else {
                  await geofenceNotifier.disable();
                }
              },
            ),

            // Info banner when geofencing is active
            if (geofenceState.isEnabled) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(6)
                      : theme.colorScheme.surfaceContainerHighest
                          .withAlpha(100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: theme.hintColor.withAlpha(160),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.geofenceActiveInfo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor.withAlpha(160),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Last zone check
            if (geofenceState.isEnabled &&
                geofenceState.lastCheckResult != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context: context,
                label: context.l10n.lblLastCheck,
                value: geofenceState.lastCheckResult!,
              ),
            ],

            // Test/teşhis: konumu hemen kontrol et (resume/15dk beklemeden).
            // Sonuç yukarıdaki "Son kontrol" satırında görünür — SnackBar YOK
            // (SnackBar haritadaki FAB'ı yukarı itip bozuyordu).
            // Tam genişlik + alt alta → dar ekranda taşma olmaz.
            if (geofenceState.isEnabled) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  // Zorla test: bölgedeyse her zaman gerçek sistem bildirimi
                  // üretir (enter/exit + cooldown atlanır).
                  onPressed: () => geofenceNotifier.forceCheckAndNotify(),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(context.l10n.geofenceCheckNow),
                ),
              ),
              // Sıfırlama (cooldown + "içeride") yalnız debug yapısında.
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await geofenceNotifier.debugResetAllCooldowns();
                      await geofenceNotifier.checkLocation();
                    },
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Sıfırla & dene'),
                  ),
                ),
              ],
            ],

            // District subscription
            if (pushState.currentDistrict != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context: context,
                label: context.l10n.lblFollowedDistrict,
                value: _formatDistrict(pushState.currentDistrict!),
              ),
            ],

            // mobile_analytics_todo.md §1.2 — Anonim kullanım istatistikleri
            // opt-out'u (KVKK). Eski /settings sheet'inden buraya taşındı ki
            // tek ayar gövdesinde korunsun.
            const SizedBox(height: 16),
            _AnalyticsOptOutRow(isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final disabledOpacity = enabled ? 1.0 : 0.45;

    return Opacity(
      opacity: disabledOpacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withAlpha(6)
              : theme.colorScheme.surfaceContainerHighest.withAlpha(100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(10)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor.withAlpha(160),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeThumbColor: isDark ? AppColors.neonBlue : null,
              activeTrackColor: isDark
                  ? AppColors.neonBlue.withValues(alpha: 0.45)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistrict(String slug) {
    const districts = {
      'kavak': 'Kavak',
      'atakum': 'Atakum',
      'ilkadim': 'İlkadım',
      'canik': 'Canik',
      'tekkeköy': 'Tekkeköy',
      'terme': 'Terme',
      'bafra': 'Bafra',
      'samsun': 'Samsun Merkez',
    };
    return districts[slug.toLowerCase()] ?? slug;
  }

  /// Bildirim OS izni verilmediğinde: açıklama + sistem ayarlarına yönlendirme.
  /// (Konum diyaloğunun bildirim karşılığı.)
  void _showNotificationPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.notifications_off, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: Text(context.l10n.dlgNotifPermissionTitle)),
          ],
        ),
        content: Text(context.l10n.dlgNotifPermissionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.btnOk),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Geolocator.openAppSettings();
            },
            child: Text(context.l10n.btnGoToSettings),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: Text(context.l10n.dlgLocationPermissionTitle)),
          ],
        ),
        content: Text(context.l10n.dlgLocationPermissionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.btnOk),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Geolocator.openAppSettings();
            },
            child: Text(context.l10n.btnGoToSettings),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Analytics Opt-Out Row — KVKK kullanım istatistikleri toggle'ı
// ═══════════════════════════════════════════════════════════════════════

class _AnalyticsOptOutRow extends ConsumerStatefulWidget {
  const _AnalyticsOptOutRow({required this.isDark});

  final bool isDark;

  @override
  ConsumerState<_AnalyticsOptOutRow> createState() =>
      _AnalyticsOptOutRowState();
}

class _AnalyticsOptOutRowState extends ConsumerState<_AnalyticsOptOutRow> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    // Service init zaten cold start'ta SharedPreferences'tan okuyor; sync getter.
    _enabled = ref.read(analyticsServiceProvider).isEnabled;
  }

  Future<void> _onToggle(bool value) async {
    setState(() => _enabled = value);
    await ref.read(analyticsServiceProvider).setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(8)
            : theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.neonBlue.withAlpha(30)
                  : theme.colorScheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.insights_outlined,
              size: 18,
              color: isDark ? AppColors.neonBlue : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.settingsAnalyticsTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.settingsAnalyticsSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: _enabled,
            onChanged: _onToggle,
            activeThumbColor: isDark ? AppColors.neonBlue : null,
            activeTrackColor:
                isDark ? AppColors.neonBlue.withValues(alpha: 0.45) : null,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Hesap Silme — KVKK §14.4.2 + App Store 5.1.1
// İki aşamalı onay akışı (uyarı + sebep) → (yazılı doğrulama) → backend.
// ═══════════════════════════════════════════════════════════════════════

class _DeleteAccountButton extends ConsumerWidget {
  const _DeleteAccountButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dangerColor = isDark ? AppColors.neonPink : AppColors.error;

    return Center(
      child: TextButton.icon(
        onPressed: () => _showFirstWarning(context, ref),
        icon: Icon(
          Icons.delete_forever_outlined,
          size: 18,
          color: dangerColor.withAlpha(180),
        ),
        label: Text(
          context.l10n.btnDeleteAccount,
          style: TextStyle(
            color: dangerColor.withAlpha(200),
            fontWeight: FontWeight.w500,
            fontSize: 13,
            letterSpacing: -0.1,
            decoration: TextDecoration.underline,
            decorationColor: dangerColor.withAlpha(100),
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Future<void> _showFirstWarning(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dangerColor = theme.brightness == Brightness.dark
        ? AppColors.neonPink
        : AppColors.error;
    String? selectedReason;
    final reasons = _reasonsFor(l10n);

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: dangerColor),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.deleteAccountWarnTitle)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deleteAccountIfYouDelete,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _DeleteBulletList(items: [
                  l10n.deleteAccountBulletProfile,
                  l10n.deleteAccountBulletFavorites,
                  l10n.deleteAccountBulletHistory,
                  l10n.deleteAccountBulletNotifications,
                ]),
                const SizedBox(height: 12),
                Text(
                  l10n.deleteAccountReSignupNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.lblReasonOptional,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (v) => setState(() => selectedReason = v),
                  child: Column(
                    children: reasons
                        .map((r) => RadioListTile<String>(
                              title: Text(r,
                                  style: const TextStyle(fontSize: 13)),
                              value: r,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.btnGiveUp),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: dangerColor),
              child: Text(l10n.btnContinue),
            ),
          ],
        ),
      ),
    );

    if (proceed != true || !context.mounted) return;
    await _showFinalConfirmation(context, ref, selectedReason);
  }

  Future<void> _showFinalConfirmation(
    BuildContext context,
    WidgetRef ref,
    String? reason,
  ) async {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dangerColor = theme.brightness == Brightness.dark
        ? AppColors.neonPink
        : AppColors.error;
    final requiredText = l10n.deleteAccountConfirmWord;
    final textCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final isMatch = textCtrl.text.trim() == requiredText;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.dangerous_rounded, color: dangerColor),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.deleteAccountFinalTitle)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deleteAccountConfirmPrompt(requiredText),
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textCtrl,
                  decoration: InputDecoration(
                    hintText: requiredText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.btnGiveUp),
              ),
              FilledButton(
                onPressed: isMatch ? () => Navigator.of(ctx).pop(true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: dangerColor,
                  disabledBackgroundColor: dangerColor.withAlpha(80),
                ),
                child: Text(l10n.btnDeleteAccount),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await _performDeletion(context, ref, reason);
  }

  Future<void> _performDeletion(
    BuildContext context,
    WidgetRef ref,
    String? reason,
  ) async {
    // KRİTİK: deleteAccount başarılı olunca auth state `unauthenticated` olur
    // ve ProfileScreen `LoginScreen`'e döner → bu fonksiyonun `context`'i unmount
    // olur. Bu yüzden loading dialog'u `context.mounted`'a bağlı OLMADAN, await
    // öncesi yakaladığımız navigator/messenger üzerinden yönetiyoruz. Aksi halde
    // spinner sonsuza dek açık kalıyordu.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final l10n = context.l10n;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await ref
        .read(authProvider.notifier)
        .deleteAccount(reason: reason);

    // Loading dialog'u her durumda kapat (yakalanan navigator state'i hâlâ canlı).
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }

    if (result.success) {
      // Başarılı: artık LoginScreen'deyiz. Bilgilendirmeyi root navigator
      // üzerinde bir dialog ile göster (snackbar yeni ekranda kaybolabiliyor).
      final daysMsg = result.daysRemaining != null
          ? l10n.deleteAccountDaysRemaining(result.daysRemaining!)
          : (result.message ?? l10n.deleteAccountMarkedGeneric);

      final dialogContext = rootNavigator.context;
      if (!dialogContext.mounted) return;
      await showDialog<void>(
        context: dialogContext,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.deleteAccountDoneTitle)),
            ],
          ),
          content: Text(daysMsg, style: const TextStyle(height: 1.5)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.btnOk),
            ),
          ],
        ),
      );
    } else {
      // Başarısız: state authenticated kaldı, hâlâ profildeyiz → snackbar yeterli.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.errorMessage ?? l10n.deleteAccountFailed,
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: errorColor,
        ),
      );
    }
  }

  static List<String> _reasonsFor(AppLocalizations l10n) => [
        l10n.deleteReasonNotUsing,
        l10n.deleteReasonMissingFeatures,
        l10n.deleteReasonPrivacy,
        l10n.deleteReasonTooManyNotifs,
        l10n.deleteReasonSwitchedApp,
        l10n.deleteReasonPreferNotSay,
      ];
}

class _DeleteBulletList extends StatelessWidget {
  const _DeleteBulletList({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('•', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item, style: const TextStyle(height: 1.4)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
