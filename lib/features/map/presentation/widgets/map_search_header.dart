import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../data/models/models.dart';
import 'pill_marker.dart';

/// Modern floating search header for the map screen.
/// 
/// Features a clean white aesthetic with soft shadows,
/// matching the app's overall light and airy design language.
/// Supports both light and dark themes.
class MapSearchHeader extends StatefulWidget {
  const MapSearchHeader({
    super.key,
    required this.categories,
    this.selectedCategory,
    this.onCategorySelected,
    this.onSearch,
    this.onSearchChanged,
  });

  final List<PlaceCategory> categories;
  /// null ise yerelleştirilmiş "Tümü"/"All" kullanılır (build içinde çözülür).
  final String? selectedCategory;
  final ValueChanged<String>? onCategorySelected;
  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onSearchChanged;

  @override
  State<MapSearchHeader> createState() => _MapSearchHeaderState();
}

class _MapSearchHeaderState extends State<MapSearchHeader> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchRow(context),
            const SizedBox(height: 12),
            _buildCategoryFilters(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final hintColor = isDark ? Colors.white54 : Colors.grey.shade400;
    // Marka yeşili — eski mavi (`neonBlue` / `lightGradientStart`) değişti.
    final iconColor = Theme.of(context).colorScheme.primary;
    
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: isDark 
                  ? Border.all(color: Colors.white.withAlpha(15), width: 1)
                  : null,
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(40),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  Icons.search_rounded,
                  color: hintColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      widget.onSearchChanged?.call(value);
                      setState(() {}); // Clear button'u güncellemek için
                    },
                    onSubmitted: (value) {
                      widget.onSearch?.call(value);
                    },
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.mapSearchHint,
                      hintStyle: TextStyle(
                        color: hintColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                // Clear button
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear_rounded, color: hintColor, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      widget.onSearchChanged?.call('');
                      setState(() {});
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildListButton(isDark, backgroundColor, iconColor),
      ],
    );
  }

  Widget _buildListButton(bool isDark, Color backgroundColor, Color iconColor) {
    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark 
            ? Border.all(color: Colors.white.withAlpha(15), width: 1)
            : null,
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/places'),
          borderRadius: BorderRadius.circular(16),
          child: Icon(
            Icons.view_list_rounded,
            color: iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.categories.length,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final selectedCat = widget.selectedCategory ?? context.l10n.lblAll;
          final isSelected = category.label == selectedCat;
          
          final isAllCategory = category.label == context.l10n.lblAll || category.id == 'all';
          final iconString = isAllCategory ? null : category.icon;
          final categorySlug = isAllCategory ? null : category.slug;
          
          return _CategoryChip(
            label: category.label,
            isSelected: isSelected,
            categorySlug: categorySlug,
            iconString: iconString,
            isAllCategory: isAllCategory,
            isDark: isDark,
            color: category.color != null 
                ? _parseColor(category.color!) 
                : null,
            onTap: () => widget.onCategorySelected?.call(category.label),
          );
        },
      ),
    );
  }

  Color? _parseColor(String colorString) {
    try {
      final hex = colorString.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (e) {
      // Parse edilemezse null dön
    }
    return null;
  }
}

/// Individual category filter chip with icon support.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.categorySlug,
    this.iconString,
    this.isAllCategory = false,
    this.isDark = false,
    this.color,
  });

  final String label;
  final bool isSelected;
  final String? categorySlug;
  final String? iconString;
  final bool isAllCategory;
  final bool isDark;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Seçili chip rengi marka yeşili (eskiden mavi idi).
    final activeColor = Theme.of(context).colorScheme.primary;
    final backgroundColor = isSelected
        ? activeColor
        : (isDark ? AppColors.darkSurface : Colors.white);
    final textColor = isSelected
        ? Theme.of(context).colorScheme.onPrimary
        : (isDark ? Colors.white : const Color(0xFF1A1A2E));
    final borderColor = isSelected
        ? activeColor
        : (isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(6));
    final iconColorValue = isSelected
        ? Theme.of(context).colorScheme.onPrimary
        : (color ?? activeColor);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: isSelected
                            ? activeColor.withAlpha(60)
                            : Colors.black.withAlpha(30),
                        blurRadius: isSelected ? 12 : 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: isSelected
                            ? activeColor.withAlpha(40)
                            : Colors.black.withAlpha(8),
                        blurRadius: isSelected ? 12 : 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 3),
                      ),
                    ],
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                isAllCategory
                    ? Icon(
                        Icons.apps_rounded,
                        size: 16,
                        color: iconColorValue,
                      )
                    : (categorySlug != null || iconString != null)
                        ? CategoryIcon(
                            categorySlug: categorySlug,
                            iconString: iconString,
                            size: 16,
                            isSelected: isSelected,
                            isDark: isDark,
                          )
                        : Icon(
                            Icons.place_rounded,
                            size: 16,
                            color: iconColorValue,
                          ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
