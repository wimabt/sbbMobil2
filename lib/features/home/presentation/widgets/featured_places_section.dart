import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/services/analytics_events.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../l10n/l10n.dart';

/// Featured places section widget for home screen
/// Light Theme: Cards with 20px border-radius, soft diffuse shadows, high-quality images, bold dark typography
/// Dark Theme: Dark grey cards with 20px rounded corners, subtle thin light-grey border or inner glow, high-contrast white text
/// 
/// Performance optimizations:
/// - cacheExtent: Ekran dışındaki cardları bellekte tutar (ilk 7+ card her zaman hazır)
/// - addAutomaticKeepAlives: true - Cardlar scroll dışına çıkınca dispose edilmez
/// - CachedImage: Disk + memory cache ile görseller hızlı yüklenir
class FeaturedPlacesSection extends StatelessWidget {
  const FeaturedPlacesSection({
    super.key,
    required this.places,
    this.onViewAll,
    this.title,
    this.actionText,
    this.analyticsBucket,
  });

  final List<FeaturedPlace> places;
  final VoidCallback? onViewAll;

  /// Bölüm başlığını override eder. `null` ise `sectionFeaturedPlaces` (default).
  final String? title;

  /// "Tümünü gör" gibi sağdaki aksiyon metnini override eder.
  final String? actionText;

  /// `mobile_analytics_todo.md` §2.6 — discovery_card_tapped için bucket.
  /// `nearby` / `popular` / `new` — null ise content_tapped fire edilir.
  final String? analyticsBucket;

  @override
  Widget build(BuildContext context) {
    // Card genişliği (180) + separator (16) = ~196px per card
    // 7 card için: 7 * 196 = ~1400px cacheExtent
    // Bu sayede ilk 7 card her zaman bellekte kalır
    const double cardWidth = 180;
    const double separatorWidth = AppSpacing.lg; // 16
    const int keepAliveCount = 7;
    const double cacheExtent = (cardWidth + separatorWidth) * keepAliveCount;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title ?? context.l10n.sectionFeaturedPlaces,
          actionText: actionText ?? context.l10n.btnViewAll,
          onAction: onViewAll ?? () => context.push('/places'),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          // Biraz daha yüksek tutarak uzun başlık + mesafe satırında overflow'u engelle
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none, // Allow shadows to overflow
            itemCount: places.length,
            // ✅ PERFORMANCE: Ekran dışındaki cardları önceden yükle ve bellekte tut
            cacheExtent: cacheExtent,
            separatorBuilder: (context, _) => const SizedBox(width: AppSpacing.lg),
            itemBuilder: (context, index) {
              final place = places[index];
              // İlk 7 card için AutomaticKeepAlive ile bellekte tut
              // Diğer cardlar da cacheExtent sayesinde önceden yüklenir
              if (index < keepAliveCount) {
                return _KeepAliveFeaturedCard(
                  place: place,
                  position: index,
                  analyticsBucket: analyticsBucket,
                );
              }
              return _FeaturedPlaceCard(
                place: place,
                position: index,
                analyticsBucket: analyticsBucket,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// İlk N card için AutomaticKeepAlive wrapper
/// Bu cardlar asla dispose edilmez, her zaman bellekte kalır
class _KeepAliveFeaturedCard extends StatefulWidget {
  const _KeepAliveFeaturedCard({
    required this.place,
    required this.position,
    this.analyticsBucket,
  });

  final FeaturedPlace place;
  final int position;
  final String? analyticsBucket;

  @override
  State<_KeepAliveFeaturedCard> createState() => _KeepAliveFeaturedCardState();
}

class _KeepAliveFeaturedCardState extends State<_KeepAliveFeaturedCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli
    return _FeaturedPlaceCard(
      place: widget.place,
      position: widget.position,
      analyticsBucket: widget.analyticsBucket,
    );
  }
}

class _FeaturedPlaceCard extends ConsumerStatefulWidget {
  const _FeaturedPlaceCard({
    required this.place,
    required this.position,
    this.analyticsBucket,
  });

  final FeaturedPlace place;
  final int position;
  final String? analyticsBucket;

  @override
  ConsumerState<_FeaturedPlaceCard> createState() => _FeaturedPlaceCardState();
}

class _FeaturedPlaceCardState extends ConsumerState<_FeaturedPlaceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final place = widget.place;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        // mobile_analytics_todo.md §2.6 / §2.4 — bucket varsa discovery_card_tapped,
        // yoksa content_tapped (generic featured liste).
        final analytics = ref.read(analyticsServiceProvider);
        if (widget.analyticsBucket != null) {
          analytics.track(
            AnalyticsEvents.discoveryCardTapped,
            properties: {
              'entity_type': 'place',
              'entity_id': place.id,
              'bucket': widget.analyticsBucket!,
              'position': widget.position,
            },
          );
        } else {
          analytics.track(
            AnalyticsEvents.contentTapped,
            properties: {
              'entity_type': 'place',
              'entity_id': place.id,
            },
          );
        }
        // Tüm mekanlar için detay sayfasına git
        context.push('/places/${place.id}');
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(AppRadius.xl), // 20px
            border: isDark
                ? Border.all(
                    color: Colors.white.withAlpha(15),
                    width: 1,
                  )
                : null,
            boxShadow: isDark ? null : AppElevation.featuredCard,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section with gradient overlay
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image (asset veya network)
                    _buildPlaceImage(context, place.image, isDark),
                    // Subtle gradient overlay for dark theme
                    if (isDark)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.darkSurface.withAlpha(150),
                            ],
                          ),
                        ),
                      ),
                    // Category badge
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: _buildCategoryBadge(context, place.category, isDark),
                    ),
                    // Points badge
                    // Points/gamification feature flag — kart rozeti gizlenir.
                    if (FeatureFlags.pointsEnabled && place.hasPoints)
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: _buildPointsBadge(context, place, isDark),
                      ),
                  ],
                ),
              ),
              // Content section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title - Bold dark typography (light) / High-contrast white (dark)
                      Text(
                        place.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Distance info
                      Row(
                        children: [
                          Icon(
                            Icons.near_me_outlined,
                            size: 12,
                            color: isDark
                                ? AppColors.neonCyan
                                : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            place.distance,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white.withAlpha(180)
                                  : Theme.of(context).colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceImage(BuildContext context, String image, bool isDark) {
    final errorPlaceholder = Container(
      color: isDark
          ? AppColors.darkSurfaceElevated
          : AppColors.lightBackground,
      child: Center(
        child: Icon(
          Icons.place_rounded,
          size: 32,
          color: isDark
              ? Colors.white.withAlpha(60)
              : Theme.of(context).colorScheme.primary.withAlpha(100),
        ),
      ),
    );

    // ✅ PERFORMANCE: CachedImage kullan - disk + memory cache
    // Network ve asset görselleri otomatik olarak cache'lenir
    // Görseller önceden yüklenir ve bellekte tutulur
    return CachedImage(
      imageUrl: image,
      fit: BoxFit.cover,
      // 180x126 card image boyutu (flex 3/5 oranı)
      // Memory cache için optimize edilmiş boyut
      width: 180,
      height: 126,
      errorWidget: errorPlaceholder,
    );
  }

  Widget _buildPointsBadge(BuildContext context, FeaturedPlace place, bool isDark) {
    final Color badgeColor;
    final Color bgColor;
    final IconData badgeIcon;
    final String badgeText;
    final Color textColor;

    if (place.isCampaignUpcoming) {
      badgeColor = isDark ? Colors.blueGrey[300]! : Colors.blueGrey;
      bgColor = Colors.black.withAlpha(170);
      badgeIcon = Icons.schedule_rounded;
      badgeText = 'Yakında';
      textColor = badgeColor;
    } else if (place.isCampaignExpired) {
      badgeColor = Colors.grey;
      bgColor = Colors.black.withAlpha(170);
      badgeIcon = Icons.event_busy_rounded;
      badgeText = 'Bitti';
      textColor = badgeColor;
    } else if (place.isPointsClaimed) {
      badgeColor = const Color(0xFF4CAF50);
      bgColor = Colors.green.withAlpha(200);
      badgeIcon = Icons.check_circle;
      badgeText = 'Alındı';
      textColor = Colors.white;
    } else {
      badgeColor = const Color(0xFFFFB74D);
      bgColor = Colors.black.withAlpha(170);
      badgeIcon = Icons.stars_rounded;
      badgeText = '+${place.points}';
      textColor = badgeColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: badgeColor.withAlpha(100),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 11, color: textColor),
          const SizedBox(width: 3),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(BuildContext context, String category, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withAlpha(150)
            : Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: isDark
            ? Border.all(
                color: Colors.white.withAlpha(20),
                width: 1,
              )
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Featured place model
class FeaturedPlace {
  const FeaturedPlace({
    required this.id,
    required this.title,
    required this.category,
    required this.distance,
    required this.image,
    this.points,
    this.visited = false,
    this.claimed = false,
    this.campaignStatus,
  });

  final String id;
  final String title;
  final String category;
  final String distance;
  final String image;
  final int? points;
  final bool visited;
  final bool claimed;
  final String? campaignStatus;

  bool get hasPoints => points != null && points! > 0;
  bool get isPointsClaimed => claimed;
  bool get isCampaignUpcoming => campaignStatus == 'upcoming';
  bool get isCampaignExpired => campaignStatus == 'expired';
}
