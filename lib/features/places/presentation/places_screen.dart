import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../l10n/l10n.dart';
import '../../../data/models/models.dart';
import '../../../api/api.dart';
import '../../favorites/presentation/providers/favorites_provider.dart';
import 'providers/places_provider.dart';
import 'providers/place_detail_provider.dart';
import 'places_category_display.dart';

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({
    super.key,
    this.initialCategorySlug,
    this.initialSearchQuery,
  });

  /// Örn. `health_tourism` — `/places?category=health_tourism`
  final String? initialCategorySlug;

  /// `/places?q=...` (ana sayfa hero araması)
  final String? initialSearchQuery;

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showFloatingHeader = false;
  double _lastOffset = 0.0;
  bool _filterFavoritesOnly = false;

  /// Üst / yüzen başlıktaki kategori chip'leri ayrı ağaçta; aynı GlobalKey iki kez kullanılamaz.
  final Map<String, GlobalKey> _categoryChipKeysMain = {};
  final Map<String, GlobalKey> _categoryChipKeysFloating = {};
  /// Arama çubuğundaki sıralama butonuna ankraj (yalnız ana header'da).
  final GlobalKey _sortKey = GlobalKey();

  // Header'ın görünmesi için gereken scroll offset
  static const double _scrollThreshold = 120.0;

  GlobalKey _mainChipKey(String categoryId) =>
      _categoryChipKeysMain.putIfAbsent(categoryId, GlobalKey.new);

  GlobalKey _floatingChipKey(String categoryId) =>
      _categoryChipKeysFloating.putIfAbsent(categoryId, GlobalKey.new);

  void _scrollActiveCategoryChipIntoView(String categoryId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _showFloatingHeader
          ? _categoryChipKeysFloating[categoryId]
          : _categoryChipKeysMain[categoryId];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.35,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    // Sayfa açıldığında:
    // - Arama sorgusunu temizle
    // - Cached place'ler varsa sadece mesafeleri güncelle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(placesProvider.notifier).clearSearch();
        _searchController.clear();
        ref
            .read(placesProvider.notifier)
            .applyRouteCategorySlug(widget.initialCategorySlug);
        final initialQ = widget.initialSearchQuery?.trim();
        if (initialQ != null && initialQ.isNotEmpty) {
          ref.read(placesProvider.notifier).search(initialQ);
          if (_searchController.text != initialQ) {
            _searchController.text = initialQ;
          }
        }
        // API'den tüm listeyi yeniden çekmeden, sadece distance değerlerini
        // güncel konuma göre yeniden hesapla. Böylece sayfaya her girişte
        // mesafeler taze olur.
        ref.read(placesProvider.notifier).recalculateDistances();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlacesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategorySlug != widget.initialCategorySlug ||
        oldWidget.initialSearchQuery != widget.initialSearchQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(placesProvider.notifier)
            .applyRouteCategorySlug(widget.initialCategorySlug);
        final q = widget.initialSearchQuery?.trim();
        if (q != null && q.isNotEmpty) {
          ref.read(placesProvider.notifier).search(q);
          if (_searchController.text != q) {
            _searchController.text = q;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchAnalyticsDebounce?.cancel();
    super.dispose();
  }

  Timer? _searchAnalyticsDebounce;

  void _onSearchChanged() {
    final query = _searchController.text;
    final currentQuery = ref.read(placesProvider).searchQuery;
    // Sadece değer gerçekten değiştiyse güncelle (sonsuz döngüyü önle)
    if (query != currentQuery) {
      ref.read(placesProvider.notifier).search(query);
    }
    // mobile_analytics_todo.md §2.6 — search_submitted (live-search debounce 800ms).
    // Tek karakterlik gürültüyü engellemek için trimmed ≥2 ise gönder.
    _searchAnalyticsDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) return;
    _searchAnalyticsDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final state = ref.read(placesProvider);
      ref.read(analyticsServiceProvider).track(
        AnalyticsEvents.searchSubmitted,
        properties: {
          'query': trimmed,
          'scope': 'places',
          'result_count': state.filteredPlaces.length,
        },
      );
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final isScrollingDown = offset > _lastOffset;

    bool shouldShow = _showFloatingHeader;

    // En üstlere yakınken her zaman gizli kalsın
    if (offset <= _scrollThreshold) {
      shouldShow = false;
    } else {
      if (isScrollingDown) {
        // Aşağı kaydırırken gizle
        shouldShow = false;
      } else {
        // Yukarı kaydırırken (ve yeterince aşağı inilmişse) göster
        shouldShow = true;
      }
    }

    if (shouldShow != _showFloatingHeader) {
      setState(() {
        _showFloatingHeader = shouldShow;
      });
    }

    _lastOffset = offset;
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      // Biraz daha yavaş animasyon
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placesState = ref.watch(placesProvider);
    final favState = ref.watch(favoritesProvider);
    final displayPlaces = _filterFavoritesOnly
        ? placesState.filteredPlaces
            .where((p) => favState.isFavorite(FavoriteEntityType.place, p.id))
            .toList()
        : placesState.filteredPlaces;

    // State değişikliklerini dinle ve controller'ı güncelle
    ref.listen<String>(placesProvider.select((state) => state.searchQuery), (previous, next) {
      // Sadece değer gerçekten değiştiyse güncelle (sonsuz döngüyü önle)
      if (_searchController.text != next) {
        _searchController.text = next;
      }
    });

    ref.listen<String>(
      placesProvider.select((state) => state.selectedCategory),
      (previous, next) {
        if (previous == next) return;
        _scrollActiveCategoryChipIntoView(next);
      },
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Ana içerik
          // ✅ PERFORMANCE: cacheExtent ile ekran dışındaki cardları önceden yükle
          // 130px card + 16px padding = ~146px per card
          // 5 card önceden yükle = ~730px (kaydırırken bekleme yok)
          CustomScrollView(
            controller: _scrollController,
            cacheExtent: 730, // ~5 card önceden yüklensin
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _PlacesHeader(
                  searchController: _searchController,
                  favoritesFilterActive: _filterFavoritesOnly,
                  categoryChipKeyBuilder: _mainChipKey,
                  sortMenuKey: _sortKey,
                  onFavoritesPressed: () {
                    setState(() {
                      _filterFavoritesOnly = !_filterFavoritesOnly;
                    });
                  },
                ),
              ),
              // Konum uyarı banner'ı
              if (placesState.locationStatus != LocationStatus.unknown &&
                  placesState.locationStatus != LocationStatus.available)
                SliverToBoxAdapter(
                  child: _LocationWarningBanner(
                    status: placesState.locationStatus,
                  ),
                ),
              // Content
              // Show skeleton only when loading AND no cached data exists
              if (placesState.isLoading && placesState.allPlaces.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _PlaceCardSkeleton(),
                      ),
                      childCount: 5, // 5 skeleton card göster
                    ),
                  ),
                )
              else if (placesState.error != null)
                SliverFillRemaining(
                  child: _PlacesError(error: placesState.error!),
                )
              else if (placesState.filteredPlaces.isEmpty)
                const SliverFillRemaining(
                  child: _PlacesEmpty(),
                )
              else if (displayPlaces.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.l10n.favPlacesEmptyOrNoMatch,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final place = displayPlaces[index];
                        return RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _PlaceCard(
                              place: place,
                              categories: placesState.categories,
                              isFavorite: favState.isFavorite(
                                FavoriteEntityType.place,
                                place.id,
                              ),
                              onFavoriteToggle: () {
                                ref
                                    .read(favoritesProvider.notifier)
                                    .toggleFavorite(
                                      FavoriteEntityType.place,
                                      place.id,
                                    );
                              },
                            ),
                          ),
                        );
                      },
                      childCount: displayPlaces.length,
                      // ✅ PERFORMANCE: Cardları bellekte tut (max ~300 card için sorun yok)
                      // cacheExtent ile birlikte çalışır - önceden yükle + bellekte tut
                      addAutomaticKeepAlives: true,
                      addRepaintBoundaries: false, // Kendimiz RepaintBoundary ekliyoruz
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppNavBar.bottomPadding),
              ),
            ],
          ),
          // Floating header (scroll olduğunda görünür)
          _FloatingSearchHeader(
            isVisible: _showFloatingHeader,
            onScrollToTop: _scrollToTop,
            searchController: _searchController,
            categoryChipKeyBuilder: _floatingChipKey,
          ),
        ],
      ),
    );
  }
}

class _PlacesHeader extends ConsumerWidget {
  const _PlacesHeader({
    required this.searchController,
    this.onFavoritesPressed,
    this.favoritesFilterActive = false,
    this.categoryChipKeyBuilder,
    this.sortMenuKey,
  });

  final TextEditingController searchController;
  final VoidCallback? onFavoritesPressed;
  final bool favoritesFilterActive;
  final GlobalKey Function(String categoryId)? categoryChipKeyBuilder;
  /// Arama çubuğundaki filtre butonuna ankrajlı sıralama menüsü için.
  final GlobalKey? sortMenuKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(placesProvider);
    final notifier = ref.read(placesProvider.notifier);

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.titlePlaces,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                            letterSpacing: -0.3,
                          ),
                    ),
                  ),
                  if (onFavoritesPressed != null)
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
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest),
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
                          favoritesFilterActive
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isDark
                              ? AppColors.neonPink
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onPressed: onFavoritesPressed,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Search bar
              AppSearchBar(
                hintText: context.l10n.lblSearchPlaces,
                showFilterButton: true,
                controller: searchController,
                onChanged: notifier.search,
                // §6.4.5 — sıralama artık arama yanındaki filtre butonunda.
                filterButtonKey: sortMenuKey,
                isFilterActive: state.sortMode != PlaceSortMode.recommended,
                onFilterTap: sortMenuKey == null
                    ? null
                    : () => showAppSortMenu<PlaceSortMode>(
                          context: context,
                          anchorKey: sortMenuKey!,
                          current: state.sortMode,
                          values: PlaceSortMode.values,
                          labelOf: (m) => placeSortLabel(context.l10n, m),
                          onSelected: notifier.setSortMode,
                        ),
              ),
              const SizedBox(height: 16),
              // Kategori pill'leri (sıralama yukarı, arama butonuna taşındı).
              SizedBox(
                height: 40,
                child: _buildCategoryPills(
                  context,
                  ref,
                  state,
                  notifier,
                  isDark,
                  categoryChipKeyBuilder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPills(
    BuildContext context,
    WidgetRef ref,
    PlacesState state,
    PlacesNotifier notifier,
    bool isDark,
    GlobalKey Function(String categoryId)? categoryChipKeyBuilder,
  ) {
    final categoriesToShow = state.filteredCategories.isNotEmpty 
        ? state.filteredCategories 
        : state.categories;
    
    // Loading durumunda ve kategoriler boşsa skeleton göster
    if (categoriesToShow.isEmpty) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (context, _) => SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => SkeletonLoader(
          width: 70,
          height: 36,
          borderRadius: BorderRadius.circular(18),
        ),
      );
    }
    
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: categoriesToShow.length,
      separatorBuilder: (context, _) => SizedBox(width: AppSpacing.sm),
      itemBuilder: (context, index) {
        final cat = categoriesToShow[index];
        Widget pill = CategoryPill(
          label: displayPlacesCategoryLabel(cat, context.l10n),
          iconString: cat.icon,
          isActive: state.selectedCategory == cat.id,
          onTap: () {
            // mobile_analytics_todo.md §2.6 — filter_applied
            ref.read(analyticsServiceProvider).track(
              AnalyticsEvents.filterApplied,
              properties: {'scope': 'places_category', 'value': cat.id},
            );
            notifier.setCategory(cat.id);
          },
        );
        if (categoryChipKeyBuilder != null) {
          pill = KeyedSubtree(
            key: categoryChipKeyBuilder(cat.id),
            child: pill,
          );
        }
        return pill;
      },
    );
  }
}

/// Floating header - Scroll olduğunda üstte sabit görünür
class _FloatingSearchHeader extends ConsumerWidget {
  const _FloatingSearchHeader({
    required this.isVisible,
    required this.onScrollToTop,
    required this.searchController,
    this.categoryChipKeyBuilder,
  });

  final bool isVisible;
  final VoidCallback onScrollToTop;
  final TextEditingController searchController;
  final GlobalKey Function(String categoryId)? categoryChipKeyBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(placesProvider);
    final notifier = ref.read(placesProvider.notifier);
    final topPadding = MediaQuery.of(context).padding.top;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      top: isVisible ? 0 : -180,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          boxShadow: isVisible
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 40 : 15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search bar with scroll to top button
              Row(
                children: [
                  Expanded(
                    child: AppSearchBar(
                      hintText: context.l10n.lblSearchPlaces,
                      showFilterButton: false,
                      controller: searchController,
                      onChanged: notifier.search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Scroll to top button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onScrollToTop,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: isDark
                              ? Border.all(color: Colors.white.withAlpha(15))
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 30 : 8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: isDark ? AppColors.neonBlue : AppColors.lightGradientStart,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Category pills - arama sonuçlarına göre filtrelenmiş kategoriler
              SizedBox(
                height: 36,
                child: () {
                  final categoriesToShow = state.filteredCategories.isNotEmpty 
                      ? state.filteredCategories 
                      : state.categories;
                  
                  // Loading durumunda ve kategoriler boşsa skeleton göster
                  if (categoriesToShow.isEmpty) {
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      separatorBuilder: (context, _) => SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) => SkeletonLoader(
                        width: 60,
                        height: 32,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    );
                  }
                  
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categoriesToShow.length,
                    separatorBuilder: (context, _) => SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final cat = categoriesToShow[index];
                      Widget pill = CategoryPill(
                        label: displayPlacesCategoryLabel(cat, context.l10n),
                        iconString: cat.icon,
                        isActive: state.selectedCategory == cat.id,
                        onTap: () {
            // mobile_analytics_todo.md §2.6 — filter_applied
            ref.read(analyticsServiceProvider).track(
              AnalyticsEvents.filterApplied,
              properties: {'scope': 'places_category', 'value': cat.id},
            );
            notifier.setCategory(cat.id);
          },
                      );
                      final kb = categoryChipKeyBuilder;
                      if (kb != null) {
                        pill = KeyedSubtree(
                          key: kb(cat.id),
                          child: pill,
                        );
                      }
                      return pill;
                    },
                  );
                }(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlacesError extends ConsumerWidget {
  const _PlacesError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: isDark ? Colors.red[300] : Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.errGenericTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(placesProvider.notifier).refresh(),
              child: Text(context.l10n.btnRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacesEmpty extends StatelessWidget {
  const _PlacesEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.place_outlined,
              size: 48,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.errNoPlaces,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.emptyTryDifferent,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends ConsumerWidget {
  const _PlaceCard({
    required this.place,
    required this.categories,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final Place place;
  final List<PlaceCategory> categories;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // API base URL'ini al (image URL'leri için)
    const config = ApiConfig.prod;
    final baseUrl = config.baseUrl;
    final imageUrl = buildImageUrl(place.imageUrl, baseUrl: baseUrl);
    
    // Distance'ı placeDistancesProvider'dan al (sadece BU place'in distance'ını izle)
    // .select() ile diğer place'lerin distance değişimleri bu kartı rebuild etmez
    final overrideDistance = ref.watch(
      placeDistancesProvider.select((distances) => distances[place.id]),
    );
    final placeWithDistance = overrideDistance != null 
        ? place.copyWith(distance: overrideDistance)
        : place;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // mobile_analytics_todo.md §2.4 / §2.6 — aktif search query varsa
          // search_result_tapped (position dahil), yoksa content_tapped.
          final analytics = ref.read(analyticsServiceProvider);
          final state = ref.read(placesProvider);
          final query = state.searchQuery.trim();
          if (query.length >= 2) {
            // Position = filteredPlaces içindeki index. O(n) ama liste küçük.
            final position = state.filteredPlaces
                .indexWhere((p) => p.id == place.id);
            analytics.track(
              AnalyticsEvents.searchResultTapped,
              properties: {
                'query': query,
                'entity_type': 'place',
                'entity_id': place.id,
                'position': position < 0 ? 0 : position,
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
          context.push('/places/${place.cmsContentId}');
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: isDark
            ? AppColors.neonBlue.withAlpha(30)
            : Theme.of(context).colorScheme.primary.withAlpha(30),
        child: Container(
          height: 130, // SABİT KART YÜKSEKLİĞİ
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sabit boyutlu görsel alanı - 130px yükseklik
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: imageUrl != null
                            ? CachedImage(
                                imageUrl: imageUrl,
                                width: 130,
                                height: 130,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: isDark
                                    ? AppColors.darkSurfaceElevated
                                    : Colors.grey[200],
                                child: Icon(
                                  Icons.place,
                                  color: isDark
                                      ? AppColors.neonBlue.withAlpha(100)
                                      : Colors.grey,
                                  size: 32,
                                ),
                              ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: isDark
                                ? AppColors.darkSurface.withAlpha(230)
                                : Colors.white.withAlpha(230),
                            shape: const CircleBorder(),
                          ),
                          onPressed: onFavoriteToggle,
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isFavorite
                                ? (isDark
                                    ? AppColors.neonPink
                                    : Theme.of(context).colorScheme.error)
                                : (isDark
                                    ? Colors.white.withAlpha(180)
                                    : Theme.of(context).hintColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER: Title + Category Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              place.name,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : null,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.neonPurple.withAlpha(30)
                                  : Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                              border: isDark
                                  ? Border.all(color: AppColors.neonPurple.withAlpha(60))
                                  : null,
                            ),
                            child: Text(
                              displayPlacesCategoryLabelForPlace(
                                place,
                                categories,
                                context.l10n,
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.neonPurple
                                    : Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // DESCRIPTION
                      Text(
                        place.description ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white.withAlpha(180) : null,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // FOOTER: Mesafe + Puan rozeti / ok
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (placeWithDistance.distance != null &&
                                    placeWithDistance.distance!.isNotEmpty) ...[
                                  Icon(
                                    Icons.near_me_outlined,
                                    size: 14,
                                    color: isDark
                                        ? AppColors.neonCyan
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    placeWithDistance.distance!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: isDark ? Colors.white.withAlpha(150) : null,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (place.points != null && place.points! > 0)
                            _PointsBadge(
                              place: place,
                              isDark: isDark,
                            ),
                          if (place.points == null || place.points == 0)
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: isDark ? AppColors.neonBlue : Theme.of(context).hintColor,
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
}

/// Mekan kartındaki puan rozeti — kampanya durumuna göre farklı görünüm.
/// Puan değerini her zaman gösterir; claimed/campaign durumunu ikon ile belirtir.
class _PointsBadge extends StatelessWidget {
  const _PointsBadge({
    required this.place,
    required this.isDark,
  });

  final Place place;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final campaign = place.campaign;
    // claimed alanı varsa ona bak; yoksa eski visited'a düş
    final isClaimed = place.claimed || place.visited;

    final Color badgeColor;
    final IconData badgeIcon;
    final String badgeText;

    if (campaign != null && campaign.isUpcoming) {
      badgeColor = isDark ? AppColors.neonBlue : Colors.blueGrey;
      badgeIcon = Icons.schedule_rounded;
      badgeText = '+${place.points}';
    } else if (campaign != null && campaign.isExpired) {
      badgeColor = Colors.grey;
      badgeIcon = Icons.event_busy_rounded;
      badgeText = '${place.points}';
    } else if (isClaimed) {
      badgeColor = AppColors.success;
      badgeIcon = Icons.check_circle;
      badgeText = '+${place.points}';
    } else {
      badgeColor = isDark ? AppColors.neonOrange : AppColors.warningDark;
      badgeIcon = Icons.stars_rounded;
      badgeText = '+${place.points}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: badgeColor.withAlpha(isDark ? 60 : 50),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 13, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: badgeColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Konum uyarı banner'ı - Konum izni veya servis sorunu olduğunda gösterilir
class _LocationWarningBanner extends StatelessWidget {
  const _LocationWarningBanner({required this.status});

  final LocationStatus status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String message;
    IconData icon;
    VoidCallback? onTap;
    
    switch (status) {
      case LocationStatus.serviceDisabled:
        message = context.l10n.lblEnableLocationServices;
        icon = Icons.location_off;
        onTap = () => Geolocator.openLocationSettings();
        break;
      case LocationStatus.permissionDenied:
        message = context.l10n.lblGrantLocationPermission;
        icon = Icons.location_disabled;
        onTap = () => Geolocator.openAppSettings();
        break;
      case LocationStatus.permissionDeniedForever:
        message = context.l10n.locationPermissionFromSettings;
        icon = Icons.settings;
        onTap = () => Geolocator.openAppSettings();
        break;
      case LocationStatus.error:
        message = context.l10n.errLocationFailed;
        icon = Icons.error_outline;
        onTap = null;
        break;
      default:
        return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.orange.withAlpha(30) 
                  : Colors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark 
                    ? Colors.orange.withAlpha(60) 
                    : Colors.orange.withAlpha(40),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isDark ? Colors.orange[300] : Colors.orange[700],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.orange[200] : Colors.orange[800],
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: isDark ? Colors.orange[300] : Colors.orange[700],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Place card skeleton for loading state
class _PlaceCardSkeleton extends StatelessWidget {
  const _PlaceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 130, // SABİT KART YÜKSEKLİĞİ - _PlaceCard ile aynı
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image skeleton - 130x130
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: SkeletonLoader(
              width: 130,
              height: 130,
              borderRadius: BorderRadius.zero,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER: Title + Category Badge skeleton
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(
                              width: double.infinity,
                              height: 16,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 4),
                            SkeletonLoader(
                              width: 100,
                              height: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SkeletonLoader(
                        width: 60,
                        height: 24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),
                  // DESCRIPTION skeleton
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(
                        width: double.infinity,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      SkeletonLoader(
                        width: 150,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  // FOOTER: mesafe + ok iskeleti
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonLoader(
                        width: 72,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      SkeletonLoader(
                        width: 20,
                        height: 20,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
