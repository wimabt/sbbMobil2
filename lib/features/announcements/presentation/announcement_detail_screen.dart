import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/navigation_utils.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../../l10n/l10n.dart';
import 'providers/announcements_provider.dart';

class AnnouncementDetailScreen extends ConsumerWidget {
  const AnnouncementDetailScreen({
    super.key,
    required this.id,
    this.announcement,
  });

  final String id;
  /// Eğer liste'den geçirildiyse direkt kullan, yoksa API'den çek
  final dynamic announcement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Eğer announcement objesi geçirildiyse direkt kullan
    if (announcement != null && announcement is Announcement) {
      return PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) context.popOrHome();
        },
        child: Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: _AnnouncementDetailContent(
            announcement: announcement as Announcement,
            isDark: isDark,
          ),
        ),
      );
    }
    
    // Yoksa API'den çekmeye çalış
    final announcementAsync = ref.watch(announcementDetailProvider(id));

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.popOrHome();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: announcementAsync.when(
          data: (fetchedAnnouncement) {
            if (fetchedAnnouncement == null) {
              return _buildErrorWidget(context, isDark, context.l10n.errAnnouncementNotFound);
            }
            return _AnnouncementDetailContent(
              announcement: fetchedAnnouncement,
              isDark: isDark,
            );
          },
          loading: () => _AnnouncementDetailSkeleton(isDark: isDark),
          error: (error, _) => _buildErrorWidget(context, isDark, error.toString()),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, bool isDark, String message) {
    return SafeArea(
      child: Column(
        children: [
          // App bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
          // Error content
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 40,
                        color: Colors.red[400],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bir hata oluştu',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : null,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Theme.of(context).hintColor,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: Text(context.l10n.btnGoBack),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementDetailContent extends StatelessWidget {
  const _AnnouncementDetailContent({
    required this.announcement,
    required this.isDark,
  });

  final Announcement announcement;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hasImage = announcement.imageUrl != null;

    return CustomScrollView(
      slivers: [
        // Hero Image AppBar
        SliverAppBar(
          expandedHeight: hasImage ? 300 : 0,
          pinned: true,
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          flexibleSpace: hasImage
              ? FlexibleSpaceBar(
                  background: _HeroImage(
                    imageUrl: announcement.imageUrl!,
                    isDark: isDark,
                  ),
                )
              : null,
          automaticallyImplyLeading: false,
          leading: _BackButton(isDark: isDark),
        ),

        // Content
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Badges row
              _BadgesRow(announcement: announcement, isDark: isDark),

              const SizedBox(height: 16),

              // Title
              Text(
                announcement.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      letterSpacing: -0.3,
                      height: 1.3,
                    ),
              ),

              const SizedBox(height: 16),

              // Meta info
              _MetaInfoRow(announcement: announcement, isDark: isDark),

              const SizedBox(height: 24),

              // Decorative divider
              _DecorativeDivider(isDark: isDark),

              const SizedBox(height: 24),

              // Content
              _ContentSection(
                announcement: announcement,
                isDark: isDark,
              ),

              // Tags
              if (announcement.tags.isNotEmpty) ...[
                const SizedBox(height: 32),
                _TagsSection(tags: announcement.tags, isDark: isDark),
              ],

              SizedBox(height: AppNavBar.bottomPadding + 16),
            ]),
          ),
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.imageUrl,
    required this.isDark,
  });

  final String imageUrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: isDark ? AppColors.darkSurfaceElevated : Colors.grey[300],
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 64,
              color: isDark ? Colors.white30 : Colors.grey,
            ),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: isDark ? AppColors.darkSurfaceElevated : Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppGradients.heroOverlayDark
                : LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(180),
                      Colors.black.withAlpha(50),
                      Colors.transparent,
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurface.withAlpha(230)
              : Colors.white.withAlpha(230),
          shape: BoxShape.circle,
          border: isDark ? Border.all(color: Colors.white.withAlpha(30)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
        ),
      ),
      onPressed: () => context.pop(),
    );
  }
}

class _BadgesRow extends StatelessWidget {
  const _BadgesRow({
    required this.announcement,
    required this.isDark,
  });

  final Announcement announcement;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Category badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? _getCategoryColor().withAlpha(30)
                : _getCategoryColor().withAlpha(20),
            borderRadius: BorderRadius.circular(999),
            border: isDark
                ? Border.all(color: _getCategoryColor().withAlpha(60))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCategoryIcon(),
                size: 14,
                color: _getCategoryColor(),
              ),
              const SizedBox(width: 6),
              Text(
                announcement.category,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getCategoryColor(),
                ),
              ),
            ],
          ),
        ),
        // Important badge
        if (announcement.isImportant)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(20),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.red.withAlpha(50)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: isDark ? Colors.redAccent : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  'Önemli Duyuru',
                  style: TextStyle(
                    color: isDark ? Colors.redAccent : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        // New badge
        else if (announcement.shouldShowNewBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.neonPink.withAlpha(26)
                  : Colors.blue.withAlpha(20),
              borderRadius: BorderRadius.circular(999),
              border: isDark
                  ? Border.all(color: AppColors.neonPink.withAlpha(50))
                  : Border.all(color: Colors.blue.withAlpha(50)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fiber_new_rounded,
                  size: 14,
                  color: isDark ? AppColors.neonPink : Colors.blue,
                ),
                const SizedBox(width: 6),
                Text(
                  'Yeni',
                  style: TextStyle(
                    color: isDark ? AppColors.neonPink : Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _getCategoryColor() {
    switch (announcement.category.toLowerCase()) {
      case 'ulaşım':
        return const Color(0xFF2196F3);
      case 'etkinlik':
        return const Color(0xFF9C27B0);
      case 'belediye':
        return const Color(0xFF4CAF50);
      case 'çevre':
        return const Color(0xFF8BC34A);
      case 'sosyal':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF2196F3);
    }
  }

  IconData _getCategoryIcon() {
    switch (announcement.category.toLowerCase()) {
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
      default:
        return Icons.campaign_outlined;
    }
  }
}

class _MetaInfoRow extends StatelessWidget {
  const _MetaInfoRow({
    required this.announcement,
    required this.isDark,
  });

  final Announcement announcement;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Date
          _MetaItem(
            icon: Icons.access_time,
            label: announcement.relativeDate,
            isDark: isDark,
          ),
          if (announcement.authorName != null) ...[
            _MetaDivider(isDark: isDark),
            _MetaItem(
              icon: Icons.person_outline,
              label: announcement.authorName!,
              isDark: isDark,
            ),
          ],
          if (announcement.viewCount != null && announcement.viewCount! > 0) ...[
            _MetaDivider(isDark: isDark),
            _MetaItem(
              icon: Icons.visibility_outlined,
              label: context.l10n.lblViewCount(announcement.viewCount!),
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.neonCyan : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white70 : Theme.of(context).hintColor,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaDivider extends StatelessWidget {
  const _MetaDivider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: isDark ? Colors.white.withAlpha(20) : Colors.grey.withAlpha(30),
    );
  }
}

class _DecorativeDivider extends StatelessWidget {
  const _DecorativeDivider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 4,
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [AppColors.neonBlue, AppColors.neonPurple],
              )
            : null,
        color: isDark ? null : Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: AppColors.neonBlue.withAlpha(40),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({
    required this.announcement,
    required this.isDark,
  });

  final Announcement announcement;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final content = announcement.content ?? announcement.excerpt ?? '';
    
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if content is HTML
    if (content.contains('<p>') || 
        content.contains('<br') || 
        content.contains('<ul>') ||
        content.contains('<div>')) {
      return Html(
        data: content,
        style: {
          'body': Style(
            color: isDark ? Colors.white.withAlpha(200) : null,
            lineHeight: const LineHeight(1.8),
            fontSize: FontSize(15),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          'p': Style(
            margin: Margins.only(bottom: 16),
          ),
          'ul': Style(
            margin: Margins.only(left: 16, bottom: 16),
          ),
          'ol': Style(
            margin: Margins.only(left: 16, bottom: 16),
          ),
          'li': Style(
            margin: Margins.only(bottom: 8),
          ),
          'h1': Style(
            fontSize: FontSize(22),
            fontWeight: FontWeight.bold,
            margin: Margins.only(top: 24, bottom: 12),
          ),
          'h2': Style(
            fontSize: FontSize(20),
            fontWeight: FontWeight.bold,
            margin: Margins.only(top: 20, bottom: 10),
          ),
          'h3': Style(
            fontSize: FontSize(18),
            fontWeight: FontWeight.w600,
            margin: Margins.only(top: 16, bottom: 8),
          ),
          'a': Style(
            color: isDark ? AppColors.neonCyan : Theme.of(context).colorScheme.primary,
            textDecoration: TextDecoration.underline,
          ),
          'strong': Style(
            fontWeight: FontWeight.w600,
          ),
          'blockquote': Style(
            padding: HtmlPaddings.only(left: 16),
            margin: Margins.only(left: 0, top: 16, bottom: 16),
            border: Border(
              left: BorderSide(
                color: isDark ? AppColors.neonCyan : Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
            fontStyle: FontStyle.italic,
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
        },
      );
    }

    // Plain text with paragraph support
    return Text(
      content,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.8,
            color: isDark ? Colors.white.withAlpha(200) : null,
            fontSize: 15,
          ),
    );
  }
}

class _TagsSection extends StatelessWidget {
  const _TagsSection({
    required this.tags,
    required this.isDark,
  });

  final List<String> tags;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.lblTags,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
                border: isDark
                    ? Border.all(color: Colors.white.withAlpha(20))
                    : null,
              ),
              child: Text(
                '#$tag',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.neonCyan : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AnnouncementDetailSkeleton extends StatelessWidget {
  const _AnnouncementDetailSkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // App bar skeleton
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: isDark ? AppColors.darkSurfaceElevated : Colors.grey[200],
            ),
          ),
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: SkeletonLoader(
              width: 40,
              height: 40,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        // Content skeleton
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Badge skeleton
              SkeletonLoader(
                width: 100,
                height: 28,
                borderRadius: BorderRadius.circular(14),
              ),
              const SizedBox(height: 16),
              // Title skeleton
              const SkeletonLoader(width: double.infinity, height: 28),
              const SizedBox(height: 8),
              SkeletonLoader(width: MediaQuery.of(context).size.width * 0.7, height: 28),
              const SizedBox(height: 16),
              // Meta skeleton
              SkeletonLoader(
                width: double.infinity,
                height: 50,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 24),
              // Divider skeleton
              SkeletonLoader(
                width: double.infinity,
                height: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 24),
              // Content skeleton
              ...List.generate(6, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ]),
          ),
        ),
      ],
    );
  }
}
