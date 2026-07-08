import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'intent_handler.dart';

/// "Hayır / yeter / boşver / kapat" — `decline` intent.
///
/// Sıcak bir kapanış + her an geri dönülebileceğini hatırlatan birkaç chip.
/// Kullanıcıyı zorlamaz; konuşmayı kibarca bitirir.
class DeclineHandler extends IntentHandler {
  const DeclineHandler();

  static const List<String> _replies = [
    'Tamamdır, ne zaman istersen buradayım. İyi gezmeler! 🙂',
    'Anlaşıldı! İhtiyacın olursa tek bir mesaj uzağındayım.',
    'Peki. Aklına bir şey takılırsa yine yaz, sevinirim.',
  ];

  @override
  String get intentName => 'decline';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    final idx = DateTime.now().second % _replies.length;
    return ChatResponse(
      text: _replies[idx],
      quickReplies: const [
        QuickReply(
          label: 'Yakınımda ne var?',
          payload: 'Yakınımdaki yerleri göster',
          icon: Icons.near_me_rounded,
        ),
        QuickReply(
          label: 'Neler yapabilirsin?',
          payload: 'Neler yapabilirsin?',
          icon: Icons.help_outline_rounded,
        ),
      ],
    );
  }
}
