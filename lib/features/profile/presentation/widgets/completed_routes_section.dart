import 'package:flutter/material.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../models/completed_route.dart';

/// Completed routes section widget for profile screen.
///
/// Shows a max of 3 routes with a consistent uppercase section header
/// and a "Tümünü Gör" (View All) text button aligned to the right.
class CompletedRoutesSection extends StatelessWidget {
  const CompletedRoutesSection({
    super.key,
    required this.routes,
    this.onRouteTap,
    this.onViewAll,
    this.maxItems = 3,
  });

  final List<CompletedRoute> routes;
  final void Function(CompletedRoute route)? onRouteTap;

  /// Callback when "View All" is tapped. If null, the button is hidden.
  final VoidCallback? onViewAll;

  /// Maximum number of items to show (default 3).
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final displayedRoutes = routes.take(maxItems).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header row ──
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    context.l10n.sectionCompletedRoutes.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: isDark
                          ? AppColors.textSecondaryDark.withAlpha(180)
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ),
              if (onViewAll != null || routes.length > maxItems)
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.l10n.btnViewAll,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: isDark
                          ? AppColors.neonBlue
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...displayedRoutes.map((route) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onRouteTap?.call(route),
                    borderRadius: BorderRadius.circular(16),
                    splashColor: isDark
                        ? AppColors.neonBlue.withAlpha(12)
                        : theme.colorScheme.primary.withAlpha(12),
                    highlightColor: isDark
                        ? AppColors.neonBlue.withAlpha(6)
                        : theme.colorScheme.primary.withAlpha(6),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isDark
                            ? Border.all(
                                color: Colors.white.withAlpha(10),
                                width: 1,
                              )
                            : null,
                        boxShadow: isDark
                            ? [
                                BoxShadow(
                                  color: AppColors.neonPurple.withAlpha(10),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withAlpha(6),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.neonCyan.withAlpha(25)
                                  : theme.colorScheme.secondaryContainer
                                      .withAlpha(76),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.check_circle_outline,
                              color: isDark
                                  ? AppColors.neonCyan
                                  : theme.colorScheme.secondary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  route.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${route.places} mekan • ${route.distance} • ${route.date}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? Colors.white.withAlpha(120)
                                        : theme.hintColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: isDark
                                ? Colors.white.withAlpha(50)
                                : theme.hintColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
