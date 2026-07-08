import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../announcements/presentation/providers/announcements_provider.dart';
import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'handler_utils.dart';
import 'intent_handler.dart';

/// "Son duyurular neler / haberler" — `announcement_query` intent.
class AnnouncementHandler extends IntentHandler {
  const AnnouncementHandler();

  static const int _maxInline = 3;

  @override
  String get intentName => 'announcement_query';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    await waitForData(
      check: () {
        final s = ref.read(announcementsProvider);
        return !s.isLoading || s.allAnnouncements.isNotEmpty;
      },
    );

    final state = ref.read(announcementsProvider);
    final all = state.allAnnouncements;

    if (all.isEmpty) {
      return const ChatResponse(
        text: 'Şu an gösterebileceğim aktif bir duyuru yok.',
        quickReplies: [
          QuickReply(
            label: 'Etkinliklere bak',
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

    // En yeni → en eski
    final epoch = DateTime(2000);
    final sorted = all.toList()
      ..sort((a, b) {
        final ad = a.publishedAt ?? a.createdAt ?? epoch;
        final bd = b.publishedAt ?? b.createdAt ?? epoch;
        return bd.compareTo(ad);
      });

    final shown = sorted.take(_maxInline).toList();
    final hasMore = sorted.length > _maxInline;

    final cards = shown.map((a) {
      return ChatCard(
        type: ChatCardType.announcement,
        title: a.title,
        subtitle: a.excerpt ?? a.categoryName,
        imageUrl: a.imageUrl ?? a.thumbnailUrl,
        trailing: a.isImportant ? 'Önemli' : (a.isNew ? 'Yeni' : null),
        targetRoute: '/announcements/${a.id}',
      );
    }).toList();

    return ChatResponse(
      text: 'En son ${sorted.length} duyuru var. İlk üçü:',
      cards: cards,
      quickReplies: [
        if (hasMore)
          const QuickReply(
            label: 'Tümünü gör',
            payload: 'Tüm duyurular',
            icon: Icons.list_rounded,
            navigateTo: '/announcements',
          ),
        const QuickReply(
          label: 'Yaklaşan etkinlikler',
          payload: 'Yaklaşan etkinlikler',
          icon: Icons.event_rounded,
        ),
      ],
    );
  }
}
