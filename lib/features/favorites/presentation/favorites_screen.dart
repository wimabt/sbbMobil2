import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../data/models/favorite.dart';
import '../../../data/models/gastronomy.dart';
import '../../../data/models/recipe.dart';
import '../../../l10n/l10n.dart';
import '../../gastronomy/presentation/providers/gastronomy_provider.dart';
import '../../places/presentation/providers/places_provider.dart';
import '../../recipes/presentation/providers/recipes_provider.dart';
import '../../routes/presentation/models/route_data.dart';
import '../../routes/presentation/providers/routes_provider.dart';
import 'providers/favorites_provider.dart';

/// Şartname §6.5.1 — Favoriler ekranı.
///
/// Dört sekmeli liste: Mekanlar, Tarifler, Rotalar, Lezzetler.
/// Listeler hâlihazırda ilgili özelliklerin Notifier önbelleklerinden çekilir;
/// ayrı bir API isteği yapılmaz. Kart üzerindeki kalp ikonuna basıldığında
/// favori durumu kaldırılır (§6.5.1 son madde).
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = <_FavoriteTab>[
    _FavoriteTab(label: 'Mekanlar', type: FavoriteEntityType.place),
    _FavoriteTab(label: 'Tarifler', type: FavoriteEntityType.recipe),
    _FavoriteTab(label: 'Rotalar', type: FavoriteEntityType.route),
    _FavoriteTab(label: 'Lezzetler', type: FavoriteEntityType.menu),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final favState = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              totalCount: favState.favoriteIds.values
                  .fold<int>(0, (sum, set) => sum + set.length),
            ),
            _Tabs(controller: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _PlacesFavoritesTab(favoriteIds: favState.favoriteIds),
                  _RecipesFavoritesTab(favoriteIds: favState.favoriteIds),
                  _RoutesFavoritesTab(favoriteIds: favState.favoriteIds),
                  _MenusFavoritesTab(favoriteIds: favState.favoriteIds),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteTab {
  const _FavoriteTab({required this.label, required this.type});
  final String label;
  final FavoriteEntityType type;
}

// ═══════════════════════════════════════════════════════════════════════
// Header & tabs
// ═══════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            tooltip: 'Geri',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.settingsFavorites,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                if (totalCount > 0)
                  Text(
                    context.l10n.favRecordCount(totalCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: isDark ? AppColors.neonPink : theme.colorScheme.primary,
        unselectedLabelColor: theme.hintColor,
        indicatorColor:
            isDark ? AppColors.neonPink : theme.colorScheme.primary,
        indicatorWeight: 2.5,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        dividerColor: Colors.transparent,
        tabs: [
          for (final t in _FavoritesScreenState._tabs) Tab(text: t.label),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab bodies — her sekme kendi listesini ilgili Notifier önbelleğinden alır
// ═══════════════════════════════════════════════════════════════════════

class _PlacesFavoritesTab extends ConsumerWidget {
  const _PlacesFavoritesTab({required this.favoriteIds});

  final Map<FavoriteEntityType, Set<String>> favoriteIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = favoriteIds[FavoriteEntityType.place] ?? const <String>{};
    final placesState = ref.watch(placesProvider);

    if (ids.isEmpty) {
      return _EmptyState(
        icon: Icons.place_outlined,
        message: context.l10n.favEmptyPlaces,
      );
    }

    final items = placesState.allPlaces.where((p) => ids.contains(p.id)).toList();
    if (items.isEmpty && placesState.isLoading) {
      return const _LoadingState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(favoritesProvider.notifier).refresh();
        await ref.read(placesProvider.notifier).refresh();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          AppNavBar.bottomPadding,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final place = items[index];
          return _FavoriteCard(
            title: place.name,
            subtitle: place.description,
            imageUrl: _resolvedImageUrl(place.imageUrl),
            fallbackIcon: Icons.place,
            onTap: () => context.push('/places/${place.cmsContentId}'),
            onRemove: () => _remove(ref, FavoriteEntityType.place, place.id),
          );
        },
      ),
    );
  }
}

class _RecipesFavoritesTab extends ConsumerWidget {
  const _RecipesFavoritesTab({required this.favoriteIds});

  final Map<FavoriteEntityType, Set<String>> favoriteIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = favoriteIds[FavoriteEntityType.recipe] ?? const <String>{};
    final recipesState = ref.watch(recipesProvider);

    if (ids.isEmpty) {
      return _EmptyState(
        icon: Icons.restaurant_menu_outlined,
        message: context.l10n.favEmptyRecipes,
      );
    }

    final items =
        recipesState.recipes.where((r) => ids.contains(r.id)).toList();
    if (items.isEmpty && recipesState.isLoading) {
      return const _LoadingState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(favoritesProvider.notifier).refresh();
        await ref.read(recipesProvider.notifier).refresh();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          AppNavBar.bottomPadding,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final Recipe recipe = items[index];
          return _FavoriteCard(
            title: recipe.title,
            subtitle: recipe.description,
            imageUrl: _resolvedImageUrl(recipe.imageUrl),
            fallbackIcon: Icons.restaurant_menu_rounded,
            onTap: () => context.push('/recipes/${recipe.id}'),
            onRemove: () => _remove(ref, FavoriteEntityType.recipe, recipe.id),
          );
        },
      ),
    );
  }
}

class _RoutesFavoritesTab extends ConsumerWidget {
  const _RoutesFavoritesTab({required this.favoriteIds});

  final Map<FavoriteEntityType, Set<String>> favoriteIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = favoriteIds[FavoriteEntityType.route] ?? const <String>{};
    final routesState = ref.watch(routesProvider);

    if (ids.isEmpty) {
      return _EmptyState(
        icon: Icons.alt_route_rounded,
        message: context.l10n.favEmptyRoutes,
      );
    }

    final items =
        routesState.routes.where((r) => ids.contains(r.id)).toList();
    if (items.isEmpty && routesState.isLoading) {
      return const _LoadingState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(favoritesProvider.notifier).refresh();
        await ref.read(routesProvider.notifier).refresh();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          AppNavBar.bottomPadding,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final TourRoute route = items[index];
          final isNetwork = route.image.startsWith('http://') ||
              route.image.startsWith('https://');
          return _FavoriteCard(
            title: route.title,
            subtitle: route.description,
            imageUrl: isNetwork ? route.image : null,
            assetImagePath: isNetwork ? null : route.image,
            fallbackIcon: Icons.alt_route_rounded,
            onTap: () => context.push('/routes/${route.id}'),
            onRemove: () => _remove(ref, FavoriteEntityType.route, route.id),
          );
        },
      ),
    );
  }
}

class _MenusFavoritesTab extends ConsumerWidget {
  const _MenusFavoritesTab({required this.favoriteIds});

  final Map<FavoriteEntityType, Set<String>> favoriteIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = favoriteIds[FavoriteEntityType.menu] ?? const <String>{};

    if (ids.isEmpty) {
      return _EmptyState(
        icon: Icons.local_dining_outlined,
        message: context.l10n.favEmptyDelicacies,
      );
    }

    final asyncList = ref.watch(gastronomyListProvider);

    return asyncList.when(
      loading: () => const _LoadingState(),
      error: (error, _) => _ErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(gastronomyListProvider),
      ),
      data: (list) {
        final items = list.where((g) => ids.contains(g.id)).toList();
        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(favoritesProvider.notifier).refresh();
            ref.invalidate(gastronomyListProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              AppNavBar.bottomPadding,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final Gastronomy g = items[index];
              return _FavoriteCard(
                title: g.name,
                subtitle: g.description,
                imageUrl: _resolvedImageUrl(g.imageUrl),
                fallbackIcon: Icons.local_dining_rounded,
                onTap: () => context.push('/gastronomy/${g.id}'),
                onRemove: () => _remove(ref, FavoriteEntityType.menu, g.id),
              );
            },
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Helpers & shared widgets
// ═══════════════════════════════════════════════════════════════════════

String? _resolvedImageUrl(String? raw) {
  const config = ApiConfig.prod;
  return buildImageUrl(raw, baseUrl: config.baseUrl);
}

void _remove(WidgetRef ref, FavoriteEntityType type, String id) {
  ref.read(favoritesProvider.notifier).toggleFavorite(type, id);
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.title,
    required this.subtitle,
    required this.fallbackIcon,
    required this.onTap,
    required this.onRemove,
    this.imageUrl,
    this.assetImagePath,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? assetImagePath;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark
                ? Border.all(color: Colors.white.withAlpha(15))
                : null,
            boxShadow: isDark ? null : AppElevation.level1,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: _buildImage(isDark),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : null,
                              ),
                            ),
                            if (subtitle != null && subtitle!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? Colors.white.withAlpha(160)
                                        : theme.hintColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.favRemove,
                        onPressed: onRemove,
                        icon: Icon(
                          Icons.favorite,
                          color: isDark
                              ? AppColors.neonPink
                              : theme.colorScheme.error,
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
    );
  }

  Widget _buildImage(bool isDark) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedImage(
        imageUrl: imageUrl!,
        width: 110,
        height: 110,
        fit: BoxFit.cover,
      );
    }
    if (assetImagePath != null && assetImagePath!.isNotEmpty) {
      return Image.asset(
        assetImagePath!,
        width: 110,
        height: 110,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imageFallback(isDark),
      );
    }
    return _imageFallback(isDark);
  }

  Widget _imageFallback(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurfaceElevated : Colors.grey[200],
      child: Icon(
        fallbackIcon,
        color: isDark ? AppColors.neonBlue.withAlpha(120) : Colors.grey,
        size: 28,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.hintColor.withAlpha(120)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.favHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor.withAlpha(160),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
