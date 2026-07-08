import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'intent_handler.dart';

/// "Samsun nedir / hakkında bilgi" — `samsun_info` intent.
///
/// Statik şehir tanıtım kartı. İçerik §6.2.1 kapsamında şehir tanıtımı —
/// bu metin İdare tarafından düzenlenebilir hale getirilebilir (gelecekte
/// admin panelden çekilebilir bir endpoint'e bağlanabilir).
class SamsunInfoHandler extends IntentHandler {
  const SamsunInfoHandler();

  // İdare onayına tabidir — İdare metni güncelleyebilir.
  static const String _summary =
      'Samsun, Karadeniz kıyısında yer alan, Türkiye Cumhuriyeti\'nin '
      'kuruluş yolculuğunun başlangıç noktasıdır. 19 Mayıs 1919\'da Atatürk\'ün '
      'çıkışıyla simgeleşen şehir, hem tarihi mirası hem de doğal güzellikleri '
      'ile turizm açısından değerli bir destinasyondur.\n\n'
      'Bafra ve Çarşamba Ovaları\'nın bereketli toprakları, Kızılırmak ve '
      'Yeşilırmak nehirlerinin denize döküldüğü deltalar, antik Amisos\'tan '
      'günümüze ulaşan tarihi yapılar şehri ziyaretçileri için keşfedilmeyi '
      'bekleyen bir hazineye dönüştürür.';

  @override
  String get intentName => 'samsun_info';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    return const ChatResponse(
      text: _summary,
      followUpHint: 'Belirli bir konuda daha ayrıntı ister misin? '
          'Aşağıdan seçebilirsin.',
      quickReplies: [
        QuickReply(
          label: 'Tarihi yerler',
          payload: 'Samsun\'un tarihi yerleri nelerdir?',
          icon: Icons.museum_rounded,
        ),
        QuickReply(
          label: 'Doğal güzellikler',
          payload: 'Samsun\'un doğal güzellikleri',
          icon: Icons.park_rounded,
        ),
        QuickReply(
          label: 'Yöresel yemekler',
          payload: 'Samsun\'un yöresel yemekleri',
          icon: Icons.restaurant_rounded,
        ),
        QuickReply(
          label: 'Müzeler',
          payload: 'Samsun\'da hangi müzeler var?',
          icon: Icons.account_balance_rounded,
        ),
      ],
    );
  }
}
