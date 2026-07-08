import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/services/analytics_events.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/widgets/circular_icon_button.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/mixins/collapsing_scroll_mixin.dart';
import '../../../../data/models/favorite.dart';
import '../../../../data/models/recipe.dart' as data_models;
import '../../favorites/presentation/providers/favorites_provider.dart';
import 'providers/recipes_provider.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen>
    with CollapsingScrollMixin {
  @override
  void initState() {
    super.initState();
    initScrollController();

    // `mobile_pending_changes.md` PR1 + mobile_analytics_todo.md §2.2 —
    // Recipe detay açılış event'i. Sözlükte tipi spesifik tutmak yerine
    // generic content_tapped kullanıyoruz çünkü recipe için ayrı detail event'i
    // yok (place/route/event aksine).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).track(
        AnalyticsEvents.contentTapped,
        properties: {
          'entity_type': 'recipe',
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
    
    final recipeAsync = ref.watch(recipeDetailProvider(widget.id));
    final isFavorite = ref.watch(
      isFavoriteProvider((FavoriteEntityType.recipe, widget.id)),
    );

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && context.canPop()) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: recipeAsync.when(
          loading: () => CustomScrollView(
            controller: scrollController,
            slivers: [
              _buildAppBar(
                context,
                isDark: isDark,
                buttonBgColor: buttonBgColor,
                buttonIconColor: buttonIconColor,
                title: '',
                imageUrl: null,
                category: null,
                isLocal: false,
                isFavorite: isFavorite,
                onToggleFavorite: _toggleRecipeFavorite,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    _buildQuickStatsSkeleton(context),
                    const SizedBox(height: 24),
                    _buildSectionSkeleton(context, title: context.l10n.titleRecipeAbout),
                    const SizedBox(height: 24),
                    _buildSectionSkeleton(context, title: 'Malzemeler', lines: 4),
                    const SizedBox(height: 24),
                    _buildSectionSkeleton(context, title: context.l10n.recipePreparation, lines: 4),
                    SizedBox(height: AppNavBar.bottomPadding + 80),
                  ]),
                ),
              ),
            ],
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${context.l10n.recipeLoadError}\n${err.toString()}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
          ),
          data: (recipe) {
            if (recipe == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.l10n.errRecipeNotFound,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ),
              );
            }

            final ingredients = recipe.ingredients;
            final steps = recipe.instructions;

            return CustomScrollView(
              controller: scrollController,
              slivers: [
                _buildAppBar(
                  context,
                  isDark: isDark,
                  buttonBgColor: buttonBgColor,
                  buttonIconColor: buttonIconColor,
                  title: recipe.title,
                  imageUrl: recipe.imageUrl,
                  category: recipe.category,
                  isLocal: recipe.isLocal,
                  isFavorite: isFavorite,
                  onToggleFavorite: _toggleRecipeFavorite,
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),
                      _buildQuickStats(context, recipe),
                      const SizedBox(height: 24),
                      _buildDescription(context, recipe),
                      if (ingredients.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildIngredients(context, ingredients),
                      ],
                      if (steps.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSteps(context, steps),
                      ],
                      // Püf Noktaları bölümü - şimdilik yorum satırında, ileride eklenebilir
                      // const SizedBox(height: 24),
                      // _buildTips(context),
                      const SizedBox(height: 24),
                      _buildActionButtons(context, isFavorite),
                      SizedBox(height: AppNavBar.bottomPadding + 80),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _toggleRecipeFavorite() {
    ref.read(favoritesProvider.notifier).toggleFavorite(
          FavoriteEntityType.recipe,
          widget.id,
        );
  }

  SliverAppBar _buildAppBar(
    BuildContext context, {
    required bool isDark,
    required Color buttonBgColor,
    required Color buttonIconColor,
    required String title,
    required String? imageUrl,
    required String? category,
    required bool isLocal,
    required bool isFavorite,
    required VoidCallback onToggleFavorite,
  }) {
    final hasNetworkImage =
        imageUrl != null && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      title: buildCollapsingTitle(
        context,
        title: title.isNotEmpty ? title : context.l10n.titleRecipeDetail,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasNetworkImage)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildImageFallback(isDark),
              )
            else
              Image.asset(
                'assets/images/food-kebab.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildImageFallback(isDark),
              ),
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
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: buildFlexibleContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (category != null || isLocal)
                      Row(
                        children: [
                          if (category != null && category.isNotEmpty)
                            _badge(
                              context,
                              category,
                              isDark ? AppColors.neonBlue : Colors.blue,
                            ),
                          if (category != null && category.isNotEmpty && isLocal)
                            const SizedBox(width: 8),
                          if (isLocal)
                            _badge(
                              context,
                              context.l10n.recipeLocal,
                              isDark ? AppColors.neonOrange : Colors.red,
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(
                      title.isNotEmpty ? title : context.l10n.titleRecipeDetail,
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
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: CircularIconButton(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            backgroundColor: buttonBgColor,
            iconColor: isFavorite
                ? (isDark ? AppColors.neonPink : Theme.of(context).colorScheme.error)
                : (isDark ? AppColors.neonPink : null),
            onPressed: onToggleFavorite,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context, data_models.Recipe recipe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(
            context,
            icon: Icons.access_time,
            iconColor: isDark ? AppColors.neonCyan : Theme.of(context).colorScheme.primary,
            title: _formatTime(recipe),
            subtitle: 'dk',
            trailingSmall: context.l10n.recipePrepTime,
          ),
          _divider(context),
          _statItem(
            context,
            icon: Icons.people_outline,
            iconColor: isDark ? AppColors.neonPurple : Theme.of(context).colorScheme.secondary,
            title: recipe.servings?.toString() ?? '-',
            subtitle: context.l10n.recipeServings,
            trailingSmall: 'Porsiyon',
          ),
          _divider(context),
          _statItem(
            context,
            icon: Icons.local_fire_department_outlined,
            iconColor: isDark ? AppColors.neonOrange : Colors.red,
            title: recipe.difficulty ?? '-',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
                    color: isDark ? Colors.white : null,
                  ),
            ),
            if (trailingSmall != null) ...[
              const SizedBox(width: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white.withAlpha(180) : null,
                    ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          trailingSmall ?? subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white.withAlpha(150) : Theme.of(context).hintColor,
              ),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 40,
      color: isDark ? Colors.white.withAlpha(30) : Theme.of(context).dividerColor.withAlpha(102),
    );
  }

  Widget _buildDescription(BuildContext context, data_models.Recipe recipe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.titleRecipeAbout,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          (recipe.description?.isNotEmpty ?? false)
              ? recipe.description!
              : context.l10n.recipeNoDescription,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white.withAlpha(180) : Theme.of(context).hintColor,
                height: 1.6,
              ),
        ),
      ],
    );
  }

  Widget _buildIngredients(BuildContext context, List<String> ingredients) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Malzemeler',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
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
            children: [
              for (final ingredient in ingredients)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.neonOrange : Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ingredient,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white.withAlpha(200) : null,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSteps(BuildContext context, List<String> steps) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.recipePreparation,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            for (int i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: isDark
                        ? Border.all(color: Colors.white.withAlpha(15))
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.neonOrange : Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: isDark
                              ? [
                                  BoxShadow(
                                    color: AppColors.neonOrange.withAlpha(40),
                                    blurRadius: 6,
                                    spreadRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isDark ? Colors.white : Theme.of(context).colorScheme.onPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            steps[i],
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  height: 1.6,
                                  color: isDark ? Colors.white.withAlpha(200) : null,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // Püf Noktaları bölümü - şimdilik yorum satırında, ileride eklenebilir
  // Widget _buildTips(BuildContext context) {
  //   final isDark = Theme.of(context).brightness == Brightness.dark;
  //   
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         'Püf Noktaları',
  //         style: Theme.of(context).textTheme.titleMedium?.copyWith(
  //               fontWeight: FontWeight.w600,
  //               color: isDark ? Colors.white : null,
  //             ),
  //       ),
  //       const SizedBox(height: 8),
  //       Container(
  //         padding: const EdgeInsets.all(16),
  //         decoration: BoxDecoration(
  //           color: isDark
  //               ? AppColors.neonOrange.withAlpha(20)
  //               : Colors.orange.withAlpha(26),
  //           borderRadius: BorderRadius.circular(12),
  //           border: Border.all(
  //             color: isDark
  //                 ? AppColors.neonOrange.withAlpha(50)
  //                 : Colors.orange.withAlpha(51),
  //             width: 1,
  //           ),
  //         ),
  //         child: Row(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Icon(
  //               Icons.set_meal_outlined,
  //               color: isDark ? AppColors.neonOrange : Colors.orange.shade700,
  //               size: 20,
  //             ),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: Text(
  //                 'Etin daha yumuşak olması için bir gece önceden marine edebilirsiniz. '
  //                 'Pişirme sırasında kapağı açmadan pişirmeniz önemlidir.',
  //                 style: Theme.of(context).textTheme.bodySmall?.copyWith(
  //                       height: 1.6,
  //                       color: isDark ? Colors.white.withAlpha(180) : null,
  //                     ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildActionButtons(
    BuildContext context,
    bool isFavorite,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.neonOrange : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: isDark ? 0 : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle_outline, size: 20),
                SizedBox(width: 8),
                Text(
                  'Tarifi Denedim',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _toggleRecipeFavorite,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(16),
            side: BorderSide(
              color: isFavorite
                  ? (isDark
                      ? AppColors.neonPink
                      : Theme.of(context).colorScheme.error)
                  : (isDark
                      ? AppColors.neonPink.withAlpha(150)
                      : Theme.of(context).colorScheme.outline),
              width: 1.4,
            ),
            backgroundColor: isFavorite
                ? (isDark
                    ? AppColors.neonPink.withAlpha(28)
                    : Theme.of(context).colorScheme.error.withAlpha(22))
                : null,
          ),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite
                ? (isDark ? AppColors.neonPink : Theme.of(context).colorScheme.error)
                : (isDark ? AppColors.neonPink : null),
          ),
        ),
      ],
    );
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

  Widget _buildImageFallback(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurfaceElevated : Colors.grey[300],
      child: Icon(
        Icons.restaurant,
        size: 64,
        color: isDark ? AppColors.neonOrange.withAlpha(100) : Colors.grey,
      ),
    );
  }

  Widget _buildQuickStatsSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SkeletonLoader(
            width: 80,
            height: 24,
            borderRadius: BorderRadius.circular(999),
          ),
          _divider(context),
          SkeletonLoader(
            width: 80,
            height: 24,
            borderRadius: BorderRadius.circular(999),
          ),
          _divider(context),
          SkeletonLoader(
            width: 80,
            height: 24,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSkeleton(
    BuildContext context, {
    required String title,
    int lines = 3,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
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
            children: List.generate(
              lines,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SkeletonLoader(
                  width: double.infinity,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(data_models.Recipe recipe) {
    // Öncelik sırası: duration_minutes (sayı), totalTime (string), prepTime (string)
    if (recipe.durationMinutes != null) {
      return '${recipe.durationMinutes}';
    }
    final raw = recipe.totalTime ?? recipe.prepTime;
    if (raw == null || raw.isEmpty) return '-';
    return raw;
  }
}
