import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../models/recipe.dart';

enum RecipesTopTab { recipes, localFlavors }

class RecipesHeader extends StatelessWidget {
  const RecipesHeader({
    super.key,
    required this.categories,
    required this.activeCategory,
    required this.onCategoryChanged,
    required this.activeTopTab,
    required this.onTopTabChanged,
    this.onSearch,
    this.onFavoritesPressed,
    this.favoritesFilterActive = false,
    this.sortMenuKey,
    this.isSortActive = false,
    this.onSortTap,
  });

  final List<RecipeCategory> categories;
  final String activeCategory;
  final ValueChanged<String> onCategoryChanged;
  final RecipesTopTab activeTopTab;
  final ValueChanged<RecipesTopTab> onTopTabChanged;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onFavoritesPressed;
  /// Sağ üst kalp: yalnızca favorileri göster modu açık mı?
  final bool favoritesFilterActive;
  /// Arama çubuğundaki filtre butonuna ankrajlı sıralama menüsü için.
  final GlobalKey? sortMenuKey;
  /// Sıralama varsayılandan farklı mı (filtre butonu aktif rozeti).
  final bool isSortActive;
  /// Filtre butonuna basınca sıralama menüsünü aç. null ise buton gizlenir.
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
              _buildTitleRow(context, isDark),
              SizedBox(height: AppSpacing.sm),
              _buildTopTabs(context, isDark),
              SizedBox(height: AppSpacing.sm),
              AppSearchBar(
                hintText: context.l10n.lblSearchRecipes,
                showFilterButton: onSortTap != null,
                filterButtonKey: sortMenuKey,
                isFilterActive: isSortActive,
                onFilterTap: onSortTap,
                onChanged: onSearch,
              ),
              // Yalnızca "Tümü" varsa (gerçek kategori yok) pill'leri gizle —
              // tek başına "Tümü" anlamsız. En az bir gerçek kategori gerekir.
              if (categories.where((c) => c.id != 'all').isNotEmpty) ...[
                SizedBox(height: AppSpacing.sm),
                _buildCategoryPills(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.sectionLocalDelicacies,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : null,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              context.l10n.delicaciesSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: isDark ? Colors.white.withAlpha(150) : Theme.of(context).hintColor,
                  ),
            ),
          ],
        ),
        IconButton(
          tooltip: favoritesFilterActive
              ? context.l10n.filterShowAll
              : context.l10n.filterFavoritesOnly,
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

  Widget _buildTopTabs(BuildContext context, bool isDark) {
    final activeIsRecipes = activeTopTab == RecipesTopTab.recipes;
    final bgColor = isDark
        ? Colors.white.withAlpha(10)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final borderColor = isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(10);

    final activeGradient = isDark
        ? LinearGradient(
            colors: [
              AppColors.neonCyan.withAlpha(70),
              AppColors.neonBlue.withAlpha(45),
            ],
          )
        : LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withAlpha(210),
            ],
          );

    return SizedBox(
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: isDark ? null : AppElevation.level1,
        ),
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: activeIsRecipes ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    gradient: activeGradient,
                    boxShadow: isDark ? AppDarkEffects.neonGlow(AppColors.neonCyan) : null,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _topTabButton(
                    context,
                    isDark: isDark,
                    label: 'Tarifler',
                    icon: Icons.menu_book_rounded,
                    isActive: activeIsRecipes,
                    onTap: () => onTopTabChanged(RecipesTopTab.recipes),
                  ),
                ),
                Expanded(
                  child: _topTabButton(
                    context,
                    isDark: isDark,
                    label: context.l10n.sectionLocalDelicacies,
                    icon: Icons.local_dining_rounded,
                    isActive: !activeIsRecipes,
                    onTap: () => onTopTabChanged(RecipesTopTab.localFlavors),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _topTabButton(
    BuildContext context, {
    required bool isDark,
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final inactiveColor =
        isDark ? Colors.white.withAlpha(175) : Theme.of(context).hintColor;
    final activeColor = Colors.white;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          splashColor: isDark
              ? AppColors.neonCyan.withAlpha(25)
              : Theme.of(context).colorScheme.primary.withAlpha(25),
          highlightColor: Colors.transparent,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                            color: isActive ? activeColor : inactiveColor,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPills(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, _) => SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return CategoryPill(
            label: cat.label,
            icon: cat.icon as IconData,
            isActive: activeCategory == cat.id,
            onTap: () => onCategoryChanged(cat.id),
          );
        },
      ),
    );
  }
}

