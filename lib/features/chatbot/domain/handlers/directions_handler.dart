import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../places/presentation/providers/places_provider.dart';
import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import '../nlu/text_normalizer.dart';
import 'handler_utils.dart';
import 'intent_handler.dart';

/// "Oraya nasıl giderim / X'e nasıl giderim" — `directions` intent.
///
/// Strateji: Hedef yer adı varsa place_repository'den eşleştirip detail
/// sayfasına yönlendir (oradan harita / OSRM mevcut). Yoksa harita ekranını aç.
class DirectionsHandler extends IntentHandler {
  const DirectionsHandler();

  @override
  String get intentName => 'directions';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    final hint = intent.slot<String>('place_hint');

    if (hint != null) {
      await waitForData(
        check: () {
          final s = ref.read(placesProvider);
          return !s.isLoading || s.allPlaces.isNotEmpty;
        },
      );
    }

    final allPlaces = ref.read(placesProvider).allPlaces;

    if (hint != null && allPlaces.isNotEmpty) {
      final hintNorm = TextNormalizer.normalize(hint);
      final match = allPlaces.firstWhere(
        (p) => TextNormalizer.normalize(p.name).contains(hintNorm),
        orElse: () => allPlaces.first,
      );
      // Eşleşme bulunduysa
      final foundName = TextNormalizer.normalize(match.name).contains(hintNorm);
      if (foundName) {
        return ChatResponse(
          text: '${match.name}\'a yönlendiriyorum. Detay sayfasından harita ve '
              'yol tarifi alabilirsin.',
          cards: [
            ChatCard(
              type: ChatCardType.place,
              title: match.name,
              subtitle: match.category,
              imageUrl: match.imageUrl,
              targetRoute: '/places/${match.id}',
            ),
          ],
          quickReplies: const [
            QuickReply(
              label: 'Haritayı aç',
              payload: 'Haritayı aç',
              icon: Icons.map_rounded,
              navigateTo: '/map',
            ),
            QuickReply(
              label: 'Başka yer ara',
              payload: 'Bana bir yer öner',
              icon: Icons.search_rounded,
            ),
          ],
        );
      }
    }

    // Genel "nasıl giderim" — harita ekranına yönlendir
    return const ChatResponse(
      text: 'Hangi yere gitmek istiyorsun? İsmi yazarsan tam tarifi vereyim. '
          'Ya da haritayı açıp yer seçebilirsin.',
      quickReplies: [
        QuickReply(
          label: 'Haritayı aç',
          payload: 'Haritayı aç',
          icon: Icons.map_rounded,
          navigateTo: '/map',
        ),
        QuickReply(
          label: 'Yakındakiler',
          payload: 'Yakınımdaki yerler',
          icon: Icons.near_me_rounded,
        ),
      ],
    );
  }
}
