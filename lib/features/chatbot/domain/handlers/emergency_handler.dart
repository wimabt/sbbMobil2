import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'intent_handler.dart';

/// "Acil / 112 / hastane / polis / eczane" — `emergency` intent.
///
/// Türkiye genelinde geçerli acil durum numaralarını net ve hızlı sunar.
/// Tek acil çağrı merkezi **112**'dir; diğerleri bilgilendirme amaçlıdır.
/// Statik içerik — idare tarafından güncellenebilir.
class EmergencyHandler extends IntentHandler {
  const EmergencyHandler();

  @override
  String get intentName => 'emergency';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    return const ChatResponse(
      text: 'Acil bir durumda Türkiye genelinde tek acil çağrı numarası '
          '112\'dir — ambulans, itfaiye ve polis bu hat üzerinden yönlendirilir.\n\n'
          '• 112 — Acil Çağrı Merkezi (her durum)\n'
          '• 155 — Polis İmdat\n'
          '• 156 — Jandarma\n'
          '• 110 — İtfaiye\n'
          '• 177 — Orman Yangını\n\n'
          'En yakın hastane veya eczaneyi haritadan da bulabilirsin.',
      cards: [
        ChatCard(
          type: ChatCardType.info,
          title: 'Yakındaki sağlık noktaları',
          subtitle: 'Hastane ve eczaneleri haritada gör',
          icon: Icons.local_hospital_rounded,
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
      ],
    );
  }
}
