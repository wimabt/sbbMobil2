import 'package:flutter/material.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/scale_tap_wrapper.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../l10n/l10n.dart';

/// Ana sayfa — üst başlık + 3x2 kategori kartı ızgarası.
/// Tıklama davranışı [onCategoryTap] / [onSeeAll] ile dışarıdan bağlanır.
class CategoriesSection extends StatelessWidget {
  const CategoriesSection({
    super.key,
    this.onSeeAll,
    this.onCategoryTap,
  });

  final VoidCallback? onSeeAll;
  final void Function(String categoryId)? onCategoryTap;

  static const List<String> _categoryIds = [
    'health_tourism',
    'discover_samsun',
    'gastronomy',
    'historical_museums',
    'nature_parks',
    'beaches',
  ];

  /// Yerel görseller — aynı dosya adlarıyla `assets/images/categories/` içinde değiştirebilirsiniz.
  static const List<String> _categoryImageAssets = [
    'assets/images/categories/category_health_tourism.jpg',
    'assets/images/categories/category_discover_samsun.jpg',
    'assets/images/categories/category_gastronomy.jpg',
    'assets/images/categories/category_historical_museums.jpg',
    'assets/images/categories/category_nature_parks.jpg',
    'assets/images/categories/category_beaches.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titles = [
      l10n.categoryHealthTourism,
      l10n.categoryDiscoverSamsun,
      l10n.categoryGastronomy,
      l10n.categoryHistoricalMuseums,
      l10n.categoryNatureParks,
      l10n.categoryBeaches,
    ];
    final items = List.generate(
      _categoryIds.length,
      (i) => _CategoryTileData(
        id: _categoryIds[i],
        title: titles[i],
        icon: _icons[i],
        imageAsset: _categoryImageAssets[i],
        lightGradient: _lightGradients[i],
        darkGradient: _darkGradients[i],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.sectionCategories,
          actionText: onSeeAll != null ? l10n.btnViewAll : null,
          onAction: onSeeAll == null
              ? null
              : () {
                  Haptics.selection();
                  onSeeAll!.call();
                },
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            const gap = AppSpacing.md;
            final cellW = (maxW - 2 * gap) / 3;
            final cardH = cellW * 1.12;

            Widget cell(_CategoryTileData data) {
              return SizedBox(
                width: cellW,
                height: cardH,
                child: _CategoryCard(
                  data: data,
                  isDark: isDark,
                  onTap: () {
                    Haptics.selection();
                    onCategoryTap?.call(data.id);
                  },
                ),
              );
            }

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    cell(items[0]),
                    cell(items[1]),
                    cell(items[2]),
                  ],
                ),
                SizedBox(height: gap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    cell(items[3]),
                    cell(items[4]),
                    cell(items[5]),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CategoryTileData {
  const _CategoryTileData({
    required this.id,
    required this.title,
    required this.icon,
    required this.imageAsset,
    required this.lightGradient,
    required this.darkGradient,
  });

  final String id;
  final String title;
  final IconData icon;
  final String imageAsset;
  final List<Color> lightGradient;
  final List<Color> darkGradient;
}

const List<IconData> _icons = [
  Icons.medical_services_rounded,
  Icons.explore_rounded,
  Icons.restaurant_menu_rounded,
  Icons.museum_rounded,
  Icons.park_rounded,
  Icons.beach_access_rounded,
];

const List<List<Color>> _lightGradients = [
  [Color(0xFFB8D4E3), Color(0xFF7FA8BC)],
  [Color(0xFF9FD4B8), Color(0xFF004D26)],
  [Color(0xFFD4A574), Color(0xFF8B5A3C)],
  [Color(0xFF90A4AE), Color(0xFF546E7A)],
  [Color(0xFFA5D6A7), Color(0xFF004D26)],
  [Color(0xFF64B5F6), Color(0xFF0277BD)],
];

const List<List<Color>> _darkGradients = [
  [Color(0xFF37474F), Color(0xFF263238)],
  [Color(0xFF1B5E20), Color(0xFF004D26)],
  [Color(0xFF5D4037), Color(0xFF3E2723)],
  [Color(0xFF455A64), Color(0xFF263238)],
  [Color(0xFF2E7D32), Color(0xFF002818)],
  [Color(0xFF01579B), Color(0xFF002F4F)],
];

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.data,
    required this.isDark,
    required this.onTap,
  });

  final _CategoryTileData data;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = isDark ? data.darkGradient : data.lightGradient;

    return ScaleTapWrapper(
      onTap: onTap,
      scaleEnd: 0.97,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: isDark ? AppElevation.level1 : AppElevation.featuredCard,
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.08))
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  data.imageAsset,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  // Decoded bitmap'i hücre genişliğine göre küçük tut.
                  // Kart genelde ~150-200dp, 360 cacheWidth retina'da bile
                  // yeterli. Cold start image decode süresini ~3-5x kısaltır.
                  cacheWidth: 360,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors,
                        ),
                      ),
                    );
                  },
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: isDark ? 0.2 : 0.12),
                      Colors.black.withValues(alpha: isDark ? 0.58 : 0.48),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      data.icon,
                      color: Colors.white,
                      size: 20,
                      shadows: const [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        data.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.25,
                          letterSpacing: 0,
                          shadows: [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        strutStyle: const StrutStyle(
                          fontSize: 12,
                          height: 1.25,
                          forceStrutHeight: true,
                          leading: 0,
                        ),
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
