import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/navigation_utils.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/widgets/circular_icon_button.dart';
import '../../../core/mixins/collapsing_scroll_mixin.dart';
import '../../../data/models/favorite.dart';
import '../../../data/models/gastronomy.dart';
import '../../favorites/presentation/providers/favorites_provider.dart';
import '../../places/presentation/widgets/video_player_viewer.dart';
import 'providers/gastronomy_provider.dart';

class GastronomyDetailScreen extends ConsumerStatefulWidget {
  const GastronomyDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<GastronomyDetailScreen> createState() =>
      _GastronomyDetailScreenState();
}

class _GastronomyDetailScreenState extends ConsumerState<GastronomyDetailScreen>
    with CollapsingScrollMixin {
  @override
  void initState() {
    super.initState();
    initScrollController();

    // `mobile_pending_changes.md` PR1 + mobile_analytics_todo.md §2.2 —
    // Lezzet (gastronomy/menu) detay açılış. menu için ayrı detail event'i
    // yok (whitelist dışı), generic content_tapped ile gönderiyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).track(
        AnalyticsEvents.contentTapped,
        properties: {
          'entity_type': 'menu',
          'entity_id': widget.id,
          'source': AnalyticsSource.list,
        },
      );
    });
  }

  @override
  void dispose() {
    disposeScrollController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBgColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.9);
    final buttonIconColor = isDark ? Colors.white : Colors.black87;

    final gastronomyAsync =
        ref.watch(gastronomyDetailProvider(widget.id));
    final isMenuFavorite = ref.watch(
      isFavoriteProvider((FavoriteEntityType.menu, widget.id)),
    );

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.popOrHome();
      },
      child: gastronomyAsync.when(
        loading: () => Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor:
                isDark ? AppColors.darkBackground : AppColors.lightBackground,
            title: Text(context.l10n.lblLocalDelicacy),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.delicacyLoadError,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
          ),
        ),
        data: (gastronomy) {
          if (gastronomy == null) {
            return Scaffold(
              backgroundColor: isDark
                  ? AppColors.darkBackground
                  : AppColors.lightBackground,
              appBar: AppBar(
                backgroundColor: isDark
                    ? AppColors.darkBackground
                    : AppColors.lightBackground,
                title: Text(context.l10n.lblLocalDelicacy),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.delicacyNotFound,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: isDark
                ? AppColors.darkBackground
                : AppColors.lightBackground,
            body: CustomScrollView(
              controller: scrollController,
              slivers: [
                _buildSliverAppBar(
                  context,
                  isDark: isDark,
                  buttonBgColor: buttonBgColor,
                  buttonIconColor: buttonIconColor,
                  gastronomy: gastronomy,
                  isFavorite: isMenuFavorite,
                  onToggleFavorite: () {
                    ref.read(favoritesProvider.notifier).toggleFavorite(
                          FavoriteEntityType.menu,
                          widget.id,
                        );
                  },
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 16),
                      _buildAboutSection(context, gastronomy),
                      const SizedBox(height: 24),
                      _buildRestaurantsSection(
                          context, gastronomy.relatedPlaces),
                      const SizedBox(height: 24),
                      _buildMapButton(context, gastronomy.relatedPlaces),
                      SizedBox(height: AppNavBar.bottomPadding + 80),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
    BuildContext context, {
    required bool isDark,
    required Color buttonBgColor,
    required Color buttonIconColor,
    required Gastronomy gastronomy,
    required bool isFavorite,
    required VoidCallback onToggleFavorite,
  }) {
    final hasNetworkImage = gastronomy.imageUrl != null &&
        (gastronomy.imageUrl!.startsWith('http://') ||
            gastronomy.imageUrl!.startsWith('https://'));
    final hasVideo = gastronomy.videoUrl != null &&
        gastronomy.videoUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      title: buildCollapsingTitle(
        context,
        title: gastronomy.name.isNotEmpty ? gastronomy.name : context.l10n.delicacyDetail,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (hasNetworkImage)
              Image.network(
                gastronomy.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildImageFallback(isDark),
              )
            else
              Image.asset(
                'assets/images/food-kebab.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildImageFallback(isDark),
              ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppGradients.heroOverlayDark
                    : const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black87,
                          Colors.transparent,
                        ],
                      ),
              ),
            ),
            // Title and Video Button
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: buildFlexibleContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Video Button
                    if (hasVideo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildVideoButton(context, gastronomy.videoUrl!),
                      ),
                    // Badge
                    _badge(
                      context,
                      label: context.l10n.lblLocalDelicacy,
                      color: isDark ? AppColors.neonOrange : Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      gastronomy.name,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: CircularIconButton(
          icon: Icons.arrow_back,
          backgroundColor: buttonBgColor,
          iconColor: buttonIconColor,
          // Bildirim derin bağlantısıyla açıldığında yığında üst sayfa
          // olmayabilir; pop yerine güvenli geri kullan.
          onPressed: () => context.popOrHome(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: CircularIconButton(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            backgroundColor: buttonBgColor,
            iconColor: isFavorite
                ? (isDark
                    ? AppColors.neonPink
                    : Theme.of(context).colorScheme.error)
                : (isDark ? AppColors.neonPink : null),
            onPressed: onToggleFavorite,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoButton(BuildContext context, String videoUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _openInternalVideoPlayer(context, videoUrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withAlpha(20)
              : Colors.black.withAlpha(60),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withAlpha(40),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_arrow,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.tapToWatchVideo,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInternalVideoPlayer(BuildContext context, String url) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => VideoPlayerViewer(videoUrl: url),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context, Gastronomy gastronomy) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: 20,
              color: isDark ? AppColors.neonOrange : AppColors.accentFood,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.menuAbout,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : null,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: isDark
                ? Border.all(color: Colors.white.withAlpha(15))
                : null,
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : AppElevation.level1,
          ),
          child: Text(
            gastronomy.description ?? context.l10n.delicacyNoDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? Colors.white.withAlpha(200)
                      : Theme.of(context).hintColor,
                  height: 1.6,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantsSection(
      BuildContext context, List<RelatedPlace> places) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (places.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 20,
                color: isDark ? AppColors.neonOrange : AppColors.accentFood,
              ),
              const SizedBox(width: 8),
              Text(
                'Burada yiyebilirsiniz',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : null,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: isDark
                  ? Border.all(color: Colors.white.withAlpha(15))
                  : null,
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(60),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : AppElevation.level1,
            ),
            child: Text(
              context.l10n.delicacyRestaurantsSoon,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? Colors.white.withAlpha(200)
                        : Theme.of(context).hintColor,
                  ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: 20,
              color: isDark ? AppColors.neonOrange : AppColors.accentFood,
            ),
            const SizedBox(width: 8),
            Text(
              'Burada yiyebilirsiniz',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : null,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: places.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final place = places[index];
            return _buildPlaceCard(context, place);
          },
        ),
      ],
    );
  }

  Widget _buildPlaceCard(BuildContext context, RelatedPlace place) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasNetworkImage = place.imageUrl != null &&
        (place.imageUrl!.startsWith('http://') ||
            place.imageUrl!.startsWith('https://'));

    return GestureDetector(
      onTap: () => context.push('/places/${place.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: isDark
              ? Border.all(color: Colors.white.withAlpha(15))
              : null,
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppElevation.level1,
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: hasNetworkImage
                  ? Image.network(
                      place.imageUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceImageFallback(isDark),
                    )
                  : _buildPlaceImageFallback(isDark),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : null,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (place.district != null)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: isDark
                              ? Colors.white.withAlpha(150)
                              : Theme.of(context).hintColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          place.district!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? Colors.white.withAlpha(150)
                                    : Theme.of(context).hintColor,
                              ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right,
              size: 24,
              color: isDark ? Colors.white.withAlpha(100) : Theme.of(context).hintColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton(BuildContext context, List<RelatedPlace> places) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (places.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.neonOrange.withAlpha(40),
                  AppColors.neonOrange.withAlpha(20),
                ]
              : [
                  Colors.orange.withAlpha(30),
                  Colors.orange.withAlpha(15),
                ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? AppColors.neonOrange.withAlpha(50)
              : Colors.orange.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.delicacyRestaurantsOnMap,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : null,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.delicacyShowPointsOnMap,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white.withAlpha(150)
                            : Theme.of(context).hintColor,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/map', extra: {
                'places': places.map((p) => p.id).toList(),
                'title': 'Restoranlar',
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? AppColors.neonOrange : Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.navigation_outlined, size: 18),
            label: Text(
              context.l10n.btnShowOnMap,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(230),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildImageFallback(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurfaceElevated : Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 64,
          color: isDark ? AppColors.neonOrange.withAlpha(100) : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildPlaceImageFallback(bool isDark) {
    return Container(
      width: 72,
      height: 72,
      color: isDark ? AppColors.darkSurfaceElevated : Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.storefront_outlined,
          size: 28,
          color: isDark ? AppColors.neonOrange.withAlpha(100) : Colors.grey,
        ),
      ),
    );
  }
}
