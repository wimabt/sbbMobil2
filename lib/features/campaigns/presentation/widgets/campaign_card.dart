import 'package:flutter/material.dart';

import '../../../../api/api_client.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../models/campaign.dart';

class CampaignCard extends StatelessWidget {
  const CampaignCard({
    super.key,
    required this.campaign,
    required this.isCompleted,
    required this.onTap,
  });

  final Campaign campaign;
  final bool isCompleted;
  final VoidCallback onTap;

  bool get isUpcoming => campaign.campaignStatus == 'upcoming';
  bool get isExpired => campaign.campaignStatus == 'expired';
  bool get isRoute => campaign.type == 'route';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card = Container(
      height: 160,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: isDark
            ? Border.all(color: Colors.white.withAlpha(10))
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _CampaignImage(
            imageUrl: _resolveImageUrl(),
            color: campaign.color,
            isRoute: isRoute,
            isExpired: isExpired,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          campaign.title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                    letterSpacing: -0.2,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(campaign: campaign, isCompleted: isCompleted),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      campaign.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white54 : Colors.black45,
                            height: 1.4,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isRoute) _RouteProgress(campaign: campaign),
                  if (!isRoute) _PlaceAction(campaign: campaign, isCompleted: isCompleted),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isExpired) {
      card = Opacity(opacity: 0.55, child: card);
    }

    return GestureDetector(
      onTap: isUpcoming ? null : onTap,
      child: card,
    );
  }

  String? _resolveImageUrl() {
    final raw = campaign.imageUrl;
    if (raw == null || raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final cmsBase = ApiConfig.current.baseUrl.replaceAll('/api/v1', '');
    final authBase = ApiService.baseUrl.replaceAll('/api/v1', '');
    final baseUrl = isRoute ? authBase : cmsBase;
    return buildImageUrl(raw, baseUrl: baseUrl);
  }
}

class _CampaignImage extends StatelessWidget {
  const _CampaignImage({
    required this.imageUrl,
    required this.color,
    required this.isRoute,
    required this.isExpired,
  });

  final String? imageUrl;
  final Color color;
  final bool isRoute;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget image;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(isDark);
        },
        errorBuilder: (context, error, stack) => _buildPlaceholder(isDark),
      );
    } else {
      image = _buildPlaceholder(isDark);
    }

    if (isExpired) {
      image = ColorFiltered(
        colorFilter:
            const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: image,
      );
    }

    return SizedBox(
      width: 120,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(80),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRoute ? Icons.alt_route_rounded : Icons.place_outlined,
                    size: 11,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isRoute ? 'Rota' : 'Mekan',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? color.withAlpha(30) : color.withAlpha(20),
      child: Center(
        child: Icon(
          isRoute ? Icons.alt_route_rounded : Icons.place_outlined,
          size: 36,
          color: color.withAlpha(120),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.campaign, required this.isCompleted});

  final Campaign campaign;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isExpired = campaign.campaignStatus == 'expired';
    final isUpcoming = campaign.campaignStatus == 'upcoming';

    if (isExpired) {
      return _chip(
        icon: Icons.timer_off_outlined,
        text: 'Süresi Doldu',
        fg: Colors.grey,
        bg: Colors.grey.withAlpha(isDark ? 30 : 20),
      );
    }
    if (isUpcoming) {
      return _chip(
        icon: Icons.lock_outline,
        text: 'Yakında',
        fg: Colors.blueGrey,
        bg: Colors.blueGrey.withAlpha(isDark ? 30 : 20),
      );
    }
    if (campaign.claimed || isCompleted) {
      return _chip(
        icon: Icons.check_circle_rounded,
        text: 'Kazanıldı',
        fg: Colors.green,
        bg: Colors.green.withAlpha(isDark ? 30 : 20),
      );
    }
    return _chip(
      icon: Icons.local_fire_department_rounded,
      text: campaign.daysLeft != null ? '${campaign.daysLeft} gün' : 'Aktif',
      fg: Colors.white,
      gradient: LinearGradient(
        colors: [Colors.orange.shade500, Colors.deepOrange.shade500],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String text,
    required Color fg,
    Color? bg,
    Gradient? gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteProgress extends StatelessWidget {
  const _RouteProgress({required this.campaign});
  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = campaign.progressPercent;

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.alt_route_rounded, size: 13, color: campaign.color),
            const SizedBox(width: 4),
            Text(
              '${campaign.progress} / ${campaign.target} Durak',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: campaign.color,
              ),
            ),
            const Spacer(),
            Text(
              '%${(pct * 100).toInt()}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: campaign.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: isDark
                ? Colors.white.withAlpha(15)
                : Colors.black.withAlpha(8),
            color: campaign.color,
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _RewardBadge(reward: campaign.reward),
          ],
        ),
      ],
    );
  }
}

class _PlaceAction extends StatelessWidget {
  const _PlaceAction({required this.campaign, required this.isCompleted});
  final Campaign campaign;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    if (campaign.claimed || isCompleted) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 15),
          const SizedBox(width: 4),
          const Text(
            'Görev Tamamlandı',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.green,
            ),
          ),
          const Spacer(),
          _RewardBadge(reward: campaign.reward),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: campaign.color.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.near_me_rounded, size: 13, color: campaign.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Hedefe Git & Okut',
                    style: TextStyle(
                      color: campaign.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _RewardBadge(reward: campaign.reward),
      ],
    );
  }
}

class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.reward});
  final String reward;

  @override
  Widget build(BuildContext context) {
    if (reward.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, size: 13, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            reward,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
