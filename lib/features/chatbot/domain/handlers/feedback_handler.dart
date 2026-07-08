import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import 'intent_handler.dart';

/// Teşekkür / pozitif feedback — kısa onay + alternatif öneri.
class FeedbackHandler extends IntentHandler {
  const FeedbackHandler();

  static const List<String> _replies = [
    'Rica ederim. Başka bir şey ister misin?',
    'Ne demek, kolayca buldun mu yoksa daha fazlasını mı istersin?',
    'Sevindim! Devam edelim mi?',
    'Memnun oldum. Başka bir konu var mı?',
  ];

  @override
  String get intentName => 'feedback';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    final idx = DateTime.now().second % _replies.length;
    return ChatResponse(
      text: _replies[idx],
      quickReplies: const [
        QuickReply(
          label: 'Başka bir yer öner',
          payload: 'Başka bir yer öner',
          icon: Icons.refresh_rounded,
        ),
        QuickReply(
          label: 'Etkinliklere bak',
          payload: 'Yaklaşan etkinlikleri göster',
          icon: Icons.event_rounded,
        ),
        QuickReply(
          label: 'Yeterli, teşekkürler',
          payload: 'Yeterli',
          icon: Icons.check_rounded,
        ),
      ],
    );
  }
}
