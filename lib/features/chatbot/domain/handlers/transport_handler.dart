import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'intent_handler.dart';

/// "Ulaşım / otobüs / tramvay / toplu taşıma" — `transport` intent.
///
/// Statik, idare onayına tabi bilgilendirme. Uygulamada ayrı bir ulaşım
/// modülü olmadığından kullanıcıyı doğru yöne (harita + genel bilgi) yönlendirir.
/// İleride canlı sefer verisi eklenirse bu handler ona bağlanabilir.
class TransportHandler extends IntentHandler {
  const TransportHandler();

  @override
  String get intentName => 'transport';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    return const ChatResponse(
      text: 'Samsun\'da şehir içi ulaşım büyük ölçüde tramvay ve otobüslerle '
          'sağlanır:\n\n'
          '• Tramvay sahil hattı boyunca birçok merkezi noktayı birbirine bağlar\n'
          '• Otobüs ve dolmuşlar ilçe ve mahallelere ulaşım sağlar\n'
          '• Ödemeler şehir kartı (Samkart) ile yapılır\n\n'
          'Gitmek istediğin yeri söylersen, onu haritada açıp en uygun '
          'rotayı çıkarmana yardımcı olabilirim.',
      cards: [
        ChatCard(
          type: ChatCardType.info,
          title: 'Haritada planla',
          subtitle: 'Konumunu ve hedefini seç, rotayı gör',
          icon: Icons.map_rounded,
          targetRoute: '/map',
        ),
      ],
      quickReplies: [
        QuickReply(
          label: 'Haritayı aç',
          payload: 'Haritayı aç',
          icon: Icons.map_rounded,
          navigateTo: '/map',
        ),
        QuickReply(
          label: 'Yakınımdaki yerler',
          payload: 'Yakınımdaki yerleri göster',
          icon: Icons.near_me_rounded,
        ),
        QuickReply(
          label: 'Bir yere nasıl giderim?',
          payload: 'Bir yere nasıl giderim',
          icon: Icons.directions_rounded,
        ),
      ],
    );
  }
}
