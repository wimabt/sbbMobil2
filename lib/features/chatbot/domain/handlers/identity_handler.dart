import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'intent_handler.dart';

/// "Kimsin / adın ne / robot musun / espri yap" — `identity` intent.
///
/// Asistanın kim olduğunu sıcak bir dille anlatır; "espri/şaka/fıkra"
/// istenirse hafif bir Samsun esprisiyle karşılık verir. Her durumda
/// kullanıcıyı yeteneklerine yönlendirir.
class IdentityHandler extends IntentHandler {
  const IdentityHandler();

  static const String _about =
      'Ben Samsun Asistan 🤖 — şehri keşfetmene yardımcı olan dijital '
      'rehberinim. Yakınındaki yerleri bulabilir, etkinlik ve duyuruları '
      'listeleyebilir, yöresel lezzetler ve gezi rotaları önerebilirim. '
      'Yapay zekâ destekli değilim; senin için özenle hazırlanmış bir '
      'şehir rehberiyim. Sadece doğal Türkçe ile yaz, gerisini bana bırak.';

  // Hafif, yöreye özgü espriler — "espri/şaka/fıkra" tetiklerse.
  static const List<String> _jokes = [
    'Samsunlu balık lokantaya girmiş, garson sormuş: "Hamsi mi olsun?" '
        'Balık demiş ki: "Aman, akrabalarımı karıştırma!" 🐟 '
        'Neyse, ben espriyi bırakıp sana güzel yerler önereyim mi?',
    'Pidecinin biri "En uzun pidemiz Bafra usulü" demiş; '
        'müşteri "Yarısını paket yapın" demiş. 😄 '
        'Hadi gel, gerçek lezzetlere bakalım mı?',
  ];

  @override
  String get intentName => 'identity';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    final text = intent.normalizedText;
    final wantsJoke = text.contains('espri') ||
        text.contains('saka') ||
        text.contains('şaka') ||
        text.contains('fikra') ||
        text.contains('fıkra');

    if (wantsJoke) {
      final idx = DateTime.now().second % _jokes.length;
      return ChatResponse(
        text: _jokes[idx],
        quickReplies: const [
          QuickReply(
            label: 'Yer öner',
            payload: 'Bana bir yer öner',
            icon: Icons.recommend_rounded,
          ),
          QuickReply(
            label: 'Yöresel yemek',
            payload: 'Samsun yöresel yemekleri',
            icon: Icons.restaurant_rounded,
          ),
        ],
      );
    }

    return const ChatResponse(
      text: _about,
      quickReplies: [
        QuickReply(
          label: 'Neler yapabilirsin?',
          payload: 'Neler yapabilirsin?',
          icon: Icons.auto_awesome_rounded,
        ),
        QuickReply(
          label: 'Yakınımda ne var?',
          payload: 'Yakınımdaki yerleri göster',
          icon: Icons.near_me_rounded,
        ),
        QuickReply(
          label: 'Samsun hakkında',
          payload: 'Samsun hakkında bilgi',
          icon: Icons.location_city_rounded,
        ),
      ],
    );
  }
}
