import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/favorite.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../../places/presentation/providers/places_provider.dart';
import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'handler_utils.dart';
import 'intent_handler.dart';

/// "Favorilerim / kaydettiklerim" — `favorites_query` intent.
///
/// İlk 3 favori yer kartı + diğer favorileri özetleyen rakamlar.
class FavoritesHandler extends IntentHandler {
  const FavoritesHandler();

  static const int _maxInline = 3;

  @override
  String get intentName => 'favorites_query';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    await waitForData(
      check: () => !ref.read(favoritesProvider).isLoading,
    );

    final favs = ref.read(favoritesProvider).favorites;
    final totalCount = favs.places.length +
        favs.recipes.length +
        favs.routes.length +
        favs.events.length +
        favs.arPoints.length +
        favs.menus.length;

    if (totalCount == 0) {
      return const ChatResponse(
        text: 'Henüz favorilerine bir şey eklememişsin. '
            'Beğendiğin yerlerin kart üzerindeki kalp ikonuna basabilirsin.',
        quickReplies: [
          QuickReply(
            label: 'Yer öner',
            payload: 'Bana bir yer öner',
            icon: Icons.recommend_rounded,
          ),
          QuickReply(
            label: 'Popüler yerler',
            payload: 'Popüler yerleri göster',
            icon: Icons.star_outline_rounded,
          ),
        ],
      );
    }

    // İlk olarak en çok favorisi olan tipi göster: places
    final allPlaces = ref.read(placesProvider).allPlaces;
    final favPlaceIds = favs.places.map((f) => f.entityId).toSet();
    final favPlaces = allPlaces
        .where((p) => favPlaceIds.contains(p.id))
        .take(_maxInline)
        .toList();

    final cards = favPlaces
        .map(
          (p) => ChatCard(
            type: ChatCardType.place,
            title: p.name,
            subtitle: p.category,
            imageUrl: p.imageUrl,
            targetRoute: '/places/${p.id}',
          ),
        )
        .toList();

    final summary = _summarizeBreakdown(favs);
    return ChatResponse(
      text: cards.isEmpty
          ? 'Favorilerinde $totalCount içerik var. $summary'
          : 'Favorilerinde $totalCount içerik var. '
              'İlk yerlerin:',
      cards: cards,
      followUpHint: cards.isEmpty ? null : summary,
      quickReplies: const [
        QuickReply(
          label: 'Favorilerimi aç',
          payload: 'Favorilerim',
          icon: Icons.favorite_rounded,
          navigateTo: '/favorites',
        ),
        QuickReply(
          label: 'Yeni öneri',
          payload: 'Bana bir yer öner',
          icon: Icons.recommend_rounded,
        ),
      ],
    );
  }

  String _summarizeBreakdown(UserFavorites favs) {
    final parts = <String>[];
    if (favs.places.isNotEmpty) parts.add('${favs.places.length} mekan');
    if (favs.recipes.isNotEmpty) parts.add('${favs.recipes.length} tarif');
    if (favs.routes.isNotEmpty) parts.add('${favs.routes.length} rota');
    if (favs.events.isNotEmpty) parts.add('${favs.events.length} etkinlik');
    if (favs.arPoints.isNotEmpty) parts.add('${favs.arPoints.length} AR');
    if (favs.menus.isNotEmpty) parts.add('${favs.menus.length} lezzet');
    if (parts.isEmpty) return '';
    return 'Dağılım: ${parts.join(' • ')}.';
  }
}
