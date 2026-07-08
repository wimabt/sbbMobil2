import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../core/services/analytics_events.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/widgets/cached_image.dart';
import '../models/route_data.dart';

class RouteCard extends ConsumerWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final TourRoute route;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  Color _getDifficultyColor(bool isDark) {
    final difficulty = route.difficulty.toLowerCase();
    switch (difficulty) {
      case 'easy':
      case 'kolay':
        return isDark ? AppColors.neonCyan : Colors.green;
      case 'medium':
      case 'orta':
        return isDark ? AppColors.neonOrange : Colors.orange;
      case 'hard':
      case 'zor':
        return isDark ? AppColors.neonPink : Colors.red;
      default:
        // API'den gelmeyen değerler için gri renk
        return Colors.grey;
    }
  }

  String get _difficultyLabel {
    switch (route.difficulty.toLowerCase()) {
      case 'easy':
      case 'kolay':
        return 'Kolay';
      case 'medium':
      case 'orta':
        return 'Orta';
      case 'hard':
      case 'zor':
        return 'Zor';
      default:
        // API'den gelmeyen değerler için "-" göster
        return route.difficulty;
    }
  }

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
              'entity_type': 'route',
              'entity_id': route.id,
              'source': AnalyticsSource.list,
            },
          );
          context.push('/routes/${route.id}');
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: isDark
            ? AppColors.neonBlue.withAlpha(30)
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
              _buildImage(context, isDark, isFavorite, onFavoriteToggle),
              _buildContent(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(
    BuildContext context,
    bool isDark,
    bool isFavorite,
    VoidCallback onFavoriteToggle,
  ) {
    final imagePath = route.image;
    final isNetworkImage = imagePath.startsWith('http://') || 
                          imagePath.startsWith('https://');
    
    final imageFallback = Container(
      height: 144,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.grey[200],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Icon(
        Icons.route,
        color: isDark ? AppColors.neonCyan.withAlpha(100) : Colors.grey,
        size: 48,
      ),
    );

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
                  height: 144,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : Image.asset(
                  imagePath,
                  height: 144,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => imageFallback,
                ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: Row(
            children: [
              // Anlamlı kategori / mod etiketi yoksa rozet gösterme
              if (route.category != '-' && route.category != 'ROTA') ...[
                _badge(
                  context,
                  route.category,
                  isDark
                      ? AppColors.darkSurface.withAlpha(230)
                      : Colors.white.withAlpha(230),
                  isDark,
                ),
                const SizedBox(width: 8),
              ],
              // Difficulty badge'i her zaman göster (eğer "-" ise gri renkte)
              if (_difficultyLabel.isNotEmpty && _difficultyLabel != '-')
                _badge(
                  context,
                  _difficultyLabel,
                  _getDifficultyColor(isDark).withAlpha(isDark ? 200 : 230),
                  isDark,
                  isColored: true,
                ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Points/gamification feature flag — kart üzeri "+puan" chip'i.
              if (FeatureFlags.pointsEnabled && route.points > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? LinearGradient(
                            colors: [
                              AppColors.neonOrange.withAlpha(200),
                              AppColors.neonOrange
                            ],
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
                  child: Text(
                    '+${route.points} puan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : null,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            route.description,
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
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.route_outlined, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              route.distance,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor),
            ),
            if (route.stops > 0) ...[
              const SizedBox(width: 12),
              Icon(Icons.place_outlined, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                '${route.stops} durak',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor),
              ),
            ],
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

  Widget _badge(BuildContext context, String label, Color color, bool isDark, {bool isColored = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: isDark && !isColored
            ? Border.all(color: Colors.white.withAlpha(30))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isColored
              ? Colors.white
              : (isDark ? Colors.white : Theme.of(context).colorScheme.onSurface),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

