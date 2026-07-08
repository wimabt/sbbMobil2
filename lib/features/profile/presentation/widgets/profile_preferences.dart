import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/providers/auth_provider.dart';

/// Profil ekranındaki hızlı tercihler: Tema seçici + Çıkış Yap.
///
/// Kullanıcı isteğiyle (2026-06) bu ikisi sık kullanıldığı için ayarlar
/// sayfasından buraya alındı; hesap yönetimi / gizlilik / hesap silme gibi
/// daha seyrek tercihler sağ üst dişli → [SettingsScreen]'de kalır.
class ProfilePreferences extends ConsumerWidget {
  const ProfilePreferences({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // ── Tema ──
          _SectionLabel(label: l10n.lblTheme),
          const SizedBox(height: 10),
          const _ThemeSegmentedControl(),

          const SizedBox(height: 24),

          // ── Çıkış Yap ──
          _LogoutButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),

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
// Theme Segmented Control — Compact horizontal tab switcher
// ═══════════════════════════════════════════════════════════════════════

class _ThemeSegmentedControl extends ConsumerWidget {
  const _ThemeSegmentedControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final currentMode = themeState.mode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    // Build short labels — strip " Mod" suffix if present (TR locale)
    final lightLabel = l10n.lblLightMode.replaceAll(' Mod', '');
    final darkLabel = l10n.lblDarkMode.replaceAll(' Mod', '');
    // For system, use first word if label is longer than 8 chars
    final systemLabel = l10n.lblSystemDefault.length > 8
        ? l10n.lblSystemDefault.split(' ').first
        : l10n.lblSystemDefault;

    final options = [
      _ThemeOptionData(
        icon: Icons.light_mode_rounded,
        label: lightLabel,
        mode: ThemeMode.light,
        appMode: AppThemeMode.light,
      ),
      _ThemeOptionData(
        icon: Icons.dark_mode_rounded,
        label: darkLabel,
        mode: ThemeMode.dark,
        appMode: AppThemeMode.dark,
      ),
      _ThemeOptionData(
        icon: Icons.brightness_auto_rounded,
        label: systemLabel,
        mode: ThemeMode.system,
        appMode: AppThemeMode.system,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: isDark
            ? Border.all(color: Colors.white.withAlpha(10), width: 1)
            : null,
        boxShadow: isDark ? null : AppElevation.level1,
      ),
      child: Row(
        children: options.map((option) {
          final isActive = currentMode == option.mode;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(themeProvider.notifier).setTheme(option.appMode);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark
                          ? AppColors.neonBlue.withAlpha(25)
                          : theme.colorScheme.primaryContainer)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isActive
                      ? Border.all(
                          color: isDark
                              ? AppColors.neonBlue.withAlpha(70)
                              : theme.colorScheme.primary.withAlpha(100),
                          width: 1.5,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      option.icon,
                      size: 20,
                      color: isActive
                          ? (isDark
                              ? AppColors.neonBlue
                              : theme.colorScheme.primary)
                          : theme.hintColor.withAlpha(150),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive
                            ? (isDark
                                ? AppColors.neonBlue
                                : theme.colorScheme.primary)
                            : theme.hintColor.withAlpha(180),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ThemeOptionData {
  const _ThemeOptionData({
    required this.icon,
    required this.label,
    required this.mode,
    required this.appMode,
  });

  final IconData icon;
  final String label;
  final ThemeMode mode;
  final AppThemeMode appMode;
}

// ═══════════════════════════════════════════════════════════════════════
// Logout Button — Outlined with subtle red accent
// ═══════════════════════════════════════════════════════════════════════

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final redAccent = isDark ? AppColors.neonPink : AppColors.error;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          Icons.logout_rounded,
          size: 20,
          color: redAccent.withAlpha(200),
        ),
        label: Text(
          l10n.btnLogout,
          style: TextStyle(
            color: redAccent.withAlpha(200),
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: -0.1,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: redAccent.withAlpha(isDark ? 50 : 40),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor:
              isDark ? redAccent.withAlpha(8) : redAccent.withAlpha(5),
        ),
      ),
    );
  }
}
