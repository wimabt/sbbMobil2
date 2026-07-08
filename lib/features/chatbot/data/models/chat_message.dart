import 'package:flutter/foundation.dart';

import 'chat_response.dart';

enum ChatRole { user, bot, system }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.payload,
    this.isTyping = false,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime timestamp;
  final ChatResponse? payload;
  final bool isTyping;

  bool get isUser => role == ChatRole.user;
  bool get isBot => role == ChatRole.bot;
  bool get hasCards => payload != null && payload!.cards.isNotEmpty;
  bool get hasQuickReplies =>
      payload != null && payload!.quickReplies.isNotEmpty;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? text,
    DateTime? timestamp,
    ChatResponse? payload,
    bool? isTyping,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      payload: payload ?? this.payload,
      isTyping: isTyping ?? this.isTyping,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'ts': timestamp.toIso8601String(),
        if (payload != null) 'payload': payload!.toJson(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: ChatRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => ChatRole.bot,
      ),
      text: json['text'] as String? ?? '',
      timestamp: DateTime.tryParse(json['ts'] as String? ?? '') ?? DateTime.now(),
      payload: json['payload'] is Map<String, dynamic>
          ? ChatResponse.fromJson(json['payload'] as Map<String, dynamic>)
          : null,
    );
  }

  factory ChatMessage.user(String text) => ChatMessage(
        id: 'u_${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.user,
        text: text,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.bot(String text, {ChatResponse? payload}) => ChatMessage(
        id: 'b_${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.bot,
        text: text,
        timestamp: DateTime.now(),
        payload: payload,
      );

  factory ChatMessage.typing() => ChatMessage(
        id: 't_${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.bot,
        text: '',
        timestamp: DateTime.now(),
        isTyping: true,
      );
}
