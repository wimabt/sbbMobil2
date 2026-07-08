import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routes/presentation/providers/routes_provider.dart';
import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'handler_utils.dart';
import 'intent_handler.dart';

/// "Rota öner / gezi rotası" — `route_query` intent.
///
/// Veri: `routesProvider` cache. Featured + isim sırasına göre üst 3.
class RouteHandler extends IntentHandler {
  const RouteHandler();

  static const int _maxInline = 3;

  @override
  String get intentName => 'route_query';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    await waitForData(
      check: () {
        final s = ref.read(routesProvider);
        return !s.isLoading || s.routes.isNotEmpty;
      },
    );

    final state = ref.read(routesProvider);
    final routes = state.routes;

    if (routes.isEmpty) {
      return const ChatResponse(
        text: 'Şu an yüklü hazır rotam yok. Birazdan tekrar dener misin?',
        quickReplies: [
          QuickReply(
            label: 'Yer öner',
            payload: 'Bana bir yer öner',
            icon: Icons.recommend_rounded,
          ),
          QuickReply(
            label: 'Yakındakiler',
            payload: 'Yakınımdaki yerler',
            icon: Icons.near_me_rounded,
          ),
        ],
      );
    }

    final shown = routes.take(_maxInline).toList();
    final hasMore = routes.length > _maxInline;

    final cards = shown
        .map(
          (r) => ChatCard(
            type: ChatCardType.route,
            title: r.title,
            subtitle: r.category,
            imageUrl: r.image,
            trailing: r.distance,
            targetRoute: '/routes/${r.id}',
          ),
        )
        .toList();

    return ChatResponse(
      text: 'Senin için ${routes.length} hazır rota var. '
          'En çok önerdiklerim:',
      cards: cards,
      quickReplies: [
        if (hasMore)
          const QuickReply(
            label: 'Tüm rotalar',
            payload: 'Tüm rotalar',
            icon: Icons.list_rounded,
            navigateTo: '/routes',
          ),
        const QuickReply(
          label: 'Gezi planı yap',
          payload: 'Gezi planı oluşturmak istiyorum',
          icon: Icons.event_note_rounded,
          navigateTo: '/itinerary',
        ),
        const QuickReply(
          label: 'Yakındakiler',
          payload: 'Yakınımdaki yerler',
          icon: Icons.near_me_rounded,
        ),
      ],
    );
  }
}
