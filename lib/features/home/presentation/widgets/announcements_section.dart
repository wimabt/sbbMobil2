import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/section_header.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../l10n/l10n.dart';
import '../../../announcements/presentation/providers/announcements_provider.dart';
import 'announcement_tile.dart';

/// Announcements section widget for home screen
/// API'den son duyuruları çeker ve gösterir
class AnnouncementsSection extends ConsumerWidget {
  const AnnouncementsSection({
    super.key,
    this.limit = 3,
    this.onViewAll,
  });

  final int limit;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestAnnouncementsProvider);

    return latestAsync.when(
      data: (announcements) {
        if (announcements.isEmpty) {
          return const SizedBox.shrink();
        }

        final displayList = announcements.take(limit).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: context.l10n.sectionAnnouncements,
              actionText: context.l10n.btnViewAll,
              onAction: onViewAll ?? () => context.push('/announcements'),
            ),
            const SizedBox(height: AppSpacing.md),
            ...List.generate(
              displayList.length,
              (index) {
                final announcement = displayList[index];
                final isLast = index == displayList.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
                  child: AnnouncementTile(
                    id: announcement.id,
                    title: announcement.title,
                    excerpt: announcement.excerpt ?? '',
                    date: announcement.relativeDate,
                    category: announcement.category,
                    isNew: announcement.shouldShowNewBadge,
                    isImportant: announcement.isImportant,
                    thumbnailUrl: announcement.thumbnailUrl,
                    onTap: () => context.push(
                      '/announcements/${announcement.id}',
                      extra: announcement,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
      loading: () => const _AnnouncementsSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Skeleton loader for announcements section
class _AnnouncementsSkeleton extends StatelessWidget {
  const _AnnouncementsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: context.l10n.sectionAnnouncements,
          actionText: '',
        ),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(2, (index) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: _AnnouncementTileSkeleton(),
        )),
      ],
    );
  }
}

/// Single announcement tile skeleton
class _AnnouncementTileSkeleton extends StatelessWidget {
  const _AnnouncementTileSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.1))
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge skeleton
                SkeletonLoader(
                  width: 60,
                  height: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: AppSpacing.xs),
                // Title skeleton
                const SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                ),
                const SizedBox(height: AppSpacing.xs),
                // Excerpt skeleton
                const SkeletonLoader(
                  width: double.infinity,
                  height: 12,
                ),
                const SizedBox(height: AppSpacing.xs),
                // Date skeleton
                SkeletonLoader(
                  width: 80,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
