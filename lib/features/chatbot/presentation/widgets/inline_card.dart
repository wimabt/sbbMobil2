import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../data/models/chat_response.dart';

/// Sohbet içinde gösterilen kompakt kart.
///
/// Tek widget — `ChatCard` payload'una göre place/event/recipe/route hepsini render eder.
/// Maks 3 tane üst üste gösterilir; sonrası "Hepsini gör" CTA'sıyla detail ekranına yönlenir.
///
/// **Tasarım:**
/// - 64×64 thumbnail (yoksa fallback ikon)
/// - 2 satır title + 1 satır subtitle
/// - Sağ üstte küçük trailing (mesafe / tarih)
/// - Tap → context.push(targetRoute)
class InlineCard extends StatelessWidget {
  const InlineCard({
    super.key,
    required this.card,
  });

  final ChatCard card;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasRoute = card.targetRoute != null && card.targetRoute!.trim().isNotEmpty;
    // Boş veya bozuk id'li detay rotalarında (örn. "/recipes/") fallback olarak
    // listing ekranını aç. Bu, "Navigator failed" tipi crashları önler.
    final safeRoute = hasRoute ? _safeRouteFor(card.targetRoute!) : null;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxxl + AppSpacing.xs,
        right: AppSpacing.lg,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: hasRoute
              ? () {
                  Haptics.light();
                  if (kDebugMode) {
                    debugPrint('[ChatbotCard] tap → $safeRoute (orig: ${card.targetRoute})');
                  }
                  // Chatbot route shell DIŞINDA olduğundan push yerine go
                  // kullanıyoruz. Kullanıcı detaydan geri çıkınca home shell'i
                  // doğal akışla yüklenir.
                  try {
                    context.go(safeRoute!);
                  } catch (e) {
                    debugPrint('[ChatbotCard] navigation failed: $e');
                    final fallback = _listingFallback(card.targetRoute!);
                    if (fallback != null) context.go(fallback);
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(card: card, colorScheme: colorScheme),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              card.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                                color: colorScheme.onSurface,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (card.trailing != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              card.trailing!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (card.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          card.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: -0.05,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasRoute) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `targetRoute` "/recipes/" gibi boş id'li gelmişse listing'e düşür.
/// Aksi durumda olduğu gibi döndürür.
String? _safeRouteFor(String route) {
  // Boş trailing slash veya tam id'siz pattern
  if (route.endsWith('/')) {
    return _listingFallback(route);
  }
  // `/recipes/   ` gibi whitespace id
  final parts = route.split('/');
  if (parts.isNotEmpty && parts.last.trim().isEmpty) {
    return _listingFallback(route);
  }
  return route;
}

/// `/recipes/123` → `/recipes`, `/places/abc` → `/places` gibi listing
/// ekranına yönlendiren güvenlik fallback'i.
String? _listingFallback(String route) {
  final trimmed = route.endsWith('/') ? route.substring(0, route.length - 1) : route;
  final lastSlash = trimmed.lastIndexOf('/');
  if (lastSlash <= 0) return null;
  return trimmed.substring(0, lastSlash);
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.card, required this.colorScheme});

  final ChatCard card;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    if (card.imageUrl != null && card.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: 56,
          height: 56,
          child: CachedImage(
            imageUrl: card.imageUrl!,
            fit: BoxFit.cover,
            placeholder: _fallbackIcon(colorScheme),
          ),
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: radius,
      ),
      child: _fallbackIcon(colorScheme),
    );
  }

  Widget _fallbackIcon(ColorScheme cs) {
    final icon = card.icon ?? _defaultIconForType(card.type);
    return Icon(icon, color: cs.primary, size: 24);
  }

  IconData _defaultIconForType(ChatCardType type) {
    return switch (type) {
      ChatCardType.place => Icons.place_outlined,
      ChatCardType.event => Icons.event_outlined,
      ChatCardType.recipe => Icons.restaurant_outlined,
      ChatCardType.route => Icons.alt_route_outlined,
      ChatCardType.announcement => Icons.campaign_outlined,
      ChatCardType.gastronomy => Icons.local_dining_outlined,
      ChatCardType.info => Icons.info_outline,
    };
  }
}
