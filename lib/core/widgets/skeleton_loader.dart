import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../design/design_tokens.dart';
import 'section_header.dart';

// =============================================================================
// SkeletonAnimationScope — Birden fazla SkeletonLoader tek AnimationController
// paylaşır. 15 bağımsız controller yerine 1 tane, pil ve CPU tasarrufu.
// Scope olmadan SkeletonLoader kendi controller'ını oluşturur (standalone uyum).
// =============================================================================

/// Paylaşılan shimmer animasyonu sağlayan scope widget.
/// Bu widget'ın altındaki tüm SkeletonLoader'lar tek AnimationController kullanır.
class SkeletonAnimationScope extends StatefulWidget {
  const SkeletonAnimationScope({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonAnimationScope> createState() => _SkeletonAnimationScopeState();
}

class _SkeletonAnimationScopeState extends State<SkeletonAnimationScope>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonAnimationData(
      animation: _animation,
      child: widget.child,
    );
  }
}

/// InheritedWidget ile animasyonu alt ağaca yayar.
class _SkeletonAnimationData extends InheritedWidget {
  const _SkeletonAnimationData({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SkeletonAnimationData>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(_SkeletonAnimationData oldWidget) => false;
}

/// Skeleton loader widget with shimmer effect
/// Used for ghost loading states while data is being fetched.
/// 
/// SkeletonAnimationScope altındaysa paylaşılan animasyonu kullanır.
/// Scope dışındaysa kendi AnimationController'ını oluşturur.
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.margin,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final EdgeInsets? margin;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  AnimationController? _ownController;
  Animation<double>? _ownAnimation;

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  Animation<double> _getAnimation(BuildContext context) {
    // Scope'tan paylaşılan animasyonu al (varsa)
    final shared = _SkeletonAnimationData.maybeOf(context);
    if (shared != null) return shared;

    // Scope yoksa kendi controller'ını oluştur (geriye uyumluluk)
    if (_ownController == null) {
      _ownController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..repeat();
      _ownAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
        CurvedAnimation(parent: _ownController!, curve: Curves.linear),
      );
    }
    return _ownAnimation!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animation = _getAnimation(context);
    
    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(AppRadius.xl),
        color: isDark
            ? AppColors.darkSurfaceElevated
            : Colors.grey[200],
      ),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(AppRadius.xl),
            child: CustomPaint(
              painter: _ShimmerPainter(
                animationValue: animation.value,
                isDark: isDark,
              ),
              child: Container(),
            ),
          );
        },
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({
    required this.animationValue,
    required this.isDark,
  });

  final double animationValue;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Base color
    final baseColor = isDark
        ? AppColors.darkSurfaceElevated
        : Colors.grey[200]!;
    
    // Shimmer highlight color - more visible for better feedback
    final highlightColor = isDark
        ? Colors.grey.withAlpha(101) // More visible for dark theme (~20% opacity)
        : Colors.grey.withAlpha(230); // More visible for light theme (~80% opacity)
    
    // Draw base
    final basePaint = Paint()..color = baseColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);
    
    // Draw shimmer effect - sağdan sola animasyon
    final shimmerWidth = size.width * 0.6; // Shimmer genişliği
    final shimmerStart = (animationValue + 1.0) * size.width * 1.2 - shimmerWidth * 0.5;
    
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          baseColor,
          highlightColor,
          highlightColor,
          baseColor,
        ],
        stops: const [0.0, 0.3, 0.7, 1.0], // Daha belirgin gradient
      ).createShader(
        Rect.fromLTWH(
          shimmerStart.clamp(-shimmerWidth, size.width + shimmerWidth),
          0,
          shimmerWidth,
          size.height,
        ),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      shimmerPaint,
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Featured place skeleton card for loading state
class FeaturedPlaceSkeleton extends StatelessWidget {
  const FeaturedPlaceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: isDark
            ? Border.all(
                color: Colors.white.withAlpha(15),
                width: 1,
              )
            : null,
        boxShadow: isDark ? null : AppElevation.featuredCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SkeletonLoader(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.zero,
                ),
                // Category badge skeleton
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: SkeletonLoader(
                    width: 60,
                    height: 20,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ],
            ),
          ),
          // Content skeleton
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title skeleton
                  SkeletonLoader(
                    width: double.infinity,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  SkeletonLoader(
                    width: 100,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Distance skeleton
                  SkeletonLoader(
                    width: 60,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Featured places section skeleton
class FeaturedPlacesSkeleton extends StatelessWidget {
  const FeaturedPlacesSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    // SkeletonAnimationScope: Tüm skeleton'lar tek AnimationController paylaşır
    // 15 bağımsız controller → 1 paylaşılan controller (pil + CPU tasarrufu)
    return SkeletonAnimationScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: context.l10n.sectionFeaturedPlaces,
            actionText: 'Tümünü Gör',
            onAction: () {}, // Disabled during loading
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: count,
              separatorBuilder: (context, _) => const SizedBox(width: AppSpacing.lg),
              itemBuilder: (context, index) => const FeaturedPlaceSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PLACES SCREEN SKELETON (P2 U5)
// =============================================================================

/// Tek bir place list card iskeleti
class _PlaceCardSkeleton extends StatelessWidget {
  const _PlaceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Thumbnail
          SkeletonLoader(
            width: 72,
            height: 72,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                SkeletonLoader(
                  width: 120,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
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

/// Places ekranı için tam sayfa skeleton yükleyici
class PlacesListSkeleton extends StatelessWidget {
  const PlacesListSkeleton({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonAnimationScope(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 104),
        itemBuilder: (_, _) => const _PlaceCardSkeleton(),
      ),
    );
  }
}

// =============================================================================
// CAMPAIGNS SCREEN SKELETON (P2 U5)
// =============================================================================

/// Tek bir kampanya kartı iskeleti
class _CampaignCardSkeleton extends StatelessWidget {
  const _CampaignCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner image
          SkeletonLoader(
            width: double.infinity,
            height: 140,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          const SizedBox(height: AppSpacing.md),
          // Title
          SkeletonLoader(
            width: double.infinity,
            height: 18,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Subtitle
          SkeletonLoader(
            width: 200,
            height: 14,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Progress bar
          SkeletonLoader(
            width: double.infinity,
            height: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

/// Kampanyalar ekranı için skeleton yükleyici
class CampaignsSkeleton extends StatelessWidget {
  const CampaignsSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonAnimationScope(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
        itemBuilder: (_, _) => const _CampaignCardSkeleton(),
      ),
    );
  }
}

// =============================================================================
// ROUTES SCREEN SKELETON (P2 U5)
// =============================================================================

/// Tek bir rota kartı iskeleti
class _RouteCardSkeleton extends StatelessWidget {
  const _RouteCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          SkeletonLoader(
            width: double.infinity,
            height: 180,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          const SizedBox(height: AppSpacing.md),
          // Title
          SkeletonLoader(
            width: double.infinity,
            height: 18,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Meta row (distance · duration · stops)
          Row(
            children: [
              SkeletonLoader(
                width: 60,
                height: 12,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(width: AppSpacing.sm),
              SkeletonLoader(
                width: 60,
                height: 12,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(width: AppSpacing.sm),
              SkeletonLoader(
                width: 60,
                height: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rotalar ekranı için skeleton yükleyici
class RoutesSkeleton extends StatelessWidget {
  const RoutesSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonAnimationScope(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
        itemBuilder: (_, _) => const _RouteCardSkeleton(),
      ),
    );
  }
}

