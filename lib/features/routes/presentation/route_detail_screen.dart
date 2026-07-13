import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/navigation_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../core/services/analytics_events.dart';
import '../../../../core/services/analytics_service.dart';
import '../../profile/presentation/providers/user_activity_provider.dart';
import '../../../../core/widgets/circular_icon_button.dart';
import '../../../../core/mixins/collapsing_scroll_mixin.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/services/discovery_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../../api/api.dart';
import '../../../../data/models/favorite.dart';
import '../../../../data/models/models.dart' as data_models;
import '../../favorites/presentation/providers/favorites_provider.dart';
import '../../../../core/services/point_collection_service.dart';
import '../../../../core/services/route_id_resolver.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/presentation/providers/point_collection_provider.dart';
import '../../campaigns/presentation/providers/campaigns_provider.dart';
import '../../campaigns/presentation/models/campaign.dart';
import 'providers/routes_provider.dart';
import 'providers/route_gamification_provider.dart';
import 'models/route_data.dart';
import '../../places/presentation/widgets/photo_gallery_viewer.dart';
import 'widgets/widgets.dart';
import '../../map/presentation/providers/route_navigation_provider.dart';
import '../../map/presentation/providers/route_places_on_route_only_intent_provider.dart';

class RouteDetailScreen extends ConsumerStatefulWidget {
  const RouteDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen>
    with CollapsingScrollMixin {
  bool _routeProximityStarted = false;
  final Set<String> _shownRouteCompletionDialogs = <String>{};
  final Set<String> _activeRouteStopPlaceIds = <String>{};

  /// Mobile (profil paneli) route ID — proximity check ve visit endpoint'leri
  /// bu ID'yi bekler. widget.id CMS ID'si olabilir; resolver ile çevrilir.
  int? _mobileRouteIdInt;

  // Riverpod 3.x: ref.read() dispose'da kullanılamaz, initState'te kaydet
  late final DiscoveryService _discoveryService;
  late final PointCollectionNotifier _pointCollectionNotifier;

  @override
  void initState() {
    super.initState();
    initScrollController();
    _discoveryService = ref.read(discoveryServiceProvider);
    _pointCollectionNotifier = ref.read(pointCollectionProvider.notifier);

    // mobile_analytics_todo.md §2.2 — route_detail_opened
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvents.routeDetailOpened,
      properties: {
        'route_id': widget.id,
        'source': AnalyticsSource.list,
      },
    );
  }

  @override
  void didUpdateWidget(RouteDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      final resolver = ref.read(routeIdResolverProvider.notifier);
      final oldMobile =
          resolver.resolveForRoutePath(oldWidget.id).gamificationId;
      final oldRouteId = int.tryParse(oldMobile);
      if (oldRouteId != null && _activeRouteStopPlaceIds.isNotEmpty) {
        for (final placeId in _activeRouteStopPlaceIds) {
          _pointCollectionNotifier.stopRouteStopProximityCheck(
            routeId: oldRouteId,
            placeId: placeId,
          );
        }
      }
      _routeProximityStarted = false;
      _shownRouteCompletionDialogs.clear();
      _activeRouteStopPlaceIds.clear();
    }
  }

  @override
  void dispose() {
    _discoveryService.cancelPending();

    if (_mobileRouteIdInt != null && _activeRouteStopPlaceIds.isNotEmpty) {
      for (final placeId in _activeRouteStopPlaceIds) {
        _pointCollectionNotifier.stopRouteStopProximityCheck(
          routeId: _mobileRouteIdInt!,
          placeId: placeId,
        );
      }
      _activeRouteStopPlaceIds.clear();
    }

    disposeScrollController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hesap değişince (login/logout) user-specific visited/proximity state'ini sıfırla.
    // Riverpod: ref.listen yalnızca build sırasında kullanılabilir.
    ref.listen<AuthState>(authProvider, (prev, next) {
      final prevUserId = prev?.user?.id;
      final nextUserId = next.user?.id;
      if (prev?.status != next.status || prevUserId != nextUserId) {
        _routeProximityStarted = false;
        _shownRouteCompletionDialogs.clear();
        ref.read(routeGamificationCacheProvider.notifier).remove(widget.id);
        ref.invalidate(routeDetailProvider(widget.id));
      }
    });

    // Rota tamamlanınca (son durak) MVP dialog: yalnızca bir kez göster.
    // UI'ı await/async'e zorlamadan, state transition üzerinden yakalar.
    ref.listen<Map<String, PointCollectionState>>(
      pointCollectionProvider,
      (prev, next) {
        if (!mounted) return;

        for (final entry in next.entries) {
          final key = entry.key;
          final state = entry.value;
          final result = state.routeVisitResult;
          if (state.status != PointCollectionStatus.collected) continue;
          if (result?.routeCompleted != true) continue;
          if (_shownRouteCompletionDialogs.contains(key)) continue;

          _shownRouteCompletionDialogs.add(key);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final safe = result;
            if (safe == null) return;
            final completionBonus = safe.completionBonus ?? 0;
            final allStopsBonus = safe.allStopsBonus ?? 0;
            final earned = completionBonus + allStopsBonus;

            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Theme.of(ctx).colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: Theme.of(ctx).colorScheme.outlineVariant.withAlpha(
                          Theme.of(ctx).brightness == Brightness.dark ? 110 : 90,
                        ),
                  ),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? AppColors.neonOrange
                          : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.l10n.routeCompleted)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (earned > 0) ...[
                      Text(
                        context.l10n.routeBonusPoints(earned),
                        style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? AppColors.neonOrange
                                  : Colors.orange,
                            ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (completionBonus > 0)
                      Text(context.l10n.routeCompletionBonus(completionBonus)),
                    if (allStopsBonus > 0)
                      Text(context.l10n.routeAllStopsBonus(allStopsBonus)),
                    if ((safe.message ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(safe.message!),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(context.l10n.btnClose),
                  ),
                ],
              ),
            );
          });
        }
      },
    );

    // widget.id CMS ID'si veya mobile ID olabilir; resolver ile mobile ID'ye çevir.
    ref.watch(routeIdResolverProvider);
    final mobileIdStr = ref
        .read(routeIdResolverProvider.notifier)
        .resolveForRoutePath(widget.id)
        .gamificationId;
    _mobileRouteIdInt = int.tryParse(mobileIdStr);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBgColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.9);
    final buttonIconColor = isDark ? Colors.white : Colors.black87;
    
    final routeAsync = ref.watch(routeDetailProvider(widget.id));
    // Gamification data is cached by routeDetailProvider — no extra API call
    final gamification = ref.watch(routeGamificationProvider(widget.id));

    // Rota / gamification verisi gecikmeli geldiğinde ilk build'de
    // _routeProximityStarted=true kalmış olabiliyor → durak proximity hiç başlamıyordu.
    ref.listen<AsyncValue<data_models.Route?>>(
      routeDetailProvider(widget.id),
      (prev, next) {
        if (!mounted) return;
        if (next.hasValue && (prev == null || !prev.hasValue)) {
          setState(() => _routeProximityStarted = false);
        }
      },
    );
    ref.listen<Map<String, dynamic>?>(
      routeGamificationProvider(widget.id),
      (prev, next) {
        if (!mounted) return;
        if (next != null && prev == null) {
          setState(() => _routeProximityStarted = false);
        }
      },
    );

    const config = ApiConfig.prod;
    final baseUrl = config.baseUrl;

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.popOrHome();
      },
      child: Scaffold(
        body: routeAsync.when(
          data: (route) {
            if (route == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.route_outlined,
                      size: 64,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.errRouteNotFound,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text(context.l10n.btnGoBack),
                    ),
                  ],
                ),
              );
            }

            return _buildRouteContent(
              context,
              route,
              gamification,
              isDark,
              buttonBgColor,
              buttonIconColor,
              baseUrl,
            );
          },
          loading: () => _buildLoadingState(
            context,
            isDark,
            buttonBgColor,
            buttonIconColor,
          ),
          error: (error, stack) => _buildErrorState(
            context,
            error,
            isDark,
            buttonBgColor,
            buttonIconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildRouteContent(
    BuildContext context,
    data_models.Route route,
    Map<String, dynamic>? gamification,
    bool isDark,
    Color buttonBgColor,
    Color buttonIconColor,
    String baseUrl,
  ) {
    // Detay sayfası için her zaman orijinal kapak görselini kullan
    // API base URL /api/v1 içeriyor, site URL için bunu kaldır
    final siteBaseUrl = baseUrl.replaceAll('/api/v1', '');
    final heroImagePath = route.cover ?? route.coverUrl;
    final imageUrl = buildImageUrl(heroImagePath, baseUrl: siteBaseUrl);
    final heroTag = 'route-cover-${route.id}';
    final isRouteFavorite = ref.watch(
      isFavoriteProvider((FavoriteEntityType.route, route.id)),
    );
    
    // Mesafe formatı
    final distanceText = route.distanceKm != null
        ? route.distanceKm!.toStringAsFixed(1)
        : '-';
    
    // Süre formatı (dakika -> saat)
    String durationText = '-';
    if (route.durationMinutes != null) {
      final hours = route.durationMinutes! ~/ 60;
      final minutes = route.durationMinutes! % 60;
      if (hours > 0) {
        durationText = minutes > 0 ? '$hours.${minutes ~/ 10} saat' : '$hours saat';
      } else {
        durationText = '$minutes dk';
      }
    }
    
    // Zorluk seviyesi
    final difficulty = route.difficultyLevel ?? '-';
    
    // Toplam kazanılabilir puan (tüm duraklar + completion + bonus)
    // Öncelik: RoutesProvider'dan gelen TourRoute.points (auth backend listesi),
    // yoksa city backend'deki totalPossiblePoints.
    final routesState = ref.read(routesProvider);
    final matchedTourRoute = routesState.routes
        .where((r) => r.id == route.id || r.id == route.id.toString())
        .cast<TourRoute?>()
        .firstWhere((r) => r != null, orElse: () => null);

    final totalPoints = (matchedTourRoute?.points != null &&
            matchedTourRoute!.points != 0)
        ? matchedTourRoute.points
        : (route.totalPossiblePoints ?? 0);
    
    // Places listesi - order'a göre sırala
    final sortedPlaces = List<data_models.RoutePlace>.from(route.places)
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    // Auth backend'ten gelen durak gamification datası (stop_points, visited)
    final stopsJson = (gamification?['stops'] as List?) ?? const [];
    final Map<String, Map<String, dynamic>> stopsByPlaceId = {
      for (final s in stopsJson.whereType<Map<String, dynamic>>())
        if (s['id'] != null) s['id'].toString(): s,
    };

    if (kDebugMode) {
      debugPrint(
        '🗺️ [RouteDetail] widget.id=${widget.id}, mobileRouteId=$_mobileRouteIdInt, '
        'gamification=${gamification != null ? 'loaded' : 'null'}, '
        'stops=${stopsJson.length}, stopsByPlaceId=${stopsByPlaceId.length}, '
        'totalPoints=$totalPoints',
      );
    }

    // Campaigns endpoint'inden (token ile) route progress fallback:
    // progress.visited_place_ids ile "visited" tespiti yapabiliriz.
    final campaignsState = ref.watch(campaignsProvider);
    final routeIdInt = _mobileRouteIdInt;
    final Campaign? routeCampaign = routeIdInt == null
        ? null
        : [
            ...campaignsState.activeCampaigns,
            ...campaignsState.completedCampaigns,
          ].cast<Campaign?>().firstWhere(
            (c) => c != null && c.isRoute && c.id == routeIdInt.toString(),
            orElse: () => null,
          );
    final visitedFromCampaign = routeCampaign?.visitedPlaceIds.toSet() ?? <String>{};

    final completedStops = sortedPlaces.where((place) {
      final stop = stopsByPlaceId[place.id];
      // Ziyaret bilgisi kullanıcıya özeldir; CMS'teki `place.visited` güvenilmez.
      return (stop?['visited'] == true) || visitedFromCampaign.contains(place.id);
    }).length;

    final isAuthenticated =
        ref.watch(authProvider.select((s) => s.status == AuthStatus.authenticated));

    // Proximity timer sadece auth'lu kullanıcılar için (puan toplama auth gerektirir)
    if (!_routeProximityStarted && routeIdInt != null && isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = ref.read(pointCollectionProvider.notifier);
        for (final place in sortedPlaces) {
          final stopJson = stopsByPlaceId[place.id];
          final effectivePoints =
              (stopJson?['stop_points'] as int?) ?? place.stopPoints;
          final visited =
              (stopJson?['visited'] == true) || visitedFromCampaign.contains(place.id);

          if (effectivePoints == null || effectivePoints == 0) continue;

          _activeRouteStopPlaceIds.add(place.id);
          notifier.startRouteStopProximityCheck(
            routeId: routeIdInt,
            stop: data_models.RoutePlace(
              id: place.id,
              name: place.name,
              imageUrl: place.imageUrl,
              lat: place.lat,
              lng: place.lng,
              stopPoints: effectivePoints,
              visited: visited,
              order: place.order,
            ),
          );
        }
        // Tüm duraklar 0 puandıysa bile true yap; yoksa her frame yeni postFrameCallback
        // tetiklenir. Gamification sonradan gelince listener _routeProximityStarted sıfırlar.
        if (mounted) {
          setState(() => _routeProximityStarted = true);
        }
      });
    }

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          title: buildCollapsingTitle(
            context,
            title: route.name,
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (imageUrl == null) return;

                // Orijinal kapak (cover) varsa onu, yoksa mevcut hero görselini aç
                final fullImageUrl = buildImageUrl(
                  route.cover ?? route.coverUrl,
                  baseUrl: siteBaseUrl,
                ) ?? imageUrl;

                Navigator.of(context, rootNavigator: true).push(
                  PageRouteBuilder(
                    opaque: true,
                    barrierDismissible: false,
                    transitionDuration: const Duration(milliseconds: 220),
                    reverseTransitionDuration: const Duration(milliseconds: 200),
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        PhotoGalleryViewer(
                      photoUrls: [fullImageUrl],
                      initialIndex: 0,
                      heroTag: heroTag,
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      final fade = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      // Hafif üstten giriş (sağdan slide yerine)
                      final slide = Tween<Offset>(
                        begin: const Offset(0, -0.06),
                        end: Offset.zero,
                      ).animate(fade);
                      return FadeTransition(
                        opacity: fade,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? Hero(
                          tag: heroTag,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SkeletonLoader(
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius: BorderRadius.zero,
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: isDark
                                  ? AppColors.darkSurface
                                  : Colors.grey[200],
                              child: Icon(
                                Icons.route,
                                size: 64,
                                color: isDark
                                    ? AppColors.neonBlue.withAlpha(100)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: isDark
                              ? AppColors.darkSurface
                              : Colors.grey[200],
                          child: Icon(
                            Icons.route,
                            size: 64,
                            color: isDark
                                ? AppColors.neonBlue.withAlpha(100)
                                : Colors.grey,
                          ),
                        ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black87,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Badge'ler ve başlık
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: buildFlexibleContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (difficulty != '-')
                                _badge(
                                  context,
                                  difficulty,
                                  _getDifficultyColor(difficulty, isDark),
                                ),
                              // Points/gamification feature flag — puan rozeti.
                              if (FeatureFlags.pointsEnabled &&
                                  difficulty != '-' &&
                                  totalPoints > 0)
                                const SizedBox(width: 8),
                              if (FeatureFlags.pointsEnabled && totalPoints > 0)
                                _badge(
                                  context,
                                  '+$totalPoints Puan',
                                  Colors.orange,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            route.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
          ),
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircularIconButton(
              icon: Icons.arrow_back,
              backgroundColor: buttonBgColor,
              iconColor: buttonIconColor,
              onPressed: () => context.pop(),
            ),
          ),
          actions: [
            // "Bu rotayı tamamladım" — local sayaç. Puan sistemi açıkken
            // ek olarak `mobile/routes/progress` API'sine yansır.
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Consumer(
                builder: (context, ref, _) {
                  final isDone = ref.watch(
                    userActivityProvider
                        .select((s) => s.isRouteCompleted(route.id)),
                  );
                  return CircularIconButton(
                    icon: isDone
                        ? Icons.task_alt_rounded
                        : Icons.check_circle_outline_rounded,
                    backgroundColor: buttonBgColor,
                    iconColor: isDone
                        ? Theme.of(context).colorScheme.primary
                        : buttonIconColor,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final added = await ref
                          .read(userActivityProvider.notifier)
                          .toggleRouteCompleted(route.id);
                      if (!context.mounted) return;
                      messenger.removeCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            added
                                ? context.l10n.routeMarkedCompleted
                                : context.l10n.routeUnmarkedCompleted,
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircularIconButton(
                icon: isRouteFavorite ? Icons.favorite : Icons.favorite_border,
                backgroundColor: buttonBgColor,
                iconColor: isRouteFavorite
                    ? (isDark
                        ? AppColors.neonPink
                        : Theme.of(context).colorScheme.error)
                    : buttonIconColor,
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggleFavorite(
                        FavoriteEntityType.route,
                        route.id,
                      );
                },
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              _buildQuickStats(
                context,
                distanceText,
                durationText,
                difficulty,
              ),
              const SizedBox(height: 24),
              _buildDescription(context, route.description),
              const SizedBox(height: 24),
              _buildRouteHighlights(context, sortedPlaces.length),
              const SizedBox(height: 24),
              _buildRouteStops(
                context,
                sortedPlaces,
                baseUrl,
                stopsByPlaceId,
                visitedFromCampaign,
                routeIdInt,
                isAuthenticated,
              ),
              const SizedBox(height: 24),
              _buildProgress(
                context,
                sortedPlaces.length,
                completedStops,
                totalPoints,
              ),
              const SizedBox(height: 24),
              _buildActionButtons(context, route, sortedPlaces),
              SizedBox(height: AppNavBar.bottomPadding + 80),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(
    BuildContext context,
    bool isDark,
    Color buttonBgColor,
    Color buttonIconColor,
  ) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          title: buildCollapsingTitle(
            context,
            title: context.l10n.loadingMessage,
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                SkeletonLoader(
                  width: double.infinity,
                  height: double.infinity,
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.transparent,
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
              onPressed: () => context.pop(),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              SkeletonLoader(
                width: double.infinity,
                height: 80,
                borderRadius: BorderRadius.circular(18),
              ),
              const SizedBox(height: 24),
              SkeletonLoader(
                width: double.infinity,
                height: 100,
                borderRadius: BorderRadius.circular(12),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    Object error,
    bool isDark,
    Color buttonBgColor,
    Color buttonIconColor,
  ) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverAppBar(
          pinned: true,
          title: buildCollapsingTitle(
            context,
            title: context.l10n.errGenericTitle,
          ),
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircularIconButton(
              icon: Icons.arrow_back,
              backgroundColor: buttonBgColor,
              iconColor: buttonIconColor,
              onPressed: () => context.pop(),
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.errRouteLoadFailed,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(routeDetailProvider(widget.id));
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.btnRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    String distance,
    String duration,
    String difficulty,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(
            context,
            icon: Icons.directions_walk,
            iconColor: Theme.of(context).colorScheme.primary,
            title: distance,
            subtitle: 'km',
            trailingSmall: 'Mesafe',
          ),
          _divider(context),
          _statItem(
            context,
            icon: Icons.access_time,
            iconColor: Theme.of(context).colorScheme.secondary,
            title: duration.split(' ')[0],
            subtitle: duration.contains('saat') ? 'saat' : 'dk',
            trailingSmall: context.l10n.lblDuration,
          ),
          _divider(context),
          _statItem(
            context,
            icon: Icons.trending_up,
            iconColor: _getDifficultyColor(difficulty, Theme.of(context).brightness == Brightness.dark),
            title: difficulty,
            subtitle: 'Zorluk',
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? trailingSmall,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (trailingSmall != null) ...[
              const SizedBox(width: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          trailingSmall ?? subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Theme.of(context).dividerColor.withAlpha(102),
    );
  }

  Widget _buildDescription(BuildContext context, String? description) {
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.titleRouteAbout,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
                height: 1.6,
              ),
        ),
      ],
    );
  }

  Widget _buildRouteHighlights(BuildContext context, int stopsCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.titleRouteFeatures,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (context, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final highlights = [
                {
                  'icon': Icons.camera_alt_outlined,
                  'label': context.l10n.lblPhotoSpots,
                  'color': Theme.of(context).colorScheme.primary
                },
                {
                  'icon': Icons.local_cafe_outlined,
                  'label': context.l10n.lblRestAreas,
                  'color': Theme.of(context).colorScheme.secondary
                },
                {
                  'icon': Icons.place_outlined,
                  'label': '$stopsCount Durak',
                  'color': Colors.green
                },
              ];
              final highlight = highlights[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: (highlight['color'] as Color).withAlpha(26),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      highlight['icon'] as IconData,
                      size: 16,
                      color: highlight['color'] as Color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      highlight['label'] as String,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRouteStops(
    BuildContext context,
    List<data_models.RoutePlace> places,
    String baseUrl,
    Map<String, Map<String, dynamic>> stopsByPlaceId,
    Set<String> visitedFromCampaign,
    int? routeId,
    bool isAuthenticated,
  ) {
    if (places.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.titleRouteStops,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            for (int i = 0; i < places.length; i++)
              Builder(builder: (context) {
                final place = places[i];
                final stopJson = stopsByPlaceId[place.id];
                final key = routeId != null ? '$routeId:${place.id}' : null;
                final allStates = ref.watch(pointCollectionProvider);
                final state =
                    key != null ? (allStates[key] ?? const PointCollectionState()) : const PointCollectionState();

                return RouteStopCard(
                  index: i,
                  place: place,
                  routeId: routeId,
                  baseUrl: baseUrl,
                  stopJson: stopJson,
                  visitedFromCampaign: visitedFromCampaign,
                  collectionState: state,
                  isAuthenticated: isAuthenticated,
                  onCollect: () {
                    final authState = ref.read(authProvider);
                    if (authState.status != AuthStatus.authenticated) {
                      context.push('/login');
                      return;
                    }
                    if (routeId == null) return;
                    ref.read(pointCollectionProvider.notifier).collectRouteStop(
                          routeId: routeId,
                          placeId: place.id,
                        );
                  },
                );
              }),
          ],
        ),
      ],
    );
  }

  Widget _buildProgress(
    BuildContext context,
    int totalStops,
    int completedStops,
    int totalPoints,
  ) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.routeYourProgress,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tamamlanan',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                  Text(
                    '$completedStops / $totalStops durak',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: totalStops > 0 ? completedStops / totalStops : 0,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
              ),
              // Points/gamification feature flag — kazanım bilgisi metni.
              if (FeatureFlags.pointsEnabled && totalPoints > 0) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.routeEarnPointsHint(totalPoints),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    data_models.Route route,
    List<data_models.RoutePlace> sortedPlaces,
  ) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              final routePlacesWithCoords = sortedPlaces
                  .where((p) => p.lat != null && p.lng != null)
                  .toList();

              final routePlaceIds = routePlacesWithCoords
                  .map((p) => p.id)
                  .toSet();

              final routePoints = routePlacesWithCoords
                  .map((p) => LatLng(p.lat!, p.lng!))
                  .toList();

              // MapScreen'e "bu rota duraklarını göster (polyline yok)" isteğini aktar.
              // Önce map'teki olası eski polylineları temizleyelim.
              ref.read(routeNavigationProvider.notifier).clearRoute();
              ref.read(routePlacesOnRouteOnlyIntentProvider.notifier).set(
                    placeIds: routePlaceIds,
                    routeTitle: route.name,
                  );

              if (routePoints.isEmpty) {
                // Koordinat bulunamazsa filtreli açmanın anlamı olmaz.
                ref
                    .read(routePlacesOnRouteOnlyIntentProvider.notifier)
                    .clear();
                context.push('/map');
                return;
              }

              context.push('/map');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.map_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.l10n.routeView,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getDifficultyColor(String difficulty, bool isDark) {
    final lower = difficulty.toLowerCase();
    if (lower.contains('kolay') || lower.contains('easy')) {
      return isDark ? AppColors.neonCyan : Colors.green;
    } else if (lower.contains('orta') || lower.contains('medium')) {
      return isDark ? AppColors.neonOrange : Colors.orange;
    } else if (lower.contains('zor') || lower.contains('hard')) {
      return isDark ? AppColors.neonPink : Colors.red;
    }
    return Colors.grey;
  }

  Widget _badge(BuildContext context, String label, Color color) {
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
}
