import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../data/models/models.dart';
import 'pill_marker.dart';

/// Harita alt kategori chip'i için seçenek modeli.
/// Slug filtreleme anahtarı, label görünen ad, count o alt kategorideki
/// place sayısıdır (sıralama için; UI'da gösterilmez).
class MapSubcategoryOption {
  const MapSubcategoryOption({
    required this.slug,
    required this.label,
    this.count = 0,
  });

  final String slug;
  final String label;
  final int count;
}

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
    this.subcategories = const [],
    this.selectedSubcategorySlugs = const {},
    this.onSubcategoryToggled,
    this.onSubcategoriesCleared,
    this.subcategoryFilterAsButton = false,
  });

  final List<PlaceCategory> categories;
  /// null ise yerelleştirilmiş "Tümü"/"All" kullanılır (build içinde çözülür).
  final String? selectedCategory;
  final ValueChanged<String>? onCategorySelected;
  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onSearchChanged;

  /// Seçili kategorinin alt kategorileri. Boşsa alt kategori satırı
  /// render edilmez (satır AnimatedSize ile açılır/kapanır).
  final List<MapSubcategoryOption> subcategories;
  /// Seçili alt kategori slug'ları (çoklu seçim).
  final Set<String> selectedSubcategorySlugs;
  final ValueChanged<String>? onSubcategoryToggled;
  /// Tüm alt kategori seçimlerini temizler (bottom sheet "Temizle").
  final VoidCallback? onSubcategoriesCleared;

  /// Görünüm varyantı — karşılaştırma için iki uygulama da mevcut:
  /// * `false` (varsayılan): alt kategoriler, kategori chip'lerinin altında
  ///   yatay bir chip satırı olarak açılır.
  /// * `true`: chip satırı gizlenir; arama çubuğunun yanındaki liste butonu,
  ///   alt kategori varken filtre butonuna dönüşür ve bottom sheet açar.
  final bool subcategoryFilterAsButton;

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
        // ── ESKİ (alt kategori filtresi öncesi) — geri dönüş için saklandı ──
        // child: Column(
        //   mainAxisSize: MainAxisSize.min,
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   children: [
        //     _buildSearchRow(context),
        //     const SizedBox(height: 12),
        //     _buildCategoryFilters(context),
        //   ],
        // ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchRow(context),
            const SizedBox(height: 12),
            _buildCategoryFilters(context),
            // Alt kategori satırı — seçili kategorinin alt kategorileri.
            // AnimatedSize: satır içerik geldiğinde yumuşakça açılır,
            // kategori "Tümü"ye dönünce kapanır.
            // Buton varyantında (subcategoryFilterAsButton) satır gizli —
            // alt kategoriler arama yanındaki filtre butonundan açılır.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: (widget.subcategories.isEmpty ||
                      widget.subcategoryFilterAsButton)
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildSubcategoryFilters(context),
                    ),
            ),
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
        // ── ESKİ (alt kategori filtre butonu öncesi) — geri dönüş için ──
        // _buildListButton(isDark, backgroundColor, iconColor),
        // Buton varyantı: seçili kategorinin alt kategorisi varsa liste
        // butonu, alt kategori filtre butonuna dönüşür (kullanıcı talebi).
        // Alt kategori yokken liste butonu davranışı korunur.
        (widget.subcategoryFilterAsButton && widget.subcategories.isNotEmpty)
            ? _buildSubcategoryFilterButton(isDark, backgroundColor, iconColor)
            : _buildListButton(isDark, backgroundColor, iconColor),
      ],
    );
  }

  /// Alt kategori filtre butonu — liste butonuyla aynı boyut/gölge dili.
  /// Seçili alt kategori sayısı sağ üstte rozet olarak gösterilir.
  Widget _buildSubcategoryFilterButton(
      bool isDark, Color backgroundColor, Color iconColor) {
    final selectedCount = widget.selectedSubcategorySlugs.length;
    final hasSelection = selectedCount > 0;

    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: hasSelection ? iconColor : backgroundColor,
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
          onTap: () => _showSubcategorySheet(context),
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                color: hasSelection ? Colors.white : iconColor,
                size: 24,
              ),
              if (hasSelection)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: iconColor, width: 1),
                    ),
                    child: Text(
                      '$selectedCount',
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Alt kategori seçim bottom sheet'i (buton varyantı).
  ///
  /// Seçimler anında uygulanır (harita arkada canlı güncellenir) — ayrı
  /// "Uygula" butonuna gerek yok. `widget.selectedSubcategorySlugs` parent
  /// (MapScreen) tarafından yerinde mutate edilen aynı Set örneği olduğundan,
  /// sheet içi setState sonrası chip durumları güncel kalır.
  Future<void> _showSubcategorySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final hasSelection = widget.selectedSubcategorySlugs.isNotEmpty;
            return Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).padding.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ctx.l10n.lblSubcategories,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (hasSelection)
                        TextButton(
                          onPressed: () {
                            widget.onSubcategoriesCleared?.call();
                            setSheetState(() {});
                          },
                          child: Text(
                            ctx.l10n.btnClear,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(ctx).colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final sub in widget.subcategories)
                        _SubcategoryChip(
                          label: sub.label,
                          isSelected: widget.selectedSubcategorySlugs
                              .contains(sub.slug),
                          isDark: isDark,
                          onTap: () {
                            widget.onSubcategoryToggled?.call(sub.slug);
                            setSheetState(() {});
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
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

  /// Alt kategori chip satırı — ana kategori chip'lerinin küçük/ikincil
  /// versiyonu. Seçim solid dolgu yerine yumuşak marka-yeşili tonuyla
  /// gösterilir; böylece ana kategori (solid yeşil) ile görsel hiyerarşi
  /// korunur. Çoklu seçim: her chip bağımsız toggle.
  Widget _buildSubcategoryFilters(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.subcategories.length,
        separatorBuilder: (context, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final sub = widget.subcategories[index];
          final isSelected =
              widget.selectedSubcategorySlugs.contains(sub.slug);

          return _SubcategoryChip(
            label: sub.label,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => widget.onSubcategoryToggled?.call(sub.slug),
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

/// Alt kategori filtre chip'i — [_CategoryChip]'in küçük/ikincil versiyonu.
///
/// Tasarım dili: aynı pill formu (radius 999) ve gölge yaklaşımı, ancak
/// seçili durumda solid dolgu yerine yumuşak marka-yeşili ton + ince yeşil
/// çerçeve + onay ikonu kullanılır. Böylece ana kategori chip'i (solid
/// yeşil) her zaman görsel olarak baskın kalır.
class _SubcategoryChip extends StatelessWidget {
  const _SubcategoryChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final backgroundColor = isSelected
        ? activeColor.withAlpha(isDark ? 56 : 26)
        : (isDark ? AppColors.darkSurface : Colors.white);
    final textColor = isSelected
        ? (isDark
            ? Color.lerp(activeColor, Colors.white, 0.35)!
            : activeColor)
        : (isDark ? Colors.white70 : const Color(0xFF5A5A6E));
    final borderColor = isSelected
        ? activeColor.withAlpha(isDark ? 140 : 110)
        : (isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(6));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Onay ikonu kaldırıldı — seçili durum yalnızca renk/çerçeve
                // ile gösteriliyor (kullanıcı talebi: tik olmasın).
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
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
