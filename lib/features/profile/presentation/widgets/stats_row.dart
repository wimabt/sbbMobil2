import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/design/design_tokens.dart';
import 'stat_card.dart';

/// Stats row widget for profile screen.
///
/// The "Puan" (Points) card is marked as [isPrimary] to draw more
/// attention — it uses a vibrant amber/gold icon for a metallic feel.
class StatsRow extends StatelessWidget {
  const StatsRow({
    super.key,
    required this.points,
    required this.visits,
    required this.routes,
  });

  final String points;
  final String visits;
  final String routes;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Vibrant metallic gold for Points icon — works well on both themes
    const metallicGold = Color(0xFFFFA726); // Orange 400
    const metallicGoldDark = Color(0xFFFFB74D); // Warm Amber

    // Points/gamification feature flag — Puan kartı gizlendiğinde Ziyaret +
    // Rota iki kart kalır ve eşit genişlikte yayılır.
    final showPoints = FeatureFlags.pointsEnabled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          if (showPoints) ...[
            Expanded(
              child: StatCard(
                icon: Icons.emoji_events_rounded,
                iconColor: isDark ? metallicGoldDark : metallicGold,
                value: points,
                label: context.l10n.lblPoints,
                isPrimary: true,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: StatCard(
              icon: Icons.place_outlined,
              iconColor: isDark
                  ? AppColors.neonBlue
                  : Theme.of(context).colorScheme.primary,
              value: visits,
              label: 'Ziyaret',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.route_outlined,
              iconColor: isDark
                  ? AppColors.neonPurple
                  : Theme.of(context).colorScheme.secondary,
              value: routes,
              label: context.l10n.lblRoutesDone,
            ),
          ),
        ],
      ),
    );
  }
}
