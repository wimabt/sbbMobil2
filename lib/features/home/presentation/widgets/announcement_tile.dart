import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/design_tokens.dart';

/// Announcement tile for home screen announcements preview
/// Light Theme: Clean white card with soft shadow
/// Dark Theme: Dark card with subtle border
class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({
    super.key,
    required this.id,
    required this.title,
    required this.excerpt,
    required this.date,
    required this.category,
    this.isNew = false,
    this.isImportant = false,
    this.thumbnailUrl,
    this.onTap,
  });

  final String id;
  final String title;
  final String excerpt;
  final String date;
  final String category;
  final bool isNew;
  final bool isImportant;
  final String? thumbnailUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap ?? () => context.push('/announcements/$id'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: isDark
              ? Border.all(
                  color: Colors.white.withAlpha(10),
                  width: 1,
                )
              : null,
          boxShadow: isDark ? null : AppElevation.level1,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left - Icon with category color
            _buildCategoryIcon(context, isDark),
            const SizedBox(width: AppSpacing.md),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with new badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isImportant) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _buildImportantBadge(context, isDark),
                      ] else if (isNew) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _buildNewBadge(context, isDark),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Excerpt
                  Text(
                    excerpt,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Date and category
                  Row(
                    children: [
                      Text(
                        date,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withAlpha(60)
                              : const Color(0xFF6A6A7A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        category,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.neonCyan
                                  : Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow icon
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark
                  ? Colors.white.withAlpha(60)
                  : const Color(0xFF6A6A7A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(BuildContext context, bool isDark) {
    final iconColor = _getCategoryColor(context, category, isDark);
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withAlpha(isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: isDark
            ? Border.all(
                color: iconColor.withAlpha(40),
                width: 1,
              )
            : null,
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(category),
          size: 20,
          color: iconColor,
        ),
      ),
    );
  }

  Widget _buildNewBadge(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.neonPink.withAlpha(30)
            : AppColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: isDark
            ? Border.all(
                color: AppColors.neonPink.withAlpha(50),
                width: 1,
              )
            : null,
      ),
      child: Text(
        'YENİ',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.neonPink : AppColors.error,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildImportantBadge(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.red.withAlpha(30)
            : Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: isDark
            ? Border.all(
                color: Colors.red.withAlpha(50),
                width: 1,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 10,
            color: isDark ? Colors.redAccent : Colors.red,
          ),
          const SizedBox(width: 2),
          Text(
            'ÖNEMLİ',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.redAccent : Colors.red,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(BuildContext context, String category, bool isDark) {
    switch (category.toLowerCase()) {
      case 'ulaşım':
        return isDark ? const Color(0xFF81C784) : AppColors.accentMap;
      case 'etkinlik':
        return isDark ? AppColors.neonPurple : AppColors.accentCulture;
      case 'belediye':
        return isDark ? AppColors.neonCyan : const Color(0xFF4CAF50);
      case 'çevre':
        return isDark ? const Color(0xFF8BC34A) : const Color(0xFF8BC34A);
      case 'sosyal':
        return isDark ? const Color(0xFFFF9800) : const Color(0xFFFF9800);
      case 'duyuru':
        return isDark ? AppColors.neonCyan : AppColors.accentRoutes;
      default:
        return isDark ? const Color(0xFF81C784) : Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'ulaşım':
        return Icons.directions_bus_outlined;
      case 'etkinlik':
        return Icons.celebration_outlined;
      case 'belediye':
        return Icons.account_balance_outlined;
      case 'çevre':
        return Icons.eco_outlined;
      case 'sosyal':
        return Icons.people_outline;
      case 'duyuru':
        return Icons.campaign_outlined;
      default:
        return Icons.info_outline;
    }
  }
}
