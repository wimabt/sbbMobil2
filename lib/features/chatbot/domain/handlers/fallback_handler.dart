import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'intent_handler.dart';

/// Niyet anlaşılamadığında devreye girer.
///
/// **Strateji:** Kullanıcıya "tam anlamadım" demek yerine, doğrudan
/// 4 yaygın intent'e yönlendiren quick reply göster — kullanıcı yorulmasın,
/// 1 tap'la istediği yere ulaşsın.
class FallbackHandler extends IntentHandler {
  const FallbackHandler();

  static const List<String> _variations = [
    'Tam olarak anlayamadım, ama şunlardan birini deneyebilirsiniz:',
    'Henüz bunu öğrenmedim. Şunlardan biri ilgini çekebilir:',
    'Bu konuda biraz daha açıklayabilir misiniz? Belki şunları arıyorsunuz:',
  ];

  @override
  String get intentName => 'fallback';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    // Mesaj çeşitliliği için saat bazlı pseudo-random seçim.
    final idx = DateTime.now().second % _variations.length;

    return ChatResponse(
      text: _variations[idx],
      quickReplies: const [
        QuickReply(
          label: 'Yakınımdaki yerler',
          payload: 'Yakınımdaki yerleri göster',
          icon: Icons.near_me_rounded,
        ),
        QuickReply(
          label: 'Bugünkü etkinlikler',
          payload: 'Bugün hangi etkinlikler var?',
          icon: Icons.event_rounded,
        ),
        QuickReply(
          label: 'Öne çıkan yerler',
          payload: 'Öne çıkan yerleri göster',
          icon: Icons.star_outline_rounded,
        ),
        QuickReply(
          label: 'Ne yapabilirsin?',
          payload: 'Neler yapabilirsin?',
          icon: Icons.help_outline_rounded,
        ),
      ],
    );
  }
}
