import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/widgets/collect_points_card.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/models/models.dart' as data_models;
import '../../../../core/services/point_collection_service.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../l10n/l10n.dart';

class RouteStopCard extends StatelessWidget {
  const RouteStopCard({
    super.key,
    required this.index,
    required this.place,
    required this.routeId,
    required this.baseUrl,
    required this.stopJson,
    required this.visitedFromCampaign,
    required this.collectionState,
    required this.onCollect,
    this.isAuthenticated = true,
  });

  final int index;
  final data_models.RoutePlace place;
  final int? routeId;
  final String baseUrl;
  final Map<String, dynamic>? stopJson;
  final Set<String> visitedFromCampaign;
  final PointCollectionState collectionState;
  final VoidCallback onCollect;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    final effectivePoints =
        (stopJson?['stop_points'] as int?) ?? place.stopPoints ?? 0;
    final isVisited =
        (stopJson?['visited'] == true) || visitedFromCampaign.contains(place.id) || place.visited;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              // Navigate using CMS content ID for place detail (System A).
              // The detail provider handles resolving to gamification ID internally.
              context.push(
                '/places/${place.cmsContentId}',
                extra: {'routeId': routeId},
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
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
              child: Row(
                children: [
                  Stack(
                    children: [
                      Positioned(
                        left: -20,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _PlaceImage(
                          imageUrl: place.imageUrl,
                          baseUrl: baseUrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name ?? context.l10n.lblUnnamedStop,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        // Points/gamification feature flag — chip gizlenir.
                        if (FeatureFlags.pointsEnabled)
                          _StopPointsChip(
                            stopPoints: effectivePoints,
                            isVisited: isVisited,
                            collectionState: collectionState,
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context).hintColor,
                  ),
                ],
              ),
            ),
          ),
          // Points/gamification feature flag — collect card / guest prompt gizlenir.
          if (FeatureFlags.pointsEnabled &&
              routeId != null &&
              effectivePoints > 0 &&
              !isVisited)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: isAuthenticated
                  ? CollectPointsCard(
                      state: collectionState.status == PointCollectionStatus.noPoints
                          ? collectionState.copyWith(
                              status: PointCollectionStatus.tooFar,
                              availablePoints: effectivePoints,
                            )
                          : collectionState,
                      compact: true,
                      onCollect: onCollect,
                    )
                  : _GuestStopLoginPrompt(points: effectivePoints),
            ),
        ],
      ),
    );
  }
}

class _StopPointsChip extends StatelessWidget {
  const _StopPointsChip({
    required this.stopPoints,
    required this.isVisited,
    required this.collectionState,
  });

  final int stopPoints;
  final bool isVisited;
  final PointCollectionState collectionState;

  @override
  Widget build(BuildContext context) {
    if (isVisited || collectionState.status == PointCollectionStatus.collected) {
      if (isVisited) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  'Ziyaret edildi',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        );
      }
      final earned =
          collectionState.routeVisitResult?.pointsEarned ?? stopPoints;
      if (earned <= 0) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 14, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                '+$earned P',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    if (collectionState.status == PointCollectionStatus.collecting) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (stopPoints <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '+$stopPoints P',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _PlaceImage extends StatelessWidget {
  const _PlaceImage({
    required this.imageUrl,
    required this.baseUrl,
  });

  final String? imageUrl;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final url = buildImageUrl(imageUrl, baseUrl: baseUrl);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (url == null) {
      return Container(
        width: 64,
        height: 64,
        color: isDark ? AppColors.darkSurface : Colors.grey[200],
        child: Icon(
          Icons.place_outlined,
          size: 32,
          color: isDark ? AppColors.neonBlue.withAlpha(100) : Colors.grey,
        ),
      );
    }

    return Image.network(
      url,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 64,
          height: 64,
          color: isDark ? AppColors.darkSurface : Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        width: 64,
        height: 64,
        color: isDark ? AppColors.darkSurface : Colors.grey[200],
        child: Icon(
          Icons.place_outlined,
          size: 32,
          color: isDark ? AppColors.neonBlue.withAlpha(100) : Colors.grey,
        ),
      ),
    );
  }
}

class _GuestStopLoginPrompt extends StatelessWidget {
  const _GuestStopLoginPrompt({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.push('/login'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.stars_rounded,
                color: AppColors.neonOrange,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.msgPointsGuestLoginWithValue(points),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => context.push('/login'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.l10n.btnLogin,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

