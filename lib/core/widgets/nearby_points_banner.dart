import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/providers/nearby_points_provider.dart';
import '../design/design_tokens.dart';
import '../services/point_collection_service.dart';

/// Home ekranının üstünde gösterilen "Yakınızda puan kazanabilirsiniz" banner'ı.
///
/// [NearbyPointPlacesProvider]'ı dinler ve yakınlarda puanlı mekan varsa
/// kullanıcıyı yönlendirir.
class NearbyPointsBanner extends ConsumerWidget {
  const NearbyPointsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyAsync = ref.watch(nearbyPointPlacesProvider);

    return nearbyAsync.when(
      data: (places) {
        if (places.isEmpty) return const SizedBox.shrink();

        final closest = places.first;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isWithinRange =
            closest.status == PointCollectionStatus.withinRange;

        final bgColor = isWithinRange
            ? (isDark ? AppColors.neonOrange.withAlpha(25) : Colors.orange.withAlpha(15))
            : (isDark ? AppColors.neonCyan.withAlpha(20) : Colors.blue.withAlpha(10));
        final borderColor = isWithinRange
            ? Colors.orange.withAlpha(60)
            : (isDark ? AppColors.neonCyan.withAlpha(40) : Colors.blue.withAlpha(30));
        final accentColor = isWithinRange
            ? Colors.orange
            : (isDark ? AppColors.neonCyan : Colors.blue);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              context.push('/places/${closest.placeId}');
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(isDark ? 40 : 30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isWithinRange
                          ? Icons.star_rounded
                          : Icons.near_me_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isWithinRange
                              ? 'Puan Kazanabilirsiniz!'
                              : 'Yakınızda Puan Var!',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${closest.placeName} — +${closest.points} puan (${closest.formattedDistance})',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (places.length > 1)
                          Text(
                            '+${places.length - 1} mekan daha',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .hintColor
                                          .withAlpha(150),
                                      fontSize: 11,
                                    ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: accentColor,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
