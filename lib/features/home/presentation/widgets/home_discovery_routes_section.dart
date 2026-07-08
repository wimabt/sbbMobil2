import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../l10n/l10n.dart';
import '../../../routes/presentation/models/route_data.dart';
import '../../../routes/presentation/providers/routes_provider.dart';

/// Ana sayfada öne çıkan mekanların altında: rotalar ekranıyla aynı `routesProvider` verisi,
/// yatay kaydırmalı “keşif” kartları.
class HomeDiscoveryRoutesSection extends ConsumerWidget {
  const HomeDiscoveryRoutesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routesProvider);
    final routes = state.routes;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.sizeOf(context).width;
    final cardWidth = min(300.0, screenW * 0.82);
    const double listHeight = 200;
    const double sep = AppSpacing.lg;
    const int keepAliveCount = 5;
    final cacheExtent = (cardWidth + sep) * keepAliveCount;

    if (state.error != null && routes.isEmpty && !state.isLoading) {
      return const SizedBox.shrink();
    }

    if (state.isLoading && routes.isEmpty) {
      return _SectionBand(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SectionHeader(
                title: context.l10n.sectionDiscoveryRoutes,
                actionText: context.l10n.btnViewAll,
                onAction: () => context.push('/routes'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                physics: const BouncingScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (context, _) => const SizedBox(width: sep),
                itemBuilder: (context, index) => SizedBox(
                  width: cardWidth,
                  height: listHeight,
                  child: _DiscoveryRouteCardSkeleton(isDark: isDark),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (routes.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SectionBand(
      isDark: isDark,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SectionHeader(
            title: context.l10n.sectionDiscoveryRoutes,
            actionText: context.l10n.btnViewAll,
            onAction: () => context.push('/routes'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            cacheExtent: cacheExtent,
            itemCount: routes.length,
            separatorBuilder: (context, _) => const SizedBox(width: sep),
              itemBuilder: (context, index) {
              final route = routes[index];
              final card = SizedBox(
                width: cardWidth,
                height: listHeight,
                child: _DiscoveryRouteHomeCard(
                  route: route,
                  isDark: isDark,
                ),
              );
              if (index < keepAliveCount) {
                return _KeepAliveDiscoveryCard(child: card);
              }
              return card;
            },
          ),
        ),
      ],
      ),
    );
  }
}

/// Bölüm sarmalayıcı — dikey nefes alanı. Görsel-öncelikli kartlar (öne çıkan
/// mekanlarla aynı dil) sayfa zemininde dursun diye sırıtan gradient/çerçeve
/// bandı kaldırıldı; uygulamanın geneliyle uyumlu, sade durur.
class _SectionBand extends StatelessWidget {
  const _SectionBand({required this.isDark, required this.child});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: child,
    );
  }
}

class _KeepAliveDiscoveryCard extends StatefulWidget {
  const _KeepAliveDiscoveryCard({required this.child});

  final Widget child;

  @override
  State<_KeepAliveDiscoveryCard> createState() =>
      _KeepAliveDiscoveryCardState();
}

class _KeepAliveDiscoveryCardState extends State<_KeepAliveDiscoveryCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Görsel-öncelikli "keşif rotası" hero kartı — öne çıkan mekan kartlarıyla
/// aynı görsel dil: tam-kart kapak görseli + alt karartma gradient'i + üstüne
/// beyaz tipografi. Rotanın kapak fotoğrafını kullanır (önceden hiç gösterilmiyordu).
class _DiscoveryRouteHomeCard extends StatelessWidget {
  const _DiscoveryRouteHomeCard({
    required this.route,
    required this.isDark,
  });

  final TourRoute route;
  final bool isDark;

  IconData get _modeIcon {
    final m = (route.travelMode ?? '').toLowerCase();
    if (m.contains('bike') || m.contains('cycle') || m.contains('bisiklet')) {
      return Icons.directions_bike_rounded;
    }
    if (m.contains('drive') ||
        m.contains('car') ||
        m.contains('vehicle') ||
        m.contains('araç')) {
      return Icons.directions_car_rounded;
    }
    return Icons.directions_walk_rounded;
  }

  bool get _hasCategory =>
      route.category.isNotEmpty &&
      route.category != '-' &&
      route.category != 'ROTA';

  @override
  Widget build(BuildContext context) {
    const radius = AppRadius.xl; // 20px — öne çıkan mekanlarla aynı

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/routes/${route.id}'),
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 80 : 28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1) Kapak görseli
                CachedImage(
                  imageUrl: route.image,
                  fit: BoxFit.cover,
                ),
                // 2) Okunabilirlik için alttan karartma gradient'i
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.32, 1.0],
                      colors: [Colors.transparent, Color(0xE6000000)],
                    ),
                  ),
                ),
                // 3) Üst satır: kategori (sol) + ulaşım modu (sağ) — cam efekti
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Row(
                    children: [
                      if (_hasCategory)
                        _GlassChip(
                          child: Text(
                            route.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      const Spacer(),
                      _GlassChip(
                        circle: true,
                        child: Icon(_modeIcon,
                            color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
                // 4) Alt blok: başlık + meta (mesafe / süre)
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        route.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.3,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          if (route.distance != '-') ...[
                            _OverlayMeta(
                              icon: Icons.straighten_rounded,
                              label: route.distance.toUpperCase(),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                          ],
                          if (route.duration != '-')
                            _OverlayMeta(
                              icon: Icons.schedule_rounded,
                              label: route.duration,
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
      ),
    );
  }
}

/// Görsel üstünde yarı saydam "cam" çip (kategori / mod ikonu).
class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.child, this.circle = false});

  final Widget child;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: circle
          ? const EdgeInsets.all(8)
          : const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(70),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withAlpha(46)),
      ),
      child: child,
    );
  }
}

/// Görsel üstündeki meta satırı (ikon + etiket, beyaz).
class _OverlayMeta extends StatelessWidget {
  const _OverlayMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white.withAlpha(230)),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withAlpha(235),
          ),
        ),
      ],
    );
  }
}

class _DiscoveryRouteCardSkeleton extends StatelessWidget {
  const _DiscoveryRouteCardSkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Görsel-kart iskeleti: tam kart shimmer bloğu + altta başlık/meta hayaleti.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SkeletonLoader(
            width: double.infinity,
            height: double.infinity,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: 180,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: AppSpacing.sm),
                SkeletonLoader(
                  width: 120,
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
