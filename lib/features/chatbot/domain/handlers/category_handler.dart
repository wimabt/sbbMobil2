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

/// "Tarihi yerler öner / müze öner / doğa keşfi" — `category_query` intent.
///
/// Slot `category` zorunlu — yoksa kullanıcıya seçim sun.
/// Konum varsa mesafeye göre sıralanır; yoksa featured + isim sırasına göre.
class CategoryHandler extends IntentHandler {
  const CategoryHandler();

  static const int _maxInline = 3;

  @override
  String get intentName => 'category_query';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    final category = intent.slot<String>('category');
    final featured = intent.slot<bool>('featured') ?? false;

    // Hem kategori hem featured boşsa kullanıcıya seçim sun.
    if (category == null && !featured) {
      return const ChatResponse(
        text: 'Tabii, hangi kategoride yer öneririm?',
        quickReplies: [
          QuickReply(
            label: 'Öne çıkanlar',
            payload: 'Öne çıkan yerleri göster',
            icon: Icons.star_outline_rounded,
          ),
          QuickReply(
            label: 'Tarihi',
            payload: 'Tarihi yerler öner',
            icon: Icons.museum_rounded,
          ),
          QuickReply(
            label: 'Doğa',
            payload: 'Doğa yerleri öner',
            icon: Icons.park_rounded,
          ),
          QuickReply(
            label: 'Yemek',
            payload: 'Yöresel yemek nerede',
            icon: Icons.restaurant_rounded,
          ),
        ],
      );
    }

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

    // İki filtre kombine: kategori (varsa) AND featured (varsa).
    Iterable<Place> filteredPlaces = allPlaces;
    if (category != null) {
      filteredPlaces = filteredPlaces.where((p) => _matchesCategory(p, category));
    }
    if (featured) {
      filteredPlaces = filteredPlaces.where((p) => p.featured);
    }
    final filtered = filteredPlaces.toList();

    if (filtered.isEmpty) {
      final headlineEmpty = category != null
          ? '${_categoryLabel(category)} kategorisinde uygun bir yer bulamadım.'
          : 'Şu an öne çıkardığım bir yer bulamadım.';
      return ChatResponse(
        text: '$headlineEmpty Başka bir kategori dener misin?',
        quickReplies: const [
          QuickReply(
            label: 'Tarihi',
            payload: 'Tarihi yerler',
            icon: Icons.museum_rounded,
          ),
          QuickReply(
            label: 'Doğa',
            payload: 'Doğa yerleri',
            icon: Icons.park_rounded,
          ),
          QuickReply(
            label: 'Tüm yerler',
            payload: 'Tüm yerler',
            icon: Icons.list_rounded,
            navigateTo: '/places',
          ),
        ],
      );
    }

    // Sıralama: konum varsa mesafe, yoksa featured + isim
    final ranked = _rank(filtered, context);
    final shown = ranked.take(_maxInline).toList();
    final hasMore = ranked.length > _maxInline;

    final cards = shown.map((rp) {
      return ChatCard(
        type: ChatCardType.place,
        title: rp.place.name,
        subtitle: rp.place.category,
        imageUrl: rp.place.imageUrl,
        trailing: rp.distanceKm == null ? null : _formatDistance(rp.distanceKm!),
        targetRoute: '/places/${rp.place.id}',
        distance: rp.distanceKm,
      );
    }).toList();

    final headline = _composeHeadline(
      category: category,
      featured: featured,
      total: ranked.length,
      shownCount: shown.length,
    );

    return ChatResponse(
      text: headline,
      cards: cards,
      quickReplies: [
        if (hasMore)
          const QuickReply(
            label: 'Tümünü gör',
            payload: 'Tüm yerler',
            icon: Icons.list_rounded,
            navigateTo: '/places',
          ),
        const QuickReply(
          label: 'Haritada göster',
          payload: 'Haritayı aç',
          icon: Icons.map_rounded,
          navigateTo: '/map',
        ),
        const QuickReply(
          label: 'Başka kategori',
          payload: 'Başka bir kategori öner',
          icon: Icons.swap_horiz_rounded,
        ),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  bool _matchesCategory(Place p, String category) {
    final keywords = kCategoryKeywords[category] ?? const [];
    final cat = (p.category ?? '').toLowerCase();
    final name = p.name.toLowerCase();
    final tags = p.subcategories.map((s) => s.toLowerCase()).toList();

    for (final kw in keywords) {
      if (cat.contains(kw) || name.contains(kw)) return true;
      for (final t in tags) {
        if (t.contains(kw)) return true;
      }
    }
    return false;
  }

  List<_RankedPlace> _rank(List<Place> places, ChatContext context) {
    if (context.hasLocation) {
      final origin = LatLng(context.userLatitude!, context.userLongitude!);
      final ranked = places.map((p) {
        if (p.lat == null || p.lng == null) {
          return _RankedPlace(place: p, distanceKm: double.infinity);
        }
        final dM = DistanceHelper.calculateHaversineDistance(
          origin,
          LatLng(p.lat!, p.lng!),
        );
        return _RankedPlace(place: p, distanceKm: dM / 1000.0);
      }).toList()
        ..sort((a, b) =>
            (a.distanceKm ?? double.infinity)
                .compareTo(b.distanceKm ?? double.infinity));
      return ranked;
    }

    // Konum yok — featured öncelikli, sonra isim
    final ranked = places.toList()
      ..sort((a, b) {
        if (a.featured != b.featured) {
          return a.featured ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });
    return ranked.map((p) => _RankedPlace(place: p, distanceKm: null)).toList();
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

  /// Sorgunun katmanlarına göre uygun başlık üret.
  ///
  /// - sadece category → "Tarihi kategorisinde 12 yer var..."
  /// - sadece featured → "Öne çıkan 7 yer var..."
  /// - ikisi de → "Öne çıkan tarihi yerlerden 4 tane var..."
  String _composeHeadline({
    String? category,
    required bool featured,
    required int total,
    required int shownCount,
  }) {
    if (featured && category != null) {
      return 'Öne çıkan ${_categoryLabel(category).toLowerCase()} yerlerinden '
          '$total tane var. İlk $shownCount\'ünü seçtim:';
    }
    if (featured) {
      return 'Öne çıkan $total yer var. İlk $shownCount\'ünü seçtim:';
    }
    // category != null garantili çünkü daha yukarıda kontrol var
    return '${_categoryLabel(category!)} kategorisinde $total yer var. '
        'Sana $shownCount\'ini seçtim:';
  }
}

class _RankedPlace {
  const _RankedPlace({required this.place, this.distanceKm});
  final Place place;
  final double? distanceKm;
}
