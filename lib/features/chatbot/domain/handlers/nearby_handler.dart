import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/utils/distance_helper.dart';
import '../../../../data/models/place.dart';
import '../../../places/presentation/providers/places_provider.dart';
import '../../data/intent_dictionary.dart';
import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'handler_utils.dart';
import 'intent_handler.dart';

/// "Yakınımdaki yerler" — `nearby_query` intent.
///
/// Veri kaynağı: mevcut `placesProvider.allPlaces` cache (yeni API çağrısı yok).
/// Mesafe: `DistanceHelper.calculateHaversineDistance`.
/// Slot desteği:
///   - `category` → kategori filtresi (varsa)
///   - `distance_km` → radius override (yoksa 5 km)
class NearbyHandler extends IntentHandler {
  const NearbyHandler();

  static const int _maxInline = 3;
  static const double _defaultRadiusKm = 5.0;

  @override
  String get intentName => 'nearby_query';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    // Konum şart — yoksa kullanıcıya nazikçe bildir.
    if (!context.hasLocation) {
      return const ChatResponse(
        text: 'Konumunu henüz alamadım. Konum iznin açıksa harita ekranına '
            'gittiğinde alınır; sonra bana yine sorabilirsin. O zamana kadar '
            'aşağıdakilerle başlayabilirsin:',
        quickReplies: [
          QuickReply(
            label: 'Öne çıkan yerler',
            payload: 'Öne çıkan yerleri göster',
            icon: Icons.star_outline_rounded,
          ),
          QuickReply(
            label: 'Haritayı aç',
            payload: 'Haritayı aç',
            icon: Icons.map_rounded,
            navigateTo: '/map',
          ),
          QuickReply(
            label: 'Yaklaşan etkinlikler',
            payload: 'Yaklaşan etkinlikler',
            icon: Icons.event_rounded,
          ),
        ],
      );
    }

    // Provider lazy-load için kısa polling.
    await waitForData(
      check: () {
        final s = ref.read(placesProvider);
        return !s.isLoading || s.allPlaces.isNotEmpty;
      },
    );

    final allPlaces = ref.read(placesProvider).allPlaces;
    if (allPlaces.isEmpty) {
      return const ChatResponse(
        text: 'Mekan listesi henüz yüklenmedi. Bir saniye sonra tekrar dener '
            'misin?',
      );
    }

    final radius =
        intent.slot<double>('distance_km') ?? _defaultRadiusKm;
    final category = intent.slot<String>('category');

    final origin = LatLng(context.userLatitude!, context.userLongitude!);
    final candidates = <_RankedPlace>[];

    for (final p in allPlaces) {
      if (p.lat == null || p.lng == null) continue;

      // Kategori filtresi
      if (category != null && !_matchesCategory(p, category)) {
        continue;
      }

      final dM = DistanceHelper.calculateHaversineDistance(
        origin,
        LatLng(p.lat!, p.lng!),
      );
      final dKm = dM / 1000.0;
      if (dKm > radius) continue;

      candidates.add(_RankedPlace(place: p, distanceKm: dKm));
    }

    if (candidates.isEmpty) {
      return ChatResponse(
        text: category != null
            ? '${_categoryLabel(category)} kategorisinde yakınında bir yer '
                'bulamadım. Mesafeyi genişletmeyi denemek ister misin?'
            : 'Yakınında bir şey bulamadım. Mesafeyi genişletip bir daha '
                'bakalım mı?',
        quickReplies: const [
          QuickReply(
            label: 'Öne çıkan yerler',
            payload: 'Öne çıkan yerleri göster',
            icon: Icons.star_outline_rounded,
          ),
          QuickReply(
            label: 'Tüm yerleri gör',
            payload: 'Tüm yerleri göster',
            icon: Icons.list_rounded,
            navigateTo: '/places',
          ),
        ],
      );
    }

    candidates.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final shown = candidates.take(_maxInline).toList();
    final hasMore = candidates.length > _maxInline;

    final cards = shown
        .map(
          (rp) => ChatCard(
            type: ChatCardType.place,
            title: rp.place.name,
            subtitle: rp.place.category,
            imageUrl: rp.place.imageUrl,
            trailing: _formatDistance(rp.distanceKm),
            targetRoute: '/places/${rp.place.id}',
            distance: rp.distanceKm,
          ),
        )
        .toList();

    // Combined akıştan geldiyse (örn. "yakındakiler" → "yemek olanlar")
    // mesaj kullanıcının soruyu hatırladığımızı göstermeli.
    final isCombined = intent.slot<String>('_combined_from') != null;
    final headline = category != null
        ? (isCombined
            ? 'Tamam, yakındakiler içinden ${_categoryLabel(category).toLowerCase()} olanları seçtim. '
                '${candidates.length} tane var:'
            : '${_categoryLabel(category)} kategorisinde yakınında ${candidates.length} yer var. '
                'En yakın olanlar:')
        : 'Yakınında ${candidates.length} yer buldum. En yakın olanlar:';

    return ChatResponse(
      text: headline,
      cards: cards,
      quickReplies: [
        if (hasMore)
          const QuickReply(
            label: 'Hepsini haritada gör',
            payload: 'Haritayı aç',
            icon: Icons.map_rounded,
            navigateTo: '/map',
          ),
        const QuickReply(
          label: 'Tüm yerleri gör',
          payload: 'Tüm yerleri göster',
          icon: Icons.list_rounded,
          navigateTo: '/places',
        ),
        const QuickReply(
          label: 'Yemek olanlar',
          payload: 'Yakınımdaki yemek mekanları',
          icon: Icons.restaurant_rounded,
        ),
        const QuickReply(
          label: 'Tarihi olanlar',
          payload: 'Yakınımdaki tarihi yerler',
          icon: Icons.museum_rounded,
        ),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  bool _matchesCategory(Place p, String category) {
    final cat = (p.category ?? '').toLowerCase();
    final tags = p.subcategories.map((s) => s.toLowerCase()).toList();
    final keywords = kCategoryKeywords[category] ?? const [];

    bool textMatches(String haystack) {
      for (final kw in keywords) {
        if (haystack.contains(kw)) return true;
      }
      return false;
    }

    if (textMatches(cat)) return true;
    if (textMatches(p.name.toLowerCase())) return true;
    for (final t in tags) {
      if (textMatches(t)) return true;
    }
    return false;
  }

  String _formatDistance(double km) {
    if (km < 1.0) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  String _categoryLabel(String slug) {
    return switch (slug) {
      'historical' => 'Tarihi',
      'cultural' => 'Kültürel',
      'nature' => 'Doğa',
      'food' => 'Yemek',
      'art' => 'Sanat',
      'shopping' => 'Alışveriş',
      'nightlife' => 'Gece hayatı',
      'religious' => 'Dini',
      _ => slug,
    };
  }
}

class _RankedPlace {
  const _RankedPlace({required this.place, required this.distanceKm});
  final Place place;
  final double distanceKm;
}
