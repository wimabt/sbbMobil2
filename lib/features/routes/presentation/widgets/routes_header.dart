import 'package:flutter/material.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../l10n/l10n.dart';

class RoutesHeader extends StatelessWidget {
  const RoutesHeader({
    super.key,
    this.onSearch,
    this.onFavoritesPressed,
    this.favoritesFilterActive = false,
    this.sortMenuKey,
    this.isSortActive = false,
    this.onSortTap,
  });

  final ValueChanged<String>? onSearch;
  final VoidCallback? onFavoritesPressed;
  final bool favoritesFilterActive;
  /// Arama çubuğundaki filtre butonuna ankrajlı sıralama menüsü için.
  final GlobalKey? sortMenuKey;
  final bool isSortActive;
  final VoidCallback? onSortTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTitleSection(context, isDark),
              SizedBox(height: AppSpacing.sm),
              AppSearchBar(
                hintText: context.l10n.lblSearchRoutes,
                onChanged: onSearch,
                showFilterButton: onSortTap != null,
                filterButtonKey: sortMenuKey,
                isFilterActive: isSortActive,
                onFilterTap: onSortTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rotalar',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : null,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                // Points/gamification feature flag — kapalıyken jenerik bir cümle.
                FeatureFlags.pointsEnabled
                    ? 'Şehri keşfet, puan kazan'
                    : 'Şehri keşfetmeye başla',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: isDark ? Colors.white.withAlpha(150) : Theme.of(context).hintColor,
                    ),
              ),
            ],
          ),
        ),
        if (onFavoritesPressed != null)
          IconButton(
            tooltip: favoritesFilterActive
                ? 'Tümünü göster'
                : 'Yalnızca favorilerim',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: favoritesFilterActive
                    ? (isDark
                        ? AppColors.neonPink.withAlpha(55)
                        : Theme.of(context).colorScheme.errorContainer)
                    : (isDark
                        ? AppColors.neonPink.withAlpha(30)
                        : Theme.of(context).colorScheme.surfaceContainerHighest),
                borderRadius: BorderRadius.circular(12),
                border: isDark
                    ? Border.all(
                        color: favoritesFilterActive
                            ? AppColors.neonPink.withAlpha(100)
                            : AppColors.neonPink.withAlpha(60),
                      )
                    : null,
              ),
              child: Icon(
                favoritesFilterActive ? Icons.favorite : Icons.favorite_border,
                color: isDark ? AppColors.neonPink : Theme.of(context).colorScheme.error,
              ),
            ),
            onPressed: onFavoritesPressed,
          ),
      ],
    );
  }
}

