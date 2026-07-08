import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../l10n/l10n.dart';

/// Profil ekranındaki "İçeriklerim" kısayolları.
///
/// Net ayrım kararı (2026-06): tema/dil/bildirim/yasal gibi *tercihler* sağ üst
/// dişli → [SettingsScreen]'e taşındı. Profilde yalnızca kullanıcıya ait
/// *içerik* kısayolları kalır: Favoriler ve Gezi Planları. Ayarlar kartıyla
/// görsel olarak aynı dili konuşan birleşik, yuvarlak köşeli kart.
class ProfileQuickLinks extends StatelessWidget {
  const ProfileQuickLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final items = <_QuickLinkData>[
      _QuickLinkData(
        icon: Icons.favorite_border_rounded,
        label: l10n.settingsFavorites,
        accent: isDark ? AppColors.neonPink : AppColors.error,
        onTap: () => context.push('/favorites'),
      ),
      _QuickLinkData(
        icon: Icons.map_outlined,
        label: l10n.settingsItineraries,
        accent: isDark ? AppColors.neonBlue : AppColors.brandGreenMid,
        onTap: () => context.push('/itinerary'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              l10n.profileMyContent.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: isDark
                    ? AppColors.textSecondaryDark.withAlpha(180)
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
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
                if (index.isOdd) return _buildInsetDivider(isDark);
                final itemIndex = index ~/ 2;
                return _buildRow(
                  context: context,
                  item: items[itemIndex],
                  isDark: isDark,
                  isFirst: itemIndex == 0,
                  isLast: itemIndex == items.length - 1,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required _QuickLinkData item,
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
        splashColor: item.accent.withAlpha(12),
        highlightColor: item.accent.withAlpha(6),
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.accent.withAlpha(isDark ? 38 : 24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 20, color: item.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : null,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
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

  Widget _buildInsetDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 66, right: 16),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(12),
      ),
    );
  }
}

class _QuickLinkData {
  const _QuickLinkData({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
}
