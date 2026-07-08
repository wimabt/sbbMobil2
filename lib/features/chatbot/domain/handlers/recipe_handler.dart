import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/utils/distance_helper.dart';
import '../../../../data/models/place.dart';
import '../../../places/presentation/providers/places_provider.dart';
import '../../../recipes/presentation/providers/recipes_provider.dart';
import '../../data/intent_dictionary.dart';
import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'handler_utils.dart';
import 'intent_handler.dart';

/// "Yöresel yemek / tarif / restoran / nerede yiyeyim" — `recipe_query` intent.
///
/// İki ayrı niyet tek intent altında toplanıyor; kullanıcının derdine göre
/// ayrılır:
///   - **Dışarıda yemek** ("restoran/lokanta/kafe/nerede yiyebilirim") →
///     gerçek mekânlar (`placesProvider`, food kategorisi), konum varsa
///     mesafeye göre sıralı.
///   - **Tarif/lezzet** ("tarif/yemek tarifi/yöresel lezzet") → `recipesProvider`.
///
/// Bu ayrım, eskiden "nerede yiyebilirim?" sorusuna tarif gösteren davranışı
/// düzeltir (kullanıcı mekân ararken kitap tarifi görmesin).
class RecipeHandler extends IntentHandler {
  const RecipeHandler();

  static const int _maxInline = 3;

  /// "Dışarıda yemek" sinyalleri — bunlar varsa mekân (place) gösterilir.
  static const List<String> _diningKeywords = [
    'restoran', 'restorant', 'lokanta', 'kafe', 'cafe', 'meyhane',
    'nerede yiy', 'nerede yemek', 'yemek yiy', 'yemek nerede', 'yemek mekan',
    'aç', 'acim', 'açım', 'karnım', 'karnim', 'doyur',
  ];

  /// "Tarif" sinyalleri — bunlar varsa kesin tarif gösterilir (dining'i ezer).
  static const List<String> _recipeKeywords = [
    'tarif', 'nasil yapil', 'nasıl yapıl', 'nasil yapar', 'nasıl yapar',
    'malzeme', 'pisir', 'pişir',
  ];

  @override
  String get intentName => 'recipe_query';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    if (_wantsDining(intent)) {
      return _handleDining(context, ref);
    }
    return _handleRecipes(ref);
  }

  // ─── Dışarıda yemek (mekân arama) ─────────────────────────────────────────

  bool _wantsDining(ChatIntent intent) {
    final text = intent.normalizedText;
    // Tarif sinyali her şeyi ezer.
    for (final kw in _recipeKeywords) {
      if (text.contains(kw)) return false;
    }
    for (final kw in _diningKeywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  Future<ChatResponse> _handleDining(ChatContext context, Ref ref) async {
    await waitForData(
      check: () {
        final s = ref.read(placesProvider);
        return !s.isLoading || s.allPlaces.isNotEmpty;
      },
    );

    final allPlaces = ref.read(placesProvider).allPlaces;
    final foodPlaces = allPlaces.where(_isFoodPlace).toList();

    if (foodPlaces.isEmpty) {
      // Mekân bulunamadıysa tarif tarafına nazikçe düş.
      return _handleRecipes(
        ref,
        prefix: 'Yakında listelenmiş bir yemek mekanı bulamadım, '
            'ama yöresel tarifler ilgini çekebilir:',
      );
    }

    final ranked = _rankByDistance(foodPlaces, context);
    final shown = ranked.take(_maxInline).toList();
    final hasMore = ranked.length > _maxInline;

    final cards = shown
        .map(
          (rp) => ChatCard(
            type: ChatCardType.place,
            title: rp.place.name,
            subtitle: rp.place.category,
            imageUrl: rp.place.imageUrl,
            trailing:
                rp.distanceKm == null ? null : _formatDistance(rp.distanceKm!),
            targetRoute: '/places/${rp.place.id}',
            distance: rp.distanceKm,
          ),
        )
        .toList();

    final headline = context.hasLocation
        ? 'Yakınında yemek için ${ranked.length} mekan var. En yakınları:'
        : 'Yemek için ${ranked.length} mekan buldum. İşte öne çıkanlar:';

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
          label: 'Yöresel tarifler',
          payload: 'Samsun yöresel tarifleri',
          icon: Icons.restaurant_menu_rounded,
        ),
      ],
    );
  }

  bool _isFoodPlace(Place p) {
    final keywords = kCategoryKeywords['food'] ?? const [];
    final cat = (p.category ?? '').toLowerCase();
    final name = p.name.toLowerCase();
    final tags = p.subcategories.map((s) => s.toLowerCase());
    for (final kw in keywords) {
      if (cat.contains(kw) || name.contains(kw)) return true;
      for (final t in tags) {
        if (t.contains(kw)) return true;
      }
    }
    return false;
  }

  List<_RankedPlace> _rankByDistance(List<Place> places, ChatContext context) {
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
        ..sort((a, b) => (a.distanceKm ?? double.infinity)
            .compareTo(b.distanceKm ?? double.infinity));
      return ranked;
    }
    final ranked = places.toList()
      ..sort((a, b) {
        if (a.featured != b.featured) return a.featured ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    return ranked.map((p) => _RankedPlace(place: p, distanceKm: null)).toList();
  }

  String _formatDistance(double km) {
    if (km.isInfinite) return '';
    if (km < 1.0) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  // ─── Tarif tarafı (orijinal davranış) ─────────────────────────────────────

  Future<ChatResponse> _handleRecipes(Ref ref, {String? prefix}) async {
    await waitForData(
      check: () {
        final s = ref.read(recipesProvider);
        return !s.isLoading || s.recipes.isNotEmpty;
      },
    );

    final all = ref.read(recipesProvider).recipes;
    if (all.isEmpty) {
      return const ChatResponse(
        text: 'Şu an yüklü tarifim yok. Birazdan tekrar dener misin?',
        quickReplies: [
          QuickReply(
            label: 'Yer öner',
            payload: 'Yemek için yer öner',
            icon: Icons.restaurant_rounded,
          ),
          QuickReply(
            label: 'Yakındakiler',
            payload: 'Yakınımdaki yerler',
            icon: Icons.near_me_rounded,
          ),
        ],
      );
    }

    // ID'si boş tarifleri filtrele — Navigator failed önlemek için.
    final safeRecipes = all.where((r) => r.id.trim().isNotEmpty).toList();
    final shown = safeRecipes.take(_maxInline).toList();
    final hasMore = safeRecipes.length > _maxInline;

    final cards = shown
        .map(
          (r) => ChatCard(
            type: ChatCardType.recipe,
            title: r.title,
            subtitle: r.category,
            imageUrl: r.imageUrl,
            targetRoute: '/recipes/${r.id}',
          ),
        )
        .toList();

    return ChatResponse(
      text: prefix ??
          'Samsun\'un yöresel tariflerinden ${safeRecipes.length} tane var. '
              'İlk üçü:',
      cards: cards,
      quickReplies: [
        if (hasMore)
          const QuickReply(
            label: 'Tüm tarifler',
            payload: 'Tüm tarifleri göster',
            icon: Icons.list_rounded,
            navigateTo: '/recipes',
          ),
        const QuickReply(
          label: 'Nerede yiyebilirim?',
          payload: 'Yakınımda nerede yemek yiyebilirim?',
          icon: Icons.local_dining_rounded,
        ),
        const QuickReply(
          label: 'Haritada göster',
          payload: 'Haritayı aç',
          icon: Icons.map_rounded,
          navigateTo: '/map',
        ),
      ],
    );
  }
}

class _RankedPlace {
  const _RankedPlace({required this.place, this.distanceKm});
  final Place place;
  final double? distanceKm;
}
