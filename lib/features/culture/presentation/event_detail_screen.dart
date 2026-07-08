import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/widgets/circular_icon_button.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../../l10n/l10n.dart';
import 'providers/events_provider.dart';

/// Etkinlik detay ekranı – Events API detay + görüntülenme kaydı
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _viewRecorded = false;

  void _recordView() {
    if (_viewRecorded) return;
    _viewRecorded = true;
    ref.read(eventRepositoryProvider).recordView(widget.id);
    // mobile_analytics_todo.md §2.2 — event_detail_opened
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvents.eventDetailOpened,
      properties: {
        'event_id': widget.id,
        'source': AnalyticsSource.list,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventAsync = ref.watch(eventDetailProvider(widget.id));

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && context.canPop()) context.pop();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: eventAsync.when(
          data: (event) {
            if (event == null) {
              return _buildError(context, isDark, context.l10n.errEventNotFound);
            }
            _recordView();
            return _EventDetailContent(event: event, isDark: isDark);
          },
          loading: () => _buildSkeleton(isDark),
          error: (err, _) => _buildError(context, isDark, err.toString()),
        ),
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircularIconButton(
              icon: Icons.arrow_back,
              backgroundColor: isDark
                  ? Colors.black.withAlpha(102)
                  : Colors.white.withAlpha(230),
              iconColor: isDark ? Colors.white : Colors.black87,
              onPressed: () => context.pop(),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 24,
                  width: 120,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(25)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 32,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(25)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 80,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(25)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, bool isDark, String message) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                CircularIconButton(
                  icon: Icons.arrow_back,
                  backgroundColor: isDark
                      ? Colors.black.withAlpha(102)
                      : Colors.white.withAlpha(230),
                  iconColor: isDark ? Colors.white : Colors.black87,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.pop(),
                      child: const Text('Geri'),
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

class _EventDetailContent extends ConsumerWidget {
  const _EventDetailContent({required this.event, required this.isDark});

  final Event event;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttonBg = isDark
        ? Colors.black.withAlpha(102)
        : Colors.white.withAlpha(230);
    final buttonIcon = isDark ? Colors.white : Colors.black87;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircularIconButton(
              icon: Icons.arrow_back,
              backgroundColor: buttonBg,
              iconColor: buttonIcon,
              onPressed: () => context.pop(),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (event.imageUrl.isNotEmpty)
                  Image.network(
                    event.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholder(isDark),
                  )
                else
                  _placeholder(isDark),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      _badge(context, event.displayCategory,
                          Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      _badge(
                        context,
                        event.isFree ? context.l10n.lblFree : context.l10n.lblPaid,
                        event.isFree ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : null,
                      ),
                ),
                const SizedBox(height: 16),
                _infoRow(
                    context, Icons.calendar_today, '${event.date} • ${event.time}'),
                const SizedBox(height: 8),
                _infoRow(
                    context, Icons.location_on, event.displayLocation),
                if (event.description != null &&
                    event.description!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.lblAbout,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : null,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? Colors.white.withAlpha(200)
                              : Theme.of(context).hintColor,
                          height: 1.4,
                        ),
                  ),
                ],
                // Bilet/Kayıt bölümü
                const SizedBox(height: 24),
                if (event.ticketUrl != null && event.ticketUrl!.isNotEmpty) ...[
                  // Bilet URL'si varsa buton göster
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        // mobile_pending_changes.md PR2 — website_tapped
                        // (event ticket URL'i harici web sitesidir).
                        ref.read(analyticsServiceProvider).track(
                          AnalyticsEvents.websiteTapped,
                          properties: {
                            'entity_type': 'event',
                            'entity_id': event.id,
                            'url': event.ticketUrl!,
                            'context': 'ticket',
                          },
                        );
                        _openUrl(event.ticketUrl!);
                      },
                      icon: const Icon(Icons.confirmation_number_outlined),
                      label: Text(context.l10n.cultureTicketRegistration),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ] else if (event.isFree) ...[
                  // Ücretsiz etkinliklerde bilgilendirici mesaj
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.green.withAlpha(30)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.green.withAlpha(60)
                            : Colors.green.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.cultureFreeEvent,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.green.shade300
                                          : Colors.green.shade800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.cultureFreeEventDesc,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.green.shade200
                                          : Colors.green.shade700,
                                      height: 1.3,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Ücretli ama bilet URL'si yok
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.orange.withAlpha(30)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.orange.withAlpha(60)
                            : Colors.orange.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bilet Bilgisi',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.orange.shade300
                                          : Colors.orange.shade800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.cultureTicketContact,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.orange.shade200
                                          : Colors.orange.shade700,
                                      height: 1.3,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.neonPurple.withAlpha(60), AppColors.darkSurface]
              : [Colors.teal.shade100, Colors.teal.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.event,
          size: 64,
          color: isDark ? AppColors.neonPurple.withAlpha(150) : Colors.teal.shade300,
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(230),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: isDark ? AppColors.neonPurple : Colors.teal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.white.withAlpha(220) : null,
                ),
          ),
        ),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      // URL'yi temizle ve normalize et
      String cleanUrl = url.trim();
      if (cleanUrl.isEmpty) {
        debugPrint('⚠️ [EventDetail] Empty URL');
        return;
      }
      
      // Scheme yoksa https ekle
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      
      final uri = Uri.tryParse(cleanUrl);
      if (uri == null) {
        debugPrint('⚠️ [EventDetail] Invalid URL: $url');
        return;
      }
      
      debugPrint('🌐 [EventDetail] Opening URL: $cleanUrl');
      
      // canLaunchUrl kontrolünü atla ve direkt dene
      // Android'de bazen canLaunchUrl yanlış sonuç verebiliyor
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        debugPrint('✅ [EventDetail] URL launched successfully');
      } catch (e) {
        debugPrint('🔥 [EventDetail] Error launching URL: $e');
        // Alternatif olarak platform channel ile dene
        // Veya kullanıcıya hata mesajı göster
      }
    } catch (e) {
      debugPrint('🔥 [EventDetail] Error opening URL: $e');
    }
  }
}
