import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'intent_handler.dart';

/// "Ne yapabilirsin?" — kullanıcıya yeteneklerin özetini ve örnek sorgular sunar.
class HelpHandler extends IntentHandler {
  const HelpHandler();

  @override
  String get intentName => 'help';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    return ChatResponse(
      text: 'Sana şu konularda yardımcı olabilirim:\n\n'
          '• Yakınındaki yerleri bulma\n'
          '• Tarihi, kültürel, doğa noktaları önerme\n'
          '• Etkinlik ve duyuruları listeleme\n'
          '• Yöresel tarifler ve nerede yiyebileceğin\n'
          '• Hazır gezi rotaları ve gezi planı\n'
          '• Bir yere nasıl gidileceği\n'
          '• Belirli bir mekan hakkında bilgi\n'
          '• Ulaşım (otobüs, tramvay) ve acil numaralar\n'
          '• Samsun şehri hakkında genel bilgi\n\n'
          'Sadece doğal Türkçe ile yaz; ben anlarım.',
      quickReplies: const [
        QuickReply(
          label: 'Tarihi yerler',
          payload: 'Samsun\'da görmem gereken tarihi yerler neler?',
          icon: Icons.museum_rounded,
        ),
        QuickReply(
          label: 'Doğa keşfi',
          payload: 'Doğal güzelliklere ne öner?',
          icon: Icons.park_rounded,
        ),
        QuickReply(
          label: 'Bu hafta sonu',
          payload: 'Hafta sonu hangi etkinlikler var?',
          icon: Icons.weekend_rounded,
        ),
        QuickReply(
          label: 'Yöresel yemek',
          payload: 'Samsun\'da hangi yöresel yemekleri denemeliyim?',
          icon: Icons.restaurant_rounded,
        ),
      ],
      followUpHint: 'İpucu: "Atatürk Anıtı hakkında bilgi" gibi belirli bir '
          'mekan da sorabilirsin.',
    );
  }
}
