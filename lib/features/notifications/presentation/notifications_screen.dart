import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/navigation_utils.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../../l10n/l10n.dart';
import 'providers/notification_badge_provider.dart';
import 'providers/notifications_provider.dart';

/// Bildirimler sayfası — push (bildirim) olarak gönderilmiş duyuruların listesi.
///
/// Okundu durumu KULLANICIYA GÖSTERİLMEZ (talep gereği). Bir bildirime
/// dokunulduğunda duyuru detayına gidilir ve tıklama analitiği kaydedilir.
///
/// Sayfa görüntülenince ana sayfadaki "okunmamış bildirim" noktası temizlenir
/// (en yeni bildirimin zamanı "görüldü" olarak işaretlenir).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markedSeen = false;

  /// Liste yüklendiğinde bir kez çağrılır: en yeni bildirimi "görüldü" işaretler.
  void _markSeenOnce(List<Announcement> items) {
    if (_markedSeen) return;
    _markedSeen = true;
    final newest = newestNotificationMillis(items);
    // Build içinde değil, frame sonrası tetikle (provider mutasyonu güvenli).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationBadgeProvider.notifier).markAllSeen(newest);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncNotifications = ref.watch(notificationsProvider);

    // Veri geldiyse görüldü işaretle (boş liste de "görüldü" sayılır:
    // okunmamış nokta varsa ama liste boşsa noktayı kapat).
    asyncNotifications.whenData(_markSeenOnce);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.titleNotifications),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.popOrHome(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(notificationsProvider.future),
        child: asyncNotifications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
          data: (items) {
            if (items.isEmpty) return const _EmptyState();
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _NotificationCard(
                  announcement: item,
                  onTap: () => _openDetail(context, ref, item),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    Announcement announcement,
  ) async {
    // Tıklama analitiği (best-effort, fire-and-forget).
    () async {
      try {
        final subId =
            await ref.read(notificationProvider.notifier).getSubscriptionId();
        await ref
            .read(announcementRepositoryProvider)
            .recordNotificationClick(announcement.id, oneSignalSubId: subId);
      } catch (_) {/* analitik kritik değil */}
    }();

    if (!context.mounted) return;
    context.push('/announcements/${announcement.id}', extra: announcement);
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.announcement, required this.onTap});

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = announcement.thumbnailUrl ?? announcement.imageUrl;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: thumb != null && thumb.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Icon(
                          Icons.notifications_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        announcement.isImportant
                            ? Icons.priority_high_rounded
                            : Icons.notifications_outlined,
                        color: theme.colorScheme.primary,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (announcement.isImportant)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.error_outline,
                              size: 16,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            announcement.title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (announcement.excerpt != null &&
                        announcement.excerpt!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        announcement.excerpt!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (announcement.categoryName != null &&
                            announcement.categoryName!.isNotEmpty) ...[
                          Text(
                            announcement.categoryName!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('·', style: theme.textTheme.labelSmall),
                          ),
                        ],
                        Text(
                          announcement.relativeDate,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(Icons.notifications_off_outlined,
            size: 64, color: theme.hintColor),
        const SizedBox(height: 16),
        Text(
          context.l10n.lblNoNotifications,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            context.l10n.lblNoNotificationsDesc,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const Icon(Icons.error_outline, size: 56),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.btnRetry),
          ),
        ),
      ],
    );
  }
}
