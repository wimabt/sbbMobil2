import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'intent_handler.dart';

/// "Gezi planı / itinerary / plan oluştur" — `itinerary_help` intent.
///
/// Kullanıcıyı uygulamadaki Gezi Planlama özelliğine yönlendirir.
/// İçerik §6.5.2 kapsamında.
class ItineraryHelpHandler extends IntentHandler {
  const ItineraryHelpHandler();

  @override
  String get intentName => 'itinerary_help';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    return const ChatResponse(
      text: 'Gezi planı oluşturmak çok kolay:\n\n'
          '1. Beğendiğin yerin sayfasındaki "Plana Ekle" butonuna bas\n'
          '2. Mevcut bir plana ekle ya da yeni plan oluştur\n'
          '3. Tarih ve saat ata, sıralamayı düzenle\n'
          '4. "Haritada Göster" ile güzergahı çıkar — OSRM ile çoklu duraklı '
          'rota hesaplar\n\n'
          'Hazır rotalardan ilham almak da bir seçenek.',
      cards: [
        ChatCard(
          type: ChatCardType.info,
          title: 'Gezi planlarım',
          subtitle: 'Mevcut planlarını aç ya da yeni başlat',
          icon: Icons.event_note_rounded,
          targetRoute: '/itinerary',
        ),
      ],
      quickReplies: [
        QuickReply(
          label: 'Planlarımı aç',
          payload: 'Gezi planlarım',
          icon: Icons.event_note_rounded,
          navigateTo: '/itinerary',
        ),
        QuickReply(
          label: 'Hazır rotalar',
          payload: 'Hazır rotaları göster',
          icon: Icons.alt_route_rounded,
        ),
        QuickReply(
          label: 'Tarihi yerler',
          payload: 'Tarihi yerler öner',
          icon: Icons.museum_rounded,
        ),
      ],
    );
  }
}
