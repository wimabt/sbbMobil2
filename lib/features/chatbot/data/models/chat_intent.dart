import 'package:flutter/foundation.dart';

/// NLU sonucu — bir kullanıcı mesajının çözümlenmiş hali.
///
/// `name` boş gelirse `fallback` olarak kabul edilir.
/// `slots` rich entity bilgisi taşır (örn. {'category': 'food', 'distance_km': 2.0}).
/// `confidence` 0..1 arası — eşik altı fallback'e düşer.
@immutable
class ChatIntent {
  const ChatIntent({
    required this.name,
    required this.confidence,
    this.slots = const {},
    this.rawText = '',
    this.normalizedText = '',
  });

  final String name;
  final double confidence;
  final Map<String, dynamic> slots;
  final String rawText;
  final String normalizedText;

  /// Sadece intent ismi 'fallback' ise true.
  ///
  /// Confidence eşiği zaten `IntentMatcher` içinde uygulanıyor (skor < _minScore
  /// olanlar name='fallback' olarak işaretlenir). Burada ek konfidans kontrolü
  /// yapmıyoruz çünkü combined routing ve clarification akışları kendi
  /// kararlarını skor üzerinden veriyor.
  bool get isFallback => name == 'fallback';

  /// Tip-güvenli slot okuma.
  T? slot<T>(String key) {
    final v = slots[key];
    if (v is T) return v;
    return null;
  }

  ChatIntent copyWith({
    String? name,
    double? confidence,
    Map<String, dynamic>? slots,
    String? rawText,
    String? normalizedText,
  }) {
    return ChatIntent(
      name: name ?? this.name,
      confidence: confidence ?? this.confidence,
      slots: slots ?? this.slots,
      rawText: rawText ?? this.rawText,
      normalizedText: normalizedText ?? this.normalizedText,
    );
  }

  static const ChatIntent fallback = ChatIntent(
    name: 'fallback',
    confidence: 0.0,
  );
}

/// Konuşma bağlamı — son N mesajdan elde edilen slot taşıması için.
///
/// Kullanıcı "yakınımdaki yerler" dedikten sonra "yemek olanlar?" derse
/// önceki `nearby_query` intent'i + yeni `category=food` slot'u birleştirilir.
@immutable
class ChatContext {
  const ChatContext({
    required this.lastIntents,
    this.userLatitude,
    this.userLongitude,
    this.locale = 'tr',
  });

  final List<ChatIntent> lastIntents;
  final double? userLatitude;
  final double? userLongitude;
  final String locale;

  ChatIntent? get previousIntent =>
      lastIntents.isNotEmpty ? lastIntents.last : null;

  bool get hasLocation => userLatitude != null && userLongitude != null;

  ChatContext withNewIntent(ChatIntent intent) {
    const maxRetained = 5;
    final updated = [...lastIntents, intent];
    if (updated.length > maxRetained) {
      updated.removeRange(0, updated.length - maxRetained);
    }
    return ChatContext(
      lastIntents: updated,
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      locale: locale,
    );
  }
}
