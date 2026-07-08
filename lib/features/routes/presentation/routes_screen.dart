import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/sort_menu.dart';
import '../../../data/models/favorite.dart';
import '../../../l10n/l10n.dart';
import '../../favorites/presentation/providers/favorites_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/presentation/models/completed_route.dart';
import 'providers/routes_provider.dart';
import 'widgets/widgets.dart';
import '../../profile/presentation/providers/completed_routes_provider.dart';

double _parseDistanceKmFromLabel(String distance) {
  final match = RegExp(r'(-?\d+(?:\.\d+)?)').firstMatch(distance);
  final parsed = match?.group(1);
  return double.tryParse(parsed ?? '') ?? 0;
}

class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  bool _filterFavoritesOnly = false;
  /// Arama çubuğundaki sıralama butonuna ankraj.
  final GlobalKey _sortKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    debugPrint('📱 [RoutesScreen] initState called');
    // Ekrana her girişte arama durumunu sıfırla ve rotaları yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('📱 [RoutesScreen] PostFrameCallback executing');
      final notifier = ref.read(routesProvider.notifier);
      notifier.clearSearch();
      // Eğer rotalar yüklenmemişse, yükle
      final state = ref.read(routesProvider);
      if (state.routes.isEmpty && !state.isLoading) {
        debugPrint('📱 [RoutesScreen] Routes empty, triggering loadRoutes');
        notifier.loadRoutes(refresh: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoggedIn =
        ref.watch(authProvider.select((s) => s.status == AuthStatus.authenticated));
    final routesState = ref.watch(routesProvider);
    final favState = ref.watch(favoritesProvider);

    // Provider'dan gelen rotaları kullan
    var routes = routesState.filteredRoutes.isNotEmpty
        ? routesState.filteredRoutes
        : routesState.routes;
    if (_filterFavoritesOnly) {
      routes = routes
          .where((r) => favState.isFavorite(FavoriteEntityType.route, r.id))
          .toList();
    }

    final completedRoutesAsync = ref.watch(completedRoutesProvider);
    final completedList = isLoggedIn
        ? (completedRoutesAsync.value ?? <CompletedRoute>[])
        : <CompletedRoute>[];
    final completedCount = completedList.length;
    final completedDistanceKm = completedList.fold<double>(
      0,
      (sum, r) => sum + _parseDistanceKmFromLabel(r.distance),
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                floating: true,
                pinned: false,
                // Başlık + favori satırı + arama (50px); 132 dar kalınca RenderFlex taşması oluyordu.
                expandedHeight: 188,
                backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                elevation: 0,
                forceElevated: innerBoxIsScrolled,
                automaticallyImplyLeading: false,
                toolbarHeight: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: RoutesHeader(
                    favoritesFilterActive: _filterFavoritesOnly,
                    onFavoritesPressed: () {
                      setState(() {
                        _filterFavoritesOnly = !_filterFavoritesOnly;
                      });
                    },
                    onSearch: (query) {
                      final notifier = ref.read(routesProvider.notifier);
                      if (query.isEmpty) {
                        notifier.clearSearch();
                      } else {
                        notifier.search(query);
                      }
                    },
                    // §6.4.5 — sıralama arama yanındaki filtre butonunda.
                    sortMenuKey: _sortKey,
                    isSortActive: ref.watch(routesProvider
                            .select((s) => s.sortMode)) !=
                        RouteSortMode.name,
                    onSortTap: () => showAppSortMenu<RouteSortMode>(
                      context: context,
                      anchorKey: _sortKey,
                      current: ref.read(routesProvider).sortMode,
                      values: RouteSortMode.values,
                      labelOf: (m) => routeSortLabel(context.l10n, m),
                      onSelected: ref.read(routesProvider.notifier).setSortMode,
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: Builder(
          builder: (context) {
            return CustomScrollView(
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (isLoggedIn) ...[
                        _buildStatsRow(
                          context,
                          isDark,
                          completedCount: completedCount,
                          totalDistanceKm: completedDistanceKm,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildResultsCount(context, isDark, routes.length),
                      const SizedBox(height: 12),
                      if (routesState.isLoading && routes.isEmpty)
                        Column(
                          children: List.generate(
                            3,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RouteCardSkeleton(isDark: isDark),
                            ),
                          ),
                        )
                      else if (routesState.error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.errRoutesLoadFailed,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                routesState.error!.contains('403') || routesState.error!.contains('erişim izni')
                                    ? 'Routes endpoint\'ine erişim izni yok.\nBackend\'de route tanımlı mı kontrol edin.'
                                    : routesState.error!.contains('HTML') || routesState.error!.contains('endpoint')
                                        ? 'API endpoint bulunamadı.\nBackend\'de route tanımlı mı kontrol edin.'
                                        : routesState.error!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.white.withAlpha(180) : Theme.of(context).hintColor,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  ref.read(routesProvider.notifier).loadRoutes(refresh: true);
                                },
                                icon: const Icon(Icons.refresh),
                                label: Text(context.l10n.btnRetry),
                              ),
                            ],
                          ),
                        )
                      else if (routes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            _filterFavoritesOnly
                                ? 'Favori rotanız yok veya eşleşen sonuç bulunamadı.'
                                : 'Şu anda gösterilecek rota bulunamadı.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).hintColor,
                                ),
                          ),
                        )
                      else
                        ...routes.map(
                          (route) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RouteCard(
                              route: route,
                              isFavorite: favState.isFavorite(
                                FavoriteEntityType.route,
                                route.id,
                              ),
                              onFavoriteToggle: () {
                                ref.read(favoritesProvider.notifier).toggleFavorite(
                                      FavoriteEntityType.route,
                                      route.id,
                                    );
                              },
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 160),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    bool isDark, {
    required int completedCount,
    required double totalDistanceKm,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RouteStatCard(
                value: completedCount.toString(),
                label: 'Tamamlanan',
                color: isDark ? AppColors.neonBlue : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RouteStatCard(
                value: totalDistanceKm > 0
                    ? '${totalDistanceKm.toStringAsFixed(1)} km'
                    : '-',
                label: context.l10n.lblTotalDistance,
                color: isDark ? AppColors.neonCyan : Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildResultsCount(BuildContext context, bool isDark, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$count rota bulundu',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? Colors.white.withAlpha(150)
                    : Theme.of(context).hintColor,
              ),
        ),
        // Sıralama artık arama çubuğundaki filtre butonunda (showAppSortMenu).
      ],
    );
  }
}

/// Route kartı için skeleton loading bileşeni
class _RouteCardSkeleton extends StatelessWidget {
  const _RouteCardSkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Görsel skeleton
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: SkeletonLoader(
                  width: double.infinity,
                  height: 144,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
              // Badge skeleton
              Positioned(
                top: 12,
                left: 12,
                child: Row(
                  children: [
                    SkeletonLoader(
                      width: 60,
                      height: 22,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(width: 8),
                    SkeletonLoader(
                      width: 50,
                      height: 22,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // İçerik skeleton
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                // Açıklama satırları
                SkeletonLoader(
                  width: double.infinity,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 12),
                // Alt bilgi: mesafe, durak
                Row(
                  children: [
                    SkeletonLoader(
                      width: 70,
                      height: 12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(width: 12),
                    SkeletonLoader(
                      width: 80,
                      height: 12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const Spacer(),
                    SkeletonLoader(
                      width: 18,
                      height: 18,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
