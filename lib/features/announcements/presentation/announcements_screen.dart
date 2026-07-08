import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/pre_permission_sheet.dart';
import '../../../core/services/notification_prefs_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/design/design_tokens.dart';
import '../../../data/models/models.dart';
import '../../../l10n/l10n.dart';
import 'providers/announcements_provider.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // NOT: loadMore artık gerekli değil - tüm veriler ilk yüklemede çekiliyor
  // Infinite scroll kaldırıldı, kullanıcı tüm listeyi görebilir

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(announcementsProvider);
    // Push bildirimleri açık mı? Gerçek (kalıcı + OneSignal) tercihe bağlı.
    // "Bildirimler kapalı" uyarı banner'ı yalnızca push kapalıyken görünür.
    final pushEnabled = ref.watch(notificationPrefsProvider).general;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                floating: true,
                pinned: false,
                expandedHeight: 220,
                backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                elevation: 0,
                forceElevated: innerBoxIsScrolled,
                automaticallyImplyLeading: false,
                toolbarHeight: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: _AnnouncementsHeader(state: state),
                ),
              ),
            ),
          ];
        },
        body: Builder(
          builder: (context) {
            return RefreshIndicator(
              onRefresh: () => ref.read(announcementsProvider.notifier).refresh(),
              child: CustomScrollView(
                slivers: [
                  SliverOverlapInjector(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  ),
                  // Content
                  // NOT: allAnnouncements cache olarak kullanılıyor - loading ve empty kontrolü ona göre
                  if (state.isLoading && state.allAnnouncements.isEmpty)
                    const SliverFillRemaining(
                      child: _AnnouncementsLoadingSkeleton(),
                    )
                  else if (state.error != null && state.allAnnouncements.isEmpty)
                    SliverFillRemaining(
                      child: _AnnouncementsError(error: state.error!),
                    )
                  else if (state.allAnnouncements.isEmpty && !state.isLoading)
                    // Veri yok ve loading değil - empty state göster
                    const SliverFillRemaining(
                      child: _EmptyState(isNoData: true),
                    )
                  else if (state.filteredAnnouncements.isEmpty)
                    // Filtre sonucu boş - filtre empty state
                    const SliverFillRemaining(
                      child: _EmptyState(isNoData: false),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            // Notification banner at top
                            if (index == 0 && !pushEnabled) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _NotificationBanner(isDark: isDark),
                                  _buildResultCount(context, state, isDark),
                                ],
                              );
                            }

                            // Adjust index for notification banner
                            final adjustedIndex = !pushEnabled ? index - 1 : index;

                            // Result count at top
                            if (adjustedIndex == -1 || (pushEnabled && index == 0)) {
                              return _buildResultCount(context, state, isDark);
                            }

                            final announcementIndex = index - 1;

                            if (announcementIndex < 0 || announcementIndex >= state.filteredAnnouncements.length) {
                              return null;
                            }

                            final announcement = state.filteredAnnouncements[announcementIndex];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _AnnouncementCard(
                                announcement: announcement,
                                onTap: () => context.push(
                                  '/announcements/${announcement.id}',
                                  extra: announcement,
                                ),
                              ),
                            );
                          },
                          childCount: state.filteredAnnouncements.length + 1 +
                              (pushEnabled ? 0 : 1),
                        ),
                      ),
                    ),
                  // NOT: isLoadingMore kaldırıldı - tüm veriler ilk yüklemede çekiliyor
                  SliverToBoxAdapter(
                    child: SizedBox(height: AppNavBar.bottomPadding),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultCount(BuildContext context, AnnouncementsState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        '${state.filteredAnnouncements.length} duyuru bulundu',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isDark ? Colors.white.withAlpha(150) : Theme.of(context).hintColor,
        ),
      ),
    );
  }
}

class _AnnouncementsHeader extends ConsumerWidget {
  const _AnnouncementsHeader({required this.state});

  final AnnouncementsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(announcementsProvider.notifier);
    // Zil ikonu gerçek push tercihini (kalıcı + OneSignal) yansıtır.
    final pushEnabled = ref.watch(notificationPrefsProvider).general;

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.titleAnnouncements,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          letterSpacing: -0.3,
                        ),
                  ),
                  IconButton(
                    tooltip: pushEnabled
                        ? context.l10n.announcementsMuteTooltip
                        : context.l10n.announcementsUnmuteTooltip,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? (pushEnabled
                                ? AppColors.neonBlue.withAlpha(30)
                                : Colors.white.withAlpha(15))
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: isDark
                            ? Border.all(
                                color: pushEnabled
                                    ? AppColors.neonBlue.withAlpha(60)
                                    : Colors.white.withAlpha(20),
                              )
                            : null,
                      ),
                      child: Icon(
                        pushEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color: pushEnabled
                            ? (isDark ? AppColors.neonBlue : Theme.of(context).colorScheme.primary)
                            : (isDark ? Colors.white.withAlpha(150) : Theme.of(context).hintColor),
                      ),
                    ),
                    onPressed: () => _togglePushNotifications(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search bar
              AppSearchBar(
                hintText: context.l10n.lblSearchAnnouncements,
                onChanged: notifier.search,
              ),
              const SizedBox(height: 12),
              // Category pills
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.categories.length + 1, // +1 for "Tümü"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // "Tümü" option
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: CategoryPill(
                          label: context.l10n.lblAll,
                          isActive: state.selectedCategoryId == null,
                          onTap: () => notifier.setCategory(null),
                        ),
                      );
                    }
                    final cat = state.categories[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: CategoryPill(
                        label: cat.name,
                        isActive: state.selectedCategoryId == cat.id,
                        onTap: () => notifier.setCategory(cat.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Zil ikonuna basınca push bildirimlerini sessize alır / açar.
  ///
  /// • Sessize alma serbesttir → kalıcı tercih kapatılır (OneSignal opt-out) ve
  ///   "Geri Al" eylemli bir snackbar gösterilir.
  /// • Açma, gerçek OS iznini garanti eder (ayar ekranıyla aynı ön-izin akışı):
  ///   izin yoksa önce [PrePermissionSheet], ardından OS isteği; izin verilmezse
  ///   tercih AÇILMAZ (toggle'ın "açık ama bildirim gelmiyor" durumunu önler).
  Future<void> _togglePushNotifications(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final prefsNotifier = ref.read(notificationPrefsProvider.notifier);
    final pushNotifier = ref.read(notificationProvider.notifier);
    final currentlyEnabled = ref.read(notificationPrefsProvider).general;
    // Async sınırları aşmadan önce context'e bağımlıları yakala.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    if (currentlyEnabled) {
      // ── Sessize al ──────────────────────────────────────────────────────
      await prefsNotifier.setGeneral(false);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.announcementsMutedSnack),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: l10n.btnUndo,
            // İzin zaten verilmişti → doğrudan tekrar aç.
            onPressed: () => prefsNotifier.setGeneral(true),
          ),
        ),
      );
      return;
    }

    // ── Aç (gerçek OS iznini garanti et) ─────────────────────────────────
    var granted = ref.read(notificationProvider).hasPushPermission;
    if (!granted) {
      final proceed = await PrePermissionSheet.show(
        context,
        PrePermissionKind.notification,
      );
      if (!proceed) return;
      granted = await pushNotifier.requestPushPermission();
    }
    if (!granted) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.dlgNotifPermissionBody),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await prefsNotifier.setGeneral(true);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.announcementsUnmutedSnack),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.neonPink.withAlpha(20)
            : Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.neonPink.withAlpha(50)
              : Theme.of(context).colorScheme.error.withAlpha(51),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_off,
            color: isDark ? AppColors.neonPink : Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bildirimler kapalı. Önemli duyuruları kaçırabilirsiniz.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white.withAlpha(180) : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementsLoadingSkeleton extends StatelessWidget {
  const _AnnouncementsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) => Padding(
          padding: EdgeInsets.only(bottom: index < 2 ? 16 : 0),
          child: _AnnouncementCardSkeleton(isDark: isDark),
        )),
      ),
    );
  }
}

class _AnnouncementCardSkeleton extends StatelessWidget {
  const _AnnouncementCardSkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: isDark ? Border.all(color: Colors.white.withAlpha(10)) : null,
        boxShadow: isDark ? null : AppElevation.level1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail skeleton
          SkeletonLoader(
            width: 80,
            height: 80,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          const SizedBox(width: 12),
          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge skeleton
                SkeletonLoader(
                  width: 60,
                  height: 20,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                const SizedBox(height: 8),
                // Title skeleton
                const SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                ),
                const SizedBox(height: 4),
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: 16,
                ),
                const SizedBox(height: 8),
                // Excerpt skeleton
                const SkeletonLoader(
                  width: double.infinity,
                  height: 12,
                ),
                const SizedBox(height: 8),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.isNoData = false});

  /// true: Hiç duyuru yok (API'den veri gelmedi)
  /// false: Filtre sonucu boş
  final bool isNoData;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(10) : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNoData ? Icons.notifications_off_outlined : Icons.campaign_outlined,
                size: 40,
                color: isDark ? Colors.white.withAlpha(60) : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isNoData ? 'Henüz Duyuru Yok' : 'Duyuru Bulunamadı',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isNoData 
                  ? 'Şu anda görüntülenecek duyuru bulunmuyor.\nDaha sonra tekrar kontrol edin.'
                  : 'Arama kriterlerinize uygun duyuru bulunamadı.\nFarklı bir arama yapın veya filtreleri temizleyin.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : Theme.of(context).hintColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementsError extends ConsumerWidget {
  const _AnnouncementsError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
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
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white60 : Theme.of(context).hintColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(announcementsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.btnRetry),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced announcement card with thumbnail support
class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.onTap,
  });

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = announcement.thumbnailUrl != null || announcement.imageUrl != null;
    final imageUrl = announcement.thumbnailUrl ?? announcement.imageUrl;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: isDark ? Border.all(color: Colors.white.withAlpha(10)) : null,
          boxShadow: isDark ? null : AppElevation.level1,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image (if available)
              if (hasImage)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                      ),
                      // Gradient overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withAlpha(120),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Badges on image
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Row(
                          children: [
                            _buildCategoryBadge(context, isDark),
                            if (announcement.isImportant) ...[
                              const SizedBox(width: 8),
                              _buildImportantBadge(context),
                            ] else if (announcement.shouldShowNewBadge) ...[
                              const SizedBox(width: 8),
                              _buildNewBadge(context),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges (if no image)
                    if (!hasImage)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            BadgeChip(label: announcement.category),
                            if (announcement.isImportant) ...[
                              const SizedBox(width: 8),
                              BadgeChipVariants.important(context),
                            ] else if (announcement.shouldShowNewBadge) ...[
                              const SizedBox(width: 8),
                              BadgeChipVariants.newBadge(context),
                            ],
                          ],
                        ),
                      ),
                    
                    // Title
                    Text(
                      announcement.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    if (announcement.excerpt != null) ...[
                      const SizedBox(height: 8),
                      // Excerpt
                      Text(
                        announcement.excerpt!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Theme.of(context).hintColor,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    
                    // Footer - Date and view count
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isDark ? AppColors.neonCyan : Theme.of(context).hintColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          announcement.relativeDate,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Theme.of(context).hintColor,
                            fontSize: 11,
                          ),
                        ),
                        if (announcement.viewCount != null && announcement.viewCount! > 0) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: isDark ? Colors.white.withAlpha(102) : Theme.of(context).hintColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatViewCount(announcement.viewCount!),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white.withAlpha(102) : Theme.of(context).hintColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: isDark ? Colors.white30 : Colors.grey[400],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        announcement.category,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildImportantBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Önemli',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.neonPink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Yeni',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
