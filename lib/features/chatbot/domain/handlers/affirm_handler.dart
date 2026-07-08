import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'intent_handler.dart';

/// "Evet / olur / devam / daha fazla" — `affirm` intent.
///
/// Bot çoğu cevabını bir soruyla bitiriyor ("Daha fazlasını ister misin?",
/// "Başka bir şey var mı?"). Kullanıcı "evet" derse bunu fallback'e düşürmek
/// yerine, **bir önceki konuya** göre anlamlı bir devam üretiriz.
///
/// Önceki intent'i [ChatContext.previousIntent] üzerinden okur ve ona uygun
/// hızlı yanıt seçenekleri sunar. Bağlam yoksa genel başlangıç önerileri verir.
class AffirmHandler extends IntentHandler {
  const AffirmHandler();

  @override
  String get intentName => 'affirm';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    final prev = context.previousIntent?.name;

    final continuation = switch (prev) {
      'nearby_query' => const ChatResponse(
          text: 'Tabii! Aramayı genişletelim ya da bir tür seçelim:',
          quickReplies: [
            QuickReply(
              label: 'Daha geniş alanda ara',
              payload: 'Biraz uzaktaki yerler',
              icon: Icons.zoom_out_map_rounded,
            ),
            QuickReply(
              label: 'Yemek olanlar',
              payload: 'Yakınımdaki yemek mekanları',
              icon: Icons.restaurant_rounded,
            ),
            QuickReply(
              label: 'Tarihi olanlar',
              payload: 'Yakınımdaki tarihi yerler',
              icon: Icons.museum_rounded,
            ),
          ],
        ),
      'category_query' => const ChatResponse(
          text: 'Süper, başka bir kategoriye de bakalım mı?',
          quickReplies: [
            QuickReply(
              label: 'Doğa',
              payload: 'Doğa yerleri öner',
              icon: Icons.park_rounded,
            ),
            QuickReply(
              label: 'Kültür & müze',
              payload: 'Kültürel yerler öner',
              icon: Icons.account_balance_rounded,
            ),
            QuickReply(
              label: 'Öne çıkanlar',
              payload: 'Öne çıkan yerleri göster',
              icon: Icons.star_outline_rounded,
            ),
          ],
        ),
      'event_query' => const ChatResponse(
          text: 'Tamam, etkinlik aralığını genişleteyim:',
          quickReplies: [
            QuickReply(
              label: 'Bu hafta',
              payload: 'Bu hafta hangi etkinlikler var?',
              icon: Icons.date_range_rounded,
            ),
            QuickReply(
              label: 'Bu ay',
              payload: 'Bu ay neler oluyor?',
              icon: Icons.calendar_month_rounded,
            ),
            QuickReply(
              label: 'Tümünü gör',
              payload: 'Yaklaşan tüm etkinlikler',
              icon: Icons.list_rounded,
            ),
          ],
        ),
      'recipe_query' => const ChatResponse(
          text: 'Harika, devam edelim:',
          quickReplies: [
            QuickReply(
              label: 'Başka tarif',
              payload: 'Başka yöresel tarif öner',
              icon: Icons.restaurant_menu_rounded,
            ),
            QuickReply(
              label: 'Nerede yiyebilirim?',
              payload: 'Yakınımda nerede yemek yiyebilirim?',
              icon: Icons.local_dining_rounded,
            ),
          ],
        ),
      'route_query' => const ChatResponse(
          text: 'Tamam, gezmeye devam:',
          quickReplies: [
            QuickReply(
              label: 'Tüm rotalar',
              payload: 'Tüm rotaları göster',
              icon: Icons.alt_route_rounded,
            ),
            QuickReply(
              label: 'Gezi planı yap',
              payload: 'Gezi planı oluşturmak istiyorum',
              icon: Icons.event_note_rounded,
            ),
          ],
        ),
      _ => _generic(),
    };

    return continuation;
  }

  ChatResponse _generic() => const ChatResponse(
        text: 'Süper! Ne yapmak istersin?',
        quickReplies: [
          QuickReply(
            label: 'Yakınımdaki yerler',
            payload: 'Yakınımdaki yerleri göster',
            icon: Icons.near_me_rounded,
          ),
          QuickReply(
            label: 'Etkinlikler',
            payload: 'Yaklaşan etkinlikler',
            icon: Icons.event_rounded,
          ),
          QuickReply(
            label: 'Yer öner',
            payload: 'Bana bir yer öner',
            icon: Icons.recommend_rounded,
          ),
        ],
      );
}
