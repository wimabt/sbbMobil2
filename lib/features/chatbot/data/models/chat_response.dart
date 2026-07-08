import 'package:flutter/material.dart';

/// Kart türleri — UI tarafında uygun widget'a yönlendirmek için.
enum ChatCardType {
  place,
  event,
  recipe,
  route,
  announcement,
  gastronomy,
  info,
}

/// Bot mesajının zengin payload'u: metin + kartlar + hızlı yanıtlar.
@immutable
class ChatResponse {
  const ChatResponse({
    required this.text,
    this.cards = const [],
    this.quickReplies = const [],
    this.followUpHint,
  });

  final String text;
  final List<ChatCard> cards;
  final List<QuickReply> quickReplies;

  /// Cevabın sonunda gösterilecek incelikli alt metin
  /// (örn. "Daha fazla seçenek için kategoriyi söyleyin").
  final String? followUpHint;

  ChatResponse copyWith({
    String? text,
    List<ChatCard>? cards,
    List<QuickReply>? quickReplies,
    String? followUpHint,
  }) {
    return ChatResponse(
      text: text ?? this.text,
      cards: cards ?? this.cards,
      quickReplies: quickReplies ?? this.quickReplies,
      followUpHint: followUpHint ?? this.followUpHint,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        if (cards.isNotEmpty)
          'cards': cards.map((c) => c.toJson()).toList(growable: false),
        if (quickReplies.isNotEmpty)
          'qr': quickReplies.map((q) => q.toJson()).toList(growable: false),
        if (followUpHint != null) 'hint': followUpHint,
      };

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      text: json['text'] as String? ?? '',
      cards: (json['cards'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatCard.fromJson)
              .toList(growable: false) ??
          const [],
      quickReplies: (json['qr'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(QuickReply.fromJson)
              .toList(growable: false) ??
          const [],
      followUpHint: json['hint'] as String?,
    );
  }

  /// Sadece metin cevap.
  factory ChatResponse.text(String message, {List<QuickReply>? replies}) =>
      ChatResponse(text: message, quickReplies: replies ?? const []);
}

/// Inline gösterilecek kart. Maks 3 tane (kalan içerik "Hepsini gör" CTA'sına).
@immutable
class ChatCard {
  const ChatCard({
    required this.type,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.trailing,
    this.targetRoute,
    this.icon,
    this.distance,
  });

  final ChatCardType type;
  final String title;
  final String? subtitle;
  final String? imageUrl;

  /// Sağ üstte küçük yardımcı metin (mesafe, tarih, ücret).
  final String? trailing;

  /// Tap aksiyonu — null değilse `context.push(targetRoute)`.
  final String? targetRoute;

  /// Görsel yoksa fallback ikon.
  final IconData? icon;

  /// Sıralama için ham mesafe (km).
  final double? distance;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        if (subtitle != null) 'sub': subtitle,
        if (imageUrl != null) 'img': imageUrl,
        if (trailing != null) 'tr': trailing,
        if (targetRoute != null) 'to': targetRoute,
        if (distance != null) 'd': distance,
      };

  factory ChatCard.fromJson(Map<String, dynamic> json) {
    return ChatCard(
      type: ChatCardType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ChatCardType.info,
      ),
      title: json['title'] as String? ?? '',
      subtitle: json['sub'] as String?,
      imageUrl: json['img'] as String?,
      trailing: json['tr'] as String?,
      targetRoute: json['to'] as String?,
      distance: (json['d'] as num?)?.toDouble(),
    );
  }
}

/// Mesajın altında gösterilen quick reply chip'i.
///
/// İki davranış türü:
/// - **Sorgu chip'i** (default): [payload] yeni kullanıcı mesajı olarak gönderilir
///   ve NLU üzerinden işlenir. Örn: "Tarihi yerler", "Etkinlikler".
/// - **Navigasyon chip'i** ([navigateTo] dolu): Doğrudan route'a `context.push` yapılır.
///   NLU'ya gitmez. Örn: "Tümünü gör → /places", "Haritada göster → /map".
///
/// Bu ayrım, chatbot'un "söylediği şeyi söyleyince" tekrar fallback üretmesini
/// önler ve aksiyon chip'lerini hızlı tutar.
@immutable
class QuickReply {
  const QuickReply({
    required this.label,
    required this.payload,
    this.icon,
    this.navigateTo,
  });

  final String label;
  final String payload;
  final IconData? icon;

  /// Dolu ise, tıklamada NLU yerine doğrudan bu route'a yönlendirilir.
  /// `null` ise [payload] mesaj olarak işlenir.
  final String? navigateTo;

  bool get isNavigation => navigateTo != null && navigateTo!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'label': label,
        'p': payload,
        if (navigateTo != null) 'to': navigateTo,
      };

  factory QuickReply.fromJson(Map<String, dynamic> json) => QuickReply(
        label: json['label'] as String? ?? '',
        payload: json['p'] as String? ?? '',
        navigateTo: json['to'] as String?,
      );
}
