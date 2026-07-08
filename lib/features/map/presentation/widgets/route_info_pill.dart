import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/services/osrm_service.dart';
import '../providers/route_navigation_provider.dart';

/// Floating pill that shows distance & duration of the active route.
///
/// Appears at the bottom-center of the map (above the nav bar) with an
/// animated slide-in / fade-in transition. Fully theme-adaptive:
/// - Light mode: white surface with a soft drop shadow.
/// - Dark mode: dark surface with a subtle 1px border (no shadow).
class RouteInfoPill extends ConsumerWidget {
  const RouteInfoPill({
    super.key,
    required this.placesOnRouteActive,
    required this.onPlacesOnRoutePressed,
    required this.onClosePressed,
  });

  final bool placesOnRouteActive;
  final VoidCallback onPlacesOnRoutePressed;
  final VoidCallback onClosePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeData = ref.watch(routeNavigationProvider);

    return AnimatedOpacity(
      opacity: routeData != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: routeData != null ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: routeData == null,
          child: routeData != null
              ? _buildPill(context, ref, routeData)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildPill(BuildContext context, WidgetRef ref, RouteData routeData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surface;
    final tintColor = isDark
        ? surface.withValues(alpha: 0.95)
        : surface.withValues(alpha: 0.96);
    final borderColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    final durationParts = _parseDuration(routeData.durationMinutes);
    final distanceLabel = _formatDistance(routeData.distanceKm);

    final primaryColor = isDark ? AppColors.neonBlue : colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: tintColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT: Duration + Distance with icon
                Expanded(
                  flex: 5,
                  child: _RouteInfoSection(
                    durationParts: durationParts,
                    distanceLabel: distanceLabel,
                    primaryColor: primaryColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                // MIDDLE: primary action button
                _ExploreButton(
                  active: placesOnRouteActive,
                  onPressed: onPlacesOnRoutePressed,
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                // External maps button (Google/Apple Maps)
                _ExternalMapsButton(
                  routeData: routeData,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                // RIGHT: Close button
                _CloseButton(
                  onPressed: onClosePressed,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns a map with { hours, minutes, totalMinutes } for rich formatting.
  Map<String, int> _parseDuration(double minutes) {
    final totalMinutes = minutes.round();
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return {
      'hours': hours,
      'minutes': mins,
      'totalMinutes': totalMinutes,
    };
  }

  String _formatDistance(double km) {
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }
}

// ─────────────────────────────────────────────────────────────
// Duration + Distance section with rich typography
// ─────────────────────────────────────────────────────────────
class _RouteInfoSection extends StatelessWidget {
  const _RouteInfoSection({
    required this.durationParts,
    required this.distanceLabel,
    required this.primaryColor,
    required this.isDark,
  });

  final Map<String, int> durationParts;
  final String distanceLabel;
  final Color primaryColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final isTr = localeCode == 'tr';
    final hours = durationParts['hours'] ?? 0;
    final mins = durationParts['minutes'] ?? 0;
    final totalMinutes = durationParts['totalMinutes'] ?? 0;

    final onSurface = isDark ? Colors.white : Colors.black87;
    final onSurfaceSecondary =
        isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Duration row ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Small clock icon
            Icon(
              Icons.schedule_rounded,
              size: 18,
              color: primaryColor,
            ),
            const SizedBox(width: 6),
            // Duration text with rich formatting
            if (hours > 0) ...[
              Text(
                '$hours',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  isTr ? 'sa' : 'h',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onSurfaceSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                mins.toString().padLeft(2, '0'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  isTr ? 'dk' : 'min',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onSurfaceSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ] else ...[
              Text(
                '$totalMinutes',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  isTr ? 'dk' : 'min',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onSurfaceSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // ── Distance row ──
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.straighten_rounded,
              size: 14,
              color: onSurfaceSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              distanceLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onSurfaceSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// "Yol Üstü" action button — refined with better proportions
// ─────────────────────────────────────────────────────────────
class _ExploreButton extends StatelessWidget {
  const _ExploreButton({
    required this.active,
    required this.onPressed,
    required this.colorScheme,
    required this.isDark,
  });

  final bool active;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final isTr = localeCode == 'tr';

    final bgColor = active
        ? colorScheme.primaryContainer
        : colorScheme.primary;
    final fgColor = active
        ? colorScheme.onPrimaryContainer
        : colorScheme.onPrimary;

    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            letterSpacing: 0.1,
          ),
        ),
        icon: const Icon(Icons.alt_route_rounded, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            isTr ? 'Yol Üstü' : 'On route',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Close button — circular with subtle background
// ─────────────────────────────────────────────────────────────
class _CloseButton extends StatelessWidget {
  const _CloseButton({
    required this.onPressed,
    required this.isDark,
  });

  final VoidCallback onPressed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.5);

    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: bgColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// External maps button — opens native navigation (Google/Apple)
// ─────────────────────────────────────────────────────────────
class _ExternalMapsButton extends StatelessWidget {
  const _ExternalMapsButton({
    required this.routeData,
    required this.isDark,
  });

  final RouteData routeData;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final iconColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: bgColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _launchExternalMaps,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              Icons.directions_outlined,
              size: 20,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchExternalMaps() async {
    if (routeData.points.isEmpty) return;
    final dest = routeData.points.last;
    final lat = dest.latitude;
    final lng = dest.longitude;

    final googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lng');
    final appleMapsUrl =
        Uri.parse('https://maps.apple.com/?daddr=$lat,$lng');
    final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }
}
