import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/sort_menu.dart';
import '../../../data/models/favorite.dart';
import '../../../data/models/recipe.dart' as data_models;
import '../../../data/models/gastronomy.dart';
import '../../favorites/presentation/providers/favorites_provider.dart';
import '../../gastronomy/presentation/providers/gastronomy_provider.dart';
import 'models/recipe.dart';
import 'providers/recipes_provider.dart';
import 'widgets/widgets.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  RecipesTopTab _activeTopTab = RecipesTopTab.recipes;
  /// Sağ üst kalp: listede yalnızca favoriler.
  bool _filterFavoritesOnly = false;
  /// Arama çubuğundaki sıralama butonuna ankraj.
  final GlobalKey _sortKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Ekrana her girişte arama durumunu sıfırla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(recipesProvider.notifier);
      notifier.clearSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recipesState = ref.watch(recipesProvider);
    final favState = ref.watch(favoritesProvider);
    final gastronomyListAsync = ref.watch(gastronomyListProvider);

    // Provider'dan gelen tarifleri UI modeline map et
    final apiRecipes = recipesState.filteredRecipes.isNotEmpty
        ? recipesState.filteredRecipes
        : recipesState.recipes;
    var uiRecipes = apiRecipes
        .map(_mapApiRecipeToUi)
        .toList();
    if (_filterFavoritesOnly) {
      uiRecipes = uiRecipes
          .where(
            (r) => favState.isFavorite(FavoriteEntityType.recipe, r.id),
          )
          .toList();
    }
    
    // Provider'dan gelen kategorileri RecipeCategory'e dönüştür
    final apiCategories = recipesState.categories
        .map((cat) => RecipeCategory(
              id: cat.id,
              label: cat.label,
              icon: cat.icon,
            ))
        .toList();
    
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
                // Kategoriler yoksa header yüksekliğini biraz azalt
                // Üst sekmeler (Tarifler / Yöresel Lezzetler) eklendiği için
                // header yüksekliğini artırıyoruz; aksi halde arama çubuğu overflow olur.
                expandedHeight: apiCategories.isNotEmpty ? 252 : 212,
                backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                elevation: 0,
                forceElevated: innerBoxIsScrolled,
                automaticallyImplyLeading: false,
                toolbarHeight: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: RecipesHeader(
                    categories: apiCategories,
                    activeCategory: recipesState.selectedCategory,
                    onCategoryChanged: (category) {
                      ref.read(recipesProvider.notifier).setCategory(category);
                    },
                    activeTopTab: _activeTopTab,
                    onTopTabChanged: (tab) {
                      setState(() {
                        _activeTopTab = tab;
                      });
                    },
                    favoritesFilterActive: _filterFavoritesOnly,
                    onFavoritesPressed: () {
                      setState(() {
                        _filterFavoritesOnly = !_filterFavoritesOnly;
                      });
                    },
                    onSearch: (query) {
                      final notifier = ref.read(recipesProvider.notifier);
                      if (query.isEmpty) {
                        notifier.clearSearch();
                      } else {
                        notifier.search(query);
                      }
                    },
                    // §6.4.5 — sıralama yalnız Tarifler sekmesinde; arama
                    // yanındaki filtre butonuna ankrajlı menü ile.
                    sortMenuKey: _sortKey,
                    isSortActive: _activeTopTab == RecipesTopTab.recipes &&
                        ref.watch(recipesProvider
                                .select((s) => s.sortMode)) !=
                            RecipeSortMode.recommended,
                    onSortTap: _activeTopTab == RecipesTopTab.recipes
                        ? () => showAppSortMenu<RecipeSortMode>(
                              context: context,
                              anchorKey: _sortKey,
                              current: ref.read(recipesProvider).sortMode,
                              values: RecipeSortMode.values,
                              labelOf: (m) => recipeSortLabel(context.l10n, m),
                              onSelected: ref
                                  .read(recipesProvider.notifier)
                                  .setSortMode,
                            )
                        : null,
                  ),
                ),
              ),
            ),
          ];
        },
        body: Builder(
          builder: (context) {
            // Yöresel Lezzetler sekmesi aktifse gastronomy listesi göster
            if (_activeTopTab == RecipesTopTab.localFlavors) {
              return _buildGastronomyList(context, isDark, gastronomyListAsync);
            }
            
            // Tarifler sekmesi
            return CustomScrollView(
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        // Popüler mekanlar bölümü şimdilik görünmesin diye yorumda bırakıldı.
                        // İleride backend'den gerçek veri geldiğinde tekrar aktifleştirilebilir.
                        // PopularRestaurantsSection(restaurants: _popularRestaurants),
                        // const SizedBox(height: 24),
                        _buildRecipesHeader(context, isDark, uiRecipes.length),
                        const SizedBox(height: 12),
                        if (recipesState.isLoading && uiRecipes.isEmpty)
                          Column(
                            children: List.generate(
                              3,
                              (index) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _RecipeCardSkeleton(isDark: isDark),
                              ),
                            ),
                          )
                        else if (recipesState.error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              recipesState.error!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          )
                        else if (uiRecipes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              _filterFavoritesOnly
                                  ? context.l10n.recipeFavEmptyOrNoMatch
                                  : context.l10n.recipeNoneToShow,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                          )
                        else
                          ...uiRecipes.map(
                            (recipe) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: RecipeCard(
                                recipe: recipe,
                                isFavorite: favState.isFavorite(
                                  FavoriteEntityType.recipe,
                                  recipe.id,
                                ),
                                onFavoriteToggle: () {
                                  ref
                                      .read(favoritesProvider.notifier)
                                      .toggleFavorite(
                                        FavoriteEntityType.recipe,
                                        recipe.id,
                                      );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: AppNavBar.bottomPadding),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecipesHeader(BuildContext context, bool isDark, int recipesCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _activeTopTab == RecipesTopTab.recipes
              ? 'Tarifler'
              : context.l10n.sectionLocalDelicacies,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _activeTopTab == RecipesTopTab.recipes
                  ? '$recipesCount tarif'
                  : '$recipesCount lezzet',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withAlpha(150)
                        : Theme.of(context).hintColor,
                  ),
            ),
            // Sıralama artık arama çubuğundaki filtre butonunda (showAppSortMenu).
          ],
        ),
      ],
    );
  }

  /// API'den gelen Recipe modelini, UI'da kullanılan Recipe modeline dönüştürür.
  Recipe _mapApiRecipeToUi(data_models.Recipe api) {
    final timeText = api.durationMinutes != null
        ? '${api.durationMinutes} dk'
        : (api.prepTime ?? api.totalTime ?? '');

    return Recipe(
      id: api.id,
      image: api.imageUrl ?? 'assets/images/food-kebab.jpg',
      title: api.title,
      description: api.description ?? '',
      category: api.category,
      prepTime: timeText,
      difficulty: api.difficulty ?? '',
      servings: api.servings ?? 0,
      rating: api.rating ?? 0,
      reviews: api.reviewCount ?? 0,
      isLocal: api.isLocal,
    );
  }

  /// Yöresel Lezzetler listesi - MENUS API'den gelen verilerle
  Widget _buildGastronomyList(
    BuildContext context,
    bool isDark,
    AsyncValue<List<Gastronomy>> gastronomyAsync,
  ) {
    return gastronomyAsync.when(
      loading: () {
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildRecipesHeader(context, isDark, 0),
                  const SizedBox(height: 12),
                  Column(
                    children: List.generate(
                      3,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecipeCardSkeleton(isDark: isDark),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        );
      },
      error: (error, stackTrace) {
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildRecipesHeader(context, isDark, 0),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      context.l10n.delicaciesLoadError,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        );
      },
      data: (items) {
        final favState = ref.watch(favoritesProvider);
        final filtered = _filterFavoritesOnly
            ? items
                .where(
                  (g) => favState.isFavorite(FavoriteEntityType.menu, g.id),
                )
                .toList()
            : items;
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle:
                  NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildRecipesHeader(context, isDark, filtered.length),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _filterFavoritesOnly
                            ? context.l10n.delicacyFavEmptyOrNoMatch
                            : context.l10n.delicacyNoneToShow,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).hintColor,
                                ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GastronomyCard(
                          gastronomy: item,
                          isDark: isDark,
                          isFavorite: favState.isFavorite(
                            FavoriteEntityType.menu,
                            item.id,
                          ),
                          onFavoriteToggle: () {
                            ref
                                .read(favoritesProvider.notifier)
                                .toggleFavorite(
                                  FavoriteEntityType.menu,
                                  item.id,
                                );
                          },
                          onTap: () =>
                              context.push('/gastronomy/${item.id}'),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: AppNavBar.bottomPadding),
            ),
          ],
        );
      },
    );
  }
}

/// Tarif kartı için detaylı skeleton loading bileşeni
class _RecipeCardSkeleton extends StatelessWidget {
  const _RecipeCardSkeleton({required this.isDark});

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
                  height: 160,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
              // Kategori badge skeleton
              Positioned(
                top: 12,
                left: 12,
                child: SkeletonLoader(
                  width: 60,
                  height: 22,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // Favori ikonunun arka planı skeleton
              Positioned(
                top: 12,
                right: 12,
                child: SkeletonLoader(
                  width: 34,
                  height: 34,
                  borderRadius: BorderRadius.circular(999),
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
                // Alt bilgi: süre, kişi sayısı
                Row(
                  children: [
                    SkeletonLoader(
                      width: 70,
                      height: 12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(width: 12),
                    SkeletonLoader(
                      width: 70,
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

/// Yöresel lezzet kartı bileşeni
class _GastronomyCard extends StatelessWidget {
  const _GastronomyCard({
    required this.gastronomy,
    required this.isDark,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final Gastronomy gastronomy;
  final bool isDark;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final hasNetworkImage = gastronomy.imageUrl != null &&
        (gastronomy.imageUrl!.startsWith('http://') ||
            gastronomy.imageUrl!.startsWith('https://'));
    final hasVideo = gastronomy.videoUrl != null && gastronomy.videoUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            // Image section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: hasNetworkImage
                      ? Image.network(
                          gastronomy.imageUrl!,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildImageFallback(),
                        )
                      : _buildImageFallback(),
                ),
                // Category badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.neonOrange.withAlpha(230)
                          : Colors.orange.withAlpha(230),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      context.l10n.recipeLocal,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(6),
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
                      size: 20,
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
                // Video indicator (kalbin solunda; kategori rozeti sol üstte kalır)
                if (hasVideo)
                  Positioned(
                    top: 12,
                    right: 56,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                // Restaurant count badge
                if (gastronomy.relatedPlaces.isNotEmpty)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.neonCyan.withAlpha(200)
                            : Theme.of(context).colorScheme.primary.withAlpha(220),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.restaurant,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${gastronomy.relatedPlaces.length} mekan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gastronomy.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : null,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    gastronomy.description ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.white.withAlpha(150)
                              : Theme.of(context).hintColor,
                          height: 1.4,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Bottom row with action hint
                  Row(
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 14,
                        color: isDark
                            ? AppColors.neonOrange.withAlpha(180)
                            : Colors.orange.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.tapForDetails,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.neonOrange.withAlpha(180)
                                  : Colors.orange.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: isDark
                            ? Colors.white.withAlpha(100)
                            : Theme.of(context).hintColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      width: double.infinity,
      height: 160,
      color: isDark ? AppColors.darkSurfaceElevated : Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 48,
          color: isDark ? AppColors.neonOrange.withAlpha(100) : Colors.grey,
        ),
      ),
    );
  }
}
