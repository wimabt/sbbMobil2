import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'intent_handler.dart';

/// Karşılama — günün saatine göre selamlama, sade ve sıcak ton.
class GreetHandler extends IntentHandler {
  const GreetHandler();

  @override
  String get intentName => 'greet';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    final hour = DateTime.now().hour;
    final timeGreeting = switch (hour) {
      >= 5 && < 12 => 'Günaydın',
      >= 12 && < 18 => 'Merhaba',
      >= 18 && < 22 => 'İyi akşamlar',
      _ => 'İyi geceler',
    };

    return ChatResponse(
      text: '$timeGreeting! Bugün sana nasıl yardımcı olabilirim?',
      quickReplies: const [
        QuickReply(
          label: 'Yakınımda ne var?',
          payload: 'Yakınımdaki yerleri göster',
          icon: Icons.near_me_rounded,
        ),
        QuickReply(
          label: 'Etkinlikler',
          payload: 'Bugün etkinlik var mı?',
          icon: Icons.event_rounded,
        ),
        QuickReply(
          label: 'Yer öner',
          payload: 'Bana bir yer öner',
          icon: Icons.recommend_rounded,
        ),
        QuickReply(
          label: 'Yardım',
          payload: 'Neler yapabilirsin?',
          icon: Icons.help_outline_rounded,
        ),
      ],
    );
  }
}
