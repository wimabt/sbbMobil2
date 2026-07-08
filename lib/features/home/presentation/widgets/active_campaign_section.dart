import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../campaigns/presentation/models/campaign.dart';
import '../../../campaigns/presentation/providers/campaigns_provider.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../places/presentation/providers/places_provider.dart';
import '../../../../api/api_client.dart';

/// Data class for home campaign cards
class HomeCampaignItem {
  const HomeCampaignItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.progress,
    required this.target,
    required this.reward,
    required this.color,
  });

  final String id;
  final String title;
  final String imageUrl;
  final int progress;
  final int target;
  final String reward;
  final Color color;
}

/// Active campaigns section widget for home screen
/// Light Theme: Clean white cards with soft shadows
/// Dark Theme: Dark cards with subtle borders and neon accents
class ActiveCampaignSection extends ConsumerWidget {
  const ActiveCampaignSection({
    super.key,
    this.onViewAll,
  });

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsState = ref.watch(campaignsProvider);
    final placesCache = ref.watch(placesProvider.select((s) => s.allPlaces));
    final l10n = context.l10n;

    final items = campaignsState.activeCampaigns
        .map<HomeCampaignItem>(
          (c) => _mapCampaignToHomeItem(c, placesCache),
        )
        .toList();

    if (campaignsState.isLoading && items.isEmpty) {
      // Home'da boş loading state yerine sadece header gösteriyoruz
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.sectionActiveCampaigns,
            actionText: l10n.btnViewAll,
            onAction: onViewAll ?? () => context.push('/campaigns'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      );
    }

    if (items.isEmpty) {
      // Boş / hata durumunda Home'da tamamen gizlemek yerine,
      // kullanıcıya en azından bölüm başlığını ve durum mesajını göster.
      final hasError = (campaignsState.error != null &&
          campaignsState.error!.trim().isNotEmpty);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.sectionActiveCampaigns,
            actionText: hasError ? l10n.btnRetry : l10n.btnViewAll,
            onAction: () {
              if (hasError) {
                // Avoid awaiting here; this section can be disposed during navigation
                // and we only need to trigger a refresh.
                Future.microtask(
                  () => ref
                      .read(campaignsProvider.notifier)
                      .loadCampaigns(refresh: true),
                );
              } else {
                context.push('/campaigns');
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasError
                ? 'Kampanyalar yüklenemedi. Yenilemeyi deneyin.'
                : 'Şu anda aktif kampanya bulunamadı.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
        ],
      );
    }

    final showCount = items.length.clamp(0, 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.sectionActiveCampaigns,
          actionText: l10n.btnViewAll,
          onAction: onViewAll ?? () => context.push('/campaigns'),
        ),
        const SizedBox(height: AppSpacing.md),
        // shrinkWrap ListView bazen fazladan alt boşluk bırakıyor; az öğe için Column kullan.
        ...List.generate(
          showCount,
          (index) {
            final campaign = items[index];
            final isLast = index == showCount - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: _HomeCampaignCard(
                campaign: campaign,
                onTap: () => context.push('/campaigns/${campaign.id}'),
              ),
            );
          },
        ),
      ],
    );
  }

  HomeCampaignItem _mapCampaignToHomeItem(
    Campaign c,
    List<dynamic> placesCache,
  ) {
    // Rota kampanyası: görsel doğrudan kampanya response'undan gelir.
    // Place kampanyası: mümkünse CMS cache'inden (placesProvider) kendi kapağını kullan.
    String? rawImage = c.imageUrl;

    if (!c.isRoute) {
      final placeId = c.externalPlaceId ?? c.id;
      final matched = placesCache.cast<dynamic>().firstWhere(
            (p) => (p as dynamic).id?.toString() == placeId,
            orElse: () => null,
          );
      if (matched != null) {
        rawImage = (matched as dynamic).imageUrl?.toString() ?? rawImage;
      }
    }

    // Base URL seçimi:
    // - place (CMS): ApiConfig.current.baseUrl (api/v1 kırpılmış)
    // - route (auth veya full url): ApiService.baseUrl (api/v1 kırpılmış)
    final cmsBase = ApiConfig.current.baseUrl.replaceAll('/api/v1', '');
    final authBase = ApiService.baseUrl.replaceAll('/api/v1', '');
    final baseUrl = c.isRoute ? authBase : cmsBase;

    final resolvedImage =
        rawImage != null ? buildImageUrl(rawImage, baseUrl: baseUrl) : null;

    return HomeCampaignItem(
      id: c.id,
      title: c.title,
      imageUrl: resolvedImage ?? 'assets/images/place-historic.jpg',
      progress: c.progress,
      target: c.target,
      reward: c.reward.isNotEmpty ? c.reward : 'Puan kazan',
      color: c.color,
    );
  }
}

/// Horizontal campaign card with image on left
class _HomeCampaignCard extends StatefulWidget {
  const _HomeCampaignCard({
    required this.campaign,
    required this.onTap,
  });

  final HomeCampaignItem campaign;
  final VoidCallback onTap;

  @override
  State<_HomeCampaignCard> createState() => _HomeCampaignCardState();
}

class _HomeCampaignCardState extends State<_HomeCampaignCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final campaign = widget.campaign;
    final isCompleted = campaign.target > 0 && campaign.progress >= campaign.target;
    
    // Get accent color based on theme
    final accentColor = isCompleted
        ? Colors.green
        : (isDark ? _getNeonColor(campaign.color) : campaign.color);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: isDark
                ? Border.all(
                    color: Colors.white.withAlpha(12),
                    width: 1,
                  )
                : null,
            boxShadow: isDark ? null : AppElevation.level2,
          ),
          child: Row(
            children: [
              // Left - Image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.xl),
                  bottomLeft: Radius.circular(AppRadius.xl),
                ),
                child: SizedBox(
                  width: 100,
                  height: 110,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCampaignImage(context, campaign.imageUrl, accentColor),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              (isDark ? AppColors.darkSurface : AppColors.lightSurface).withAlpha(40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right - Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        campaign.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Reward badge
                      Row(
                        children: [
                          Icon(
                            isCompleted ? Icons.check_circle : Icons.diamond_outlined,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            campaign.reward,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Progress text
                      Text(
                        '${campaign.progress} / ${campaign.target} adım',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white.withAlpha(180)
                                  : Theme.of(context).hintColor,
                              fontSize: 11,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Step progress
                      _buildStepProgress(context, campaign, accentColor, isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepProgress(BuildContext context, HomeCampaignItem campaign, Color accentColor, bool isDark) {
    return Row(
      children: List.generate(campaign.target, (index) {
        final isActive = index < campaign.progress;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < campaign.target - 1 ? 3 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive
                  ? accentColor
                  : (isDark
                      ? Colors.white.withAlpha(20)
                      : Theme.of(context).colorScheme.surfaceContainerHighest),
              borderRadius: BorderRadius.circular(2),
              boxShadow: isActive && isDark
                  ? [
                      BoxShadow(
                        color: accentColor.withAlpha(60),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Color _getNeonColor(Color originalColor) {
    if (originalColor.toARGB32() == const Color(0xFF4A90E2).toARGB32() ||
        originalColor.toARGB32() == AppColors.brandGreen.toARGB32()) {
      return const Color(0xFF81C784);
    }
    if (originalColor.toARGB32() == const Color(0xFF26A69A).toARGB32()) {
      return AppColors.neonCyan;
    }
    return const Color(0xFF81C784);
  }

  Widget _buildCampaignImage(
    BuildContext context,
    String imageUrl,
    Color accentColor,
  ) {
    final isAsset = imageUrl.startsWith('assets/');

    if (isAsset) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(accentColor),
      );
    }

    // ✅ PERFORMANCE: CachedImage ile disk + memory cache
    return CachedImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: 100,
      height: 110,
      fadeInDuration: const Duration(milliseconds: 200),
      errorWidget: _buildFallback(accentColor),
    );
  }

  Widget _buildFallback(Color accentColor) {
    return Container(
      color: accentColor.withAlpha(30),
      child: Icon(
        Icons.campaign_outlined,
        color: accentColor,
        size: 32,
      ),
    );
  }
}
