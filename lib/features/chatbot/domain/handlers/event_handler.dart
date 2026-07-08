import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/event.dart';
import '../../../culture/presentation/providers/events_provider.dart';
import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'handler_utils.dart';
import 'intent_handler.dart';

/// "Bugün etkinlik var mı / hafta sonu konser" — `event_query` intent.
///
/// Slot:
///   - `time` → today / tomorrow / this_weekend / this_week / this_month
class EventHandler extends IntentHandler {
  const EventHandler();

  static const int _maxInline = 3;

  @override
  String get intentName => 'event_query';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    // Provider lazy-load — pre-warm yapılmış olsa bile API yanıtı gelene kadar
    // kısa süre bekle. Zaten yüklenmiş ise hemen geçer.
    await waitForData(
      check: () {
        final s = ref.read(eventsListProvider);
        return !s.isLoading || s.allEvents.isNotEmpty;
      },
    );

    final allEvents = ref.read(eventsListProvider).allEvents;
    if (allEvents.isEmpty) {
      return const ChatResponse(
        text: 'Şu an gösterebileceğim aktif bir etkinlik bulamadım. '
            'Yakın zamanda yenileri eklenecektir.',
        quickReplies: [
          QuickReply(
            label: 'Yakınımdaki yerler',
            payload: 'Yakınımdaki yerler',
            icon: Icons.near_me_rounded,
          ),
          QuickReply(
            label: 'Son duyurular',
            payload: 'Son duyurular neler?',
            icon: Icons.campaign_rounded,
          ),
          QuickReply(
            label: 'Etkinlik sayfasına git',
            payload: 'Etkinlikler',
            icon: Icons.event_rounded,
            navigateTo: '/events',
          ),
        ],
      );
    }

    final timeSlot = intent.slot<String>('time');
    final filter = _filterFor(timeSlot);
    final filtered = _futureOrInRange(allEvents, filter).toList();

    if (filtered.isEmpty) {
      return ChatResponse(
        text: '${_timeLabelHeadline(timeSlot)} etkinlik bulamadım. '
            'Daha geniş bir aralığa bakmak ister misin?',
        quickReplies: const [
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
            label: 'Tümünü göster',
            payload: 'Yaklaşan tüm etkinlikler',
            icon: Icons.list_rounded,
          ),
        ],
      );
    }

    // Tarihe göre sırala
    filtered.sort((a, b) {
      final ad = a.parsedStartDate ?? DateTime.now();
      final bd = b.parsedStartDate ?? DateTime.now();
      return ad.compareTo(bd);
    });

    final shown = filtered.take(_maxInline).toList();
    final hasMore = filtered.length > _maxInline;

    final cards = shown.map((e) {
      return ChatCard(
        type: ChatCardType.event,
        title: e.title,
        subtitle: e.displayLocation,
        imageUrl: e.imageUrl,
        trailing: _formatEventDate(e),
        targetRoute: '/events/${e.id}',
      );
    }).toList();

    // Combined akıştan (örn. "yakındakiler" → "etkinlikler") geldiyse
    // başlığı kullanıcı bağlamını yansıtacak şekilde değiştir.
    final fromContext = intent.slot<String>('_combined_from');
    final headline = fromContext == 'nearby_query'
        ? 'Yakınında ${_timeLabelHeadline(timeSlot).toLowerCase()} '
            '${filtered.length} etkinlik var:'
        : '${_timeLabelHeadline(timeSlot)} ${filtered.length} etkinlik var. '
            'En yakındakiler:';

    return ChatResponse(
      text: headline,
      cards: cards,
      quickReplies: [
        if (hasMore)
          const QuickReply(
            label: 'Tüm etkinlikler',
            payload: 'Tüm etkinlikleri göster',
            icon: Icons.list_rounded,
            navigateTo: '/events',
          ),
        const QuickReply(
          label: 'Hafta sonu',
          payload: 'Hafta sonu etkinlikler',
          icon: Icons.weekend_rounded,
        ),
        const QuickReply(
          label: 'Bu ay neler var',
          payload: 'Bu ay etkinlikler',
          icon: Icons.calendar_month_rounded,
        ),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  _DateRange _filterFor(String? slot) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    return switch (slot) {
      'today' => _DateRange(
          start: startOfToday,
          end: startOfToday.add(const Duration(days: 1)),
        ),
      'tomorrow' => _DateRange(
          start: startOfToday.add(const Duration(days: 1)),
          end: startOfToday.add(const Duration(days: 2)),
        ),
      'this_weekend' => _weekendRange(now),
      'this_week' => _DateRange(
          start: startOfToday,
          end: startOfToday.add(const Duration(days: 7)),
        ),
      'this_month' => _DateRange(
          start: startOfToday,
          end: DateTime(now.year, now.month + 1, 1),
        ),
      _ => _DateRange(
          start: startOfToday,
          end: startOfToday.add(const Duration(days: 30)),
        ),
    };
  }

  _DateRange _weekendRange(DateTime now) {
    // Bu hafta sonu: en yakın cumartesi 00:00 - pazartesi 00:00
    final today = DateTime(now.year, now.month, now.day);
    final weekday = today.weekday; // 1=pzt, 7=pazar
    final daysUntilSaturday = (DateTime.saturday - weekday) % 7;
    final saturday = today.add(Duration(days: daysUntilSaturday));
    return _DateRange(
      start: saturday,
      end: saturday.add(const Duration(days: 2)),
    );
  }

  Iterable<Event> _futureOrInRange(List<Event> events, _DateRange range) {
    return events.where((e) {
      final d = e.parsedStartDate;
      if (d == null) return false;
      return !d.isBefore(range.start) && d.isBefore(range.end);
    });
  }

  String _formatEventDate(Event e) {
    final d = e.parsedStartDate;
    if (d == null) return e.date;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay = DateTime(d.year, d.month, d.day);
    final diff = dDay.difference(today).inDays;

    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    if (diff < 7) return '$diff gün sonra';
    return '${d.day}.${d.month.toString().padLeft(2, '0')}';
  }

  String _timeLabelHeadline(String? slot) {
    return switch (slot) {
      'today' => 'Bugün',
      'tomorrow' => 'Yarın',
      'this_weekend' => 'Bu hafta sonu',
      'this_week' => 'Bu hafta',
      'this_month' => 'Bu ay',
      _ => 'Yaklaşan',
    };
  }
}

class _DateRange {
  const _DateRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}
