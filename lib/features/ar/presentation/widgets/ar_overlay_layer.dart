import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../data/models/ar_point.dart';
import '../../../../data/models/favorite.dart';
import '../../../../l10n/l10n.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../providers/ar_geo_provider.dart';

/// Şartname §6.8.3.3 + §6.8.3.7 — Kamera/AR sahnesi üzerine bindirilen POI
/// kartları + durum banner'ları + heading bilgisi.
///
/// Bu katman **moddan bağımsızdır**: hem ARCore tabanlı [ArModelScene] hem de
/// (ARCore yoksa) `camera` eklentili fallback arka planı üzerinde **aynı**
/// şekilde render edilir. Kartların yerleşim/çakışma/dikey-hizalama mantığı
/// burada tek noktada tutulur; çağıran ekran yalnızca bir 3B modele dokunma
/// davranışını [onTapModel] ile sağlar (sahneye yerleştir / Scene Viewer aç).
class ArOverlayLayer extends ConsumerWidget {
  const ArOverlayLayer({
    super.key,
    required this.onTapModel,
    this.includeModelCards = false,
  });

  /// `content_type == 'model_3d'` bir karta dokunulduğunda çağrılır
  /// (yalnızca [includeModelCards] true iken — fallback yolu).
  final ValueChanged<ArMatchedPoint> onTapModel;

  /// 3B model POI'leri için kart gösterilsin mi?
  ///   • Birincil (ARCore) modda **false**: model zaten sahneye doğrudan
  ///     yerleştirildiği için kart gösterilmez.
  ///   • Fallback (ARCore yok) modda **true**: 3B model kartı gösterilir,
  ///     dokununca cihazın native AR uygulaması (Scene Viewer/Quick Look) açılır.
  final bool includeModelCards;

  /// Telefon kameralarının tipik yatay görüş açısı (AR overlay stabilliği için
  /// sabit yaklaşım — §6.8.3.3 tolerans açısı).
  static const double _kCameraFovDeg = 65.0;

  /// Tipik telefon dikey görüş açısı (portrait). §6.8.3.2/§6.8.3.7 elevation
  /// açısını ekran dikey konumuna eşlemek için.
  static const double _kCameraVFovDeg = 50.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Geo state'i BURADA izlenir → yalnız bu overlay alt-ağacı ~20Hz rebuild
    // olur; üst ekran (Scaffold/AppBar) ve native ARView etkilenmez.
    final geo = ref.watch(arGeoControllerProvider);
    final theme = Theme.of(context);
    // RepaintBoundary: overlay ~12Hz yenilenirken altındaki native AR/kamera
    // katmanını yeniden rasterize etmesin (paint izolasyonu).
    return RepaintBoundary(
      child: Stack(
      fit: StackFit.expand,
      children: [
        // §6.8.3.7 — kartların okunabilirliği için üst yarıya hafif gradient.
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Colors.black.withAlpha(140), Colors.transparent],
              ),
            ),
          ),
        ),
        // Banner'lar (önizleme / kalibrasyon / GPS).
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          left: 0,
          right: 0,
          child: _StatusBanners(state: geo),
        ),
        // POI kartları (bearing'e göre yatay konumlama).
        if (geo.sensor != null)
          LayoutBuilder(
            builder: (context, constraints) {
              return RepaintBoundary(
                child: Stack(children: _buildOverlayCards(geo, constraints)),
              );
            },
          ),
        // Alt orta — heading bilgi şeridi.
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: _HeadingChip(state: geo, theme: theme),
        ),
      ],
      ),
    );
  }

  List<Widget> _buildOverlayCards(ArGeoState geo, BoxConstraints c) {
    final heading = geo.sensor?.headingDeg;
    if (heading == null) return const [];
    final pitch = geo.sensor?.devicePitchDeg;

    const cardWidth = 220.0;
    final widgets = <Widget>[];
    final placedCenters = <double>[];

    for (final m in geo.matches) {
      if (widgets.length >= kMaxVisibleArItems) break;
      if (!m.inRadius) continue;
      // Birincil (ARCore) modda 3B model kartı gösterilmez — model doğrudan
      // sahneye yerleştirilir. Yalnızca fallback'te kart olarak görünür.
      if (!includeModelCards && m.point.contentType == 'model_3d') continue;
      final delta = _signedDelta(heading, m.bearingFromUserDeg);
      if (delta.abs() > _kCameraFovDeg / 2) continue;

      final norm = delta / (_kCameraFovDeg / 2); // -1..+1
      final left = (c.maxWidth / 2 + norm * (c.maxWidth / 2) - cardWidth / 2)
          .clamp(8.0, c.maxWidth - cardWidth - 8.0);

      final center = left + cardWidth / 2;
      final overlaps =
          placedCenters.any((p) => (p - center).abs() < cardWidth * 0.6);
      if (overlaps) continue;
      placedCenters.add(center);

      final double top;
      if (m.hasElevationData && pitch != null) {
        final vDelta = m.elevationAngleDeg - pitch; // + => POI yukarıda
        final vNorm = (vDelta / (_kCameraVFovDeg / 2)).clamp(-1.0, 1.0);
        final band = (0.335 - vNorm * 0.215).clamp(0.12, 0.55);
        top = c.maxHeight * band;
      } else {
        final t = (m.distanceM / 500.0).clamp(0.0, 1.0);
        top = c.maxHeight * (0.18 + t * 0.18);
      }

      widgets.add(Positioned(
        left: left,
        top: top,
        width: cardWidth,
        child: FloatingPoiCard(match: m, onTapModel: onTapModel),
      ));
    }
    return widgets;
  }

  /// Heading → POI bearing yön farkı, [-180, 180] aralığında, işaretli.
  static double _signedDelta(double heading, double bearing) {
    return (bearing - heading + 540) % 360 - 180;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// POI kartı — kamera üstüne bindirilen yarı saydam içerik
// ═══════════════════════════════════════════════════════════════════════

class FloatingPoiCard extends ConsumerWidget {
  const FloatingPoiCard({
    super.key,
    required this.match,
    required this.onTapModel,
  });

  final ArMatchedPoint match;
  final ValueChanged<ArMatchedPoint> onTapModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggered = match.isTriggered;
    final distLabel = match.distanceM < 1000
        ? '${match.distanceM.toStringAsFixed(0)} m'
        : '${(match.distanceM / 1000).toStringAsFixed(1)} km';
    return Opacity(
      opacity: triggered ? 1.0 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openContent(context, ref),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: triggered
                    ? AppColors.neonBlue.withAlpha(220)
                    : Colors.white.withAlpha(60),
                width: triggered ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _iconForContentType(match.point.contentType),
                      color: triggered ? AppColors.neonBlue : Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        match.point.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.near_me_rounded,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      distLabel,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                    ),
                    const Spacer(),
                    if (match.point.contentType == 'model_3d')
                      const _PillTag(label: '3B', icon: Icons.view_in_ar_rounded)
                    else if (triggered)
                      _PillTag(label: context.l10n.arAligned),
                  ],
                ),
                if (match.point.actions.isNotEmpty && triggered) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final a in match.point.actions.take(2))
                        InkWell(
                          onTap: () => _runAction(context, ref, a),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(35),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border:
                                  Border.all(color: Colors.white.withAlpha(60)),
                            ),
                            child: Text(
                              a.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForContentType(String type) {
    switch (type) {
      case 'model_3d':
        return Icons.view_in_ar_rounded;
      case 'image_2d':
        return Icons.image_rounded;
      case 'audio':
        return Icons.headphones_rounded;
      case 'video':
        return Icons.play_circle_rounded;
      case 'animation':
        return Icons.animation_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  void _openContent(BuildContext context, WidgetRef ref) {
    final p = match.point;
    if (p.contentType == 'model_3d' && (p.modelUrl ?? '').isNotEmpty) {
      // Sayfa değiştirmeden: host sahneye yerleştirir (ARCore) ya da Scene
      // Viewer/Quick Look açar (fallback).
      onTapModel(match);
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            p.title ?? p.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: p.description != null ? Text(p.description!) : null,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.btnClose),
            ),
          ],
        ),
      );
    }
  }

  void _runAction(BuildContext context, WidgetRef ref, ArPointAction action) {
    ref.read(arGeoControllerProvider.notifier).trackAction(match.point, action);
    switch (action.action) {
      case 'open_place':
        final id = action.params['id']?.toString();
        if (id != null) context.push('/places/$id');
        break;
      case 'add_to_itinerary':
        context.push('/itinerary');
        break;
      case 'toggle_favorite':
        if (match.point.placeId != null) {
          ref.read(favoritesProvider.notifier).toggleFavorite(
                FavoriteEntityType.place,
                match.point.placeId!,
              );
        }
        break;
      default:
        break;
    }
  }
}

class _PillTag extends StatelessWidget {
  const _PillTag({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.neonBlue.withAlpha(60),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Üst banner şeridi + alt heading bilgisi
// ═══════════════════════════════════════════════════════════════════════

class _StatusBanners extends StatelessWidget {
  const _StatusBanners({required this.state});

  final ArGeoState state;

  @override
  Widget build(BuildContext context) {
    final sensor = state.sensor;
    final banners = <Widget>[];
    if (state.previewMode) {
      banners.add(_Banner(
        icon: Icons.science_outlined,
        text: context.l10n.arPreviewModeBanner,
        color: Colors.purple,
      ));
    }
    if (sensor != null && !sensor.hasGoodCompass) {
      banners.add(_Banner(
        icon: Icons.explore_off_rounded,
        text: context.l10n.arCompassCalibrationBanner,
        color: Colors.orange,
      ));
    }
    if (sensor != null && !sensor.hasGoodGps) {
      banners.add(_Banner(
        icon: Icons.gps_not_fixed_rounded,
        text: context.l10n
            .arGpsAccuracyBanner(sensor.locationAccuracyM.toStringAsFixed(0)),
        color: Colors.amber,
      ));
    }
    if (banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: banners
          .map((b) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: b,
              ))
          .toList(),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(170),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(140)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadingChip extends StatelessWidget {
  const _HeadingChip({required this.state, required this.theme});

  final ArGeoState state;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final heading = state.sensor?.headingDeg;
    final triggeredCount = state.triggered.length;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: heading != null ? -heading * math.pi / 180 : 0,
              child: const Icon(Icons.navigation_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 6),
            Text(
              heading != null ? '${heading.toStringAsFixed(0)}°' : '...',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              context.l10n.arActiveCount(triggeredCount),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
