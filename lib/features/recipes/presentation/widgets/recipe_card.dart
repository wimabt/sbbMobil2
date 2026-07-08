import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../core/services/analytics_events.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/widgets/cached_image.dart';
import '../models/recipe.dart';

class RecipeCard extends ConsumerWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final Recipe recipe;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // mobile_pending_changes.md PR1 — content_tapped (list source)
          ref.read(analyticsServiceProvider).track(
            AnalyticsEvents.contentTapped,
            properties: {
              'entity_type': 'recipe',
              'entity_id': recipe.id,
              'source': AnalyticsSource.list,
            },
          );
          context.push('/recipes/${recipe.id}');
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: isDark
            ? AppColors.neonOrange.withAlpha(30)
            : Theme.of(context).colorScheme.primary.withAlpha(30),
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
              _buildImage(context, isDark),
              _buildContent(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, bool isDark) {
    final imagePath = recipe.image;
    final isNetworkImage =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          child: isNetworkImage
              ? CachedImage(
                  imageUrl: imagePath,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : Image.asset(
                  imagePath,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildImageFallback(isDark),
                ),
        ),
        if (recipe.category.isNotEmpty || recipe.isLocal)
          Positioned(
            top: 10,
            left: 10,
            child: Row(
              children: [
                if (recipe.category.isNotEmpty)
                  _badge(
                    context,
                    recipe.category,
                    isDark
                        ? AppColors.darkSurface.withAlpha(230)
                        : Colors.white.withAlpha(230),
                    isDark,
                  ),
                if (recipe.category.isNotEmpty && recipe.isLocal) const SizedBox(width: 8),
                if (recipe.isLocal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? LinearGradient(
                              colors: [AppColors.neonOrange.withAlpha(200), AppColors.neonOrange],
                            )
                          : LinearGradient(
                              colors: [Colors.orange.shade400, Colors.orange.shade600],
                            ),
                      borderRadius: BorderRadius.circular(999),
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
                    child: const Text(
                      'Yöresel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withAlpha(230)
                    : Colors.white.withAlpha(230),
                shape: BoxShape.circle,
                border: isDark
                    ? Border.all(color: Colors.white.withAlpha(30))
                    : null,
              ),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite
                    ? (isDark ? AppColors.neonPink : Theme.of(context).colorScheme.error)
                    : (isDark ? Colors.white.withAlpha(180) : Theme.of(context).hintColor),
                size: 20,
              ),
            ),
            onPressed: onFavoriteToggle,
          ),
        ),
      ],
    );
  }

  Widget _buildImageFallback(bool isDark) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.grey[200],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Icon(
        Icons.restaurant,
        color: isDark ? AppColors.neonOrange.withAlpha(100) : Colors.grey,
        size: 48,
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : null,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            recipe.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white.withAlpha(180) : null,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _buildFooter(context, isDark),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    final iconColor = isDark ? AppColors.neonCyan : Theme.of(context).hintColor;
    final textColor = isDark ? Colors.white.withAlpha(180) : null;
    
    final timeText = recipe.prepTime.isNotEmpty ? recipe.prepTime : '-';
    final servingsText = recipe.servings > 0 ? '${recipe.servings} kişi' : '-';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.access_time, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              timeText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor),
            ),
            const SizedBox(width: 12),
            Icon(Icons.people_outline, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              servingsText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor),
            ),
          ],
        ),
        Icon(
          Icons.chevron_right,
          size: 20,
          color: isDark ? AppColors.neonBlue : Theme.of(context).hintColor,
        ),
      ],
    );
  }

  Widget _badge(BuildContext context, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: isDark
            ? Border.all(color: Colors.white.withAlpha(30))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

