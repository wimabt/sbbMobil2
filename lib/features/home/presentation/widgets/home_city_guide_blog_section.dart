import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../l10n/l10n.dart';
import '../models/city_guide_blog_item.dart';

/// Tasarım: başlık + sağda ok; yatay kaydırmalı beyaz kartlar.
/// [items] verilmezse yalnızca UI için yer tutucu liste kullanılır — API sonra bağlanacak.
class HomeCityGuideBlogSection extends StatelessWidget {
  const HomeCityGuideBlogSection({
    super.key,
    this.items,
    this.onSeeAll,
    this.onItemTap,
  });

  final List<CityGuideBlogItem>? items;
  final VoidCallback? onSeeAll;
  final void Function(CityGuideBlogItem item)? onItemTap;

  // Eskiden hardcoded turuncu (0xFFD84315) idi. Marka uyumu için tema
  // primary'ye bağlandı (build içinde colorScheme'den okunuyor).
  static const double _thumb = 88;
  static const double _cardHeight = 102;

  static List<CityGuideBlogItem> _placeholderItems() => const [
        CityGuideBlogItem(
          id: 'placeholder-1',
          categoryLabel: 'GASTRONOMİ',
          title: "Samsun'da Tatmanız Gereken 5 Lezzet",
          imageUrl: '',
          readTimeLabel: '5 dk okuma',
          dateLabel: 'Bugün',
        ),
        CityGuideBlogItem(
          id: 'placeholder-2',
          categoryLabel: 'YAŞAM',
          title: 'Hafta Sonu İçin En İyi Sahil Rotaları',
          imageUrl: '',
          readTimeLabel: '4 dk okuma',
          dateLabel: 'Bugün',
        ),
        CityGuideBlogItem(
          id: 'placeholder-3',
          categoryLabel: 'KÜLTÜR',
          title: 'Şehir Merkezinde Gezilecek Noktalar',
          imageUrl: '',
          readTimeLabel: '6 dk okuma',
          dateLabel: 'Dün',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = items ?? _placeholderItems();
    if (data.isEmpty) return const SizedBox.shrink();

    final screenW = MediaQuery.sizeOf(context).width;
    final cardWidth = min(320.0, screenW * 0.88);
    const sep = AppSpacing.lg;
    const keepAliveCount = 4;
    final cacheExtent = (cardWidth + sep) * keepAliveCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: context.l10n.sectionCityGuideBlog,
          actionText: onSeeAll != null ? context.l10n.btnViewAll : null,
          onAction: onSeeAll,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            cacheExtent: cacheExtent,
            itemCount: data.length,
            separatorBuilder: (context, _) => const SizedBox(width: sep),
            itemBuilder: (context, index) {
              final item = data[index];
              final card = SizedBox(
                width: cardWidth,
                height: _cardHeight,
                child: _CityGuideBlogCard(
                  item: item,
                  isDark: isDark,
                  onTap: onItemTap != null ? () => onItemTap!(item) : null,
                ),
              );
              if (index < keepAliveCount) {
                return _KeepAliveBlogCard(child: card);
              }
              return card;
            },
          ),
        ),
      ],
    );
  }
}

class _KeepAliveBlogCard extends StatefulWidget {
  const _KeepAliveBlogCard({required this.child});

  final Widget child;

  @override
  State<_KeepAliveBlogCard> createState() => _KeepAliveBlogCardState();
}

class _KeepAliveBlogCardState extends State<_KeepAliveBlogCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _CityGuideBlogCard extends StatelessWidget {
  const _CityGuideBlogCard({
    required this.item,
    required this.isDark,
    this.onTap,
  });

  final CityGuideBlogItem item;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final metaColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF6B6B7B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                : null,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _BlogThumbnail(
                  imageUrl: item.imageUrl,
                  categoryLabel: item.categoryLabel,
                  isDark: isDark,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.categoryLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.readTimeLabel} · ${item.dateLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: metaColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

class _BlogThumbnail extends StatelessWidget {
  const _BlogThumbnail({
    required this.imageUrl,
    required this.categoryLabel,
    required this.isDark,
  });

  final String imageUrl;
  final String categoryLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    final placeholder = Container(
      width: HomeCityGuideBlogSection._thumb,
      height: HomeCityGuideBlogSection._thumb,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFF0F2F5),
        borderRadius: radius,
      ),
      child: Icon(
        _placeholderIconForCategory(categoryLabel),
        size: 36,
        color: isDark
            ? Colors.white.withValues(alpha: 0.25)
            : const Color(0xFFB0B8C1),
      ),
    );

    if (imageUrl.trim().isEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: placeholder,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: CachedImage(
        imageUrl: imageUrl,
        width: HomeCityGuideBlogSection._thumb,
        height: HomeCityGuideBlogSection._thumb,
        fit: BoxFit.cover,
        errorWidget: placeholder,
      ),
    );
  }

  IconData _placeholderIconForCategory(String cat) {
    final c = cat.toUpperCase();
    if (c.contains('GASTRONOM')) return Icons.restaurant_rounded;
    if (c.contains('YAŞAM') || c.contains('YASAM')) return Icons.beach_access_rounded;
    if (c.contains('KÜLTÜR') || c.contains('KULTUR')) return Icons.museum_rounded;
    return Icons.article_rounded;
  }
}
