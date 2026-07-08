import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/chat_message.dart';

/// Sohbet geçmişinin yerel kalıcılığı.
///
/// **KVKK §14.4.2 + §6.9.6 uyumu:**
/// - Mesajlar yalnızca cihazda saklanır (SharedPreferences).
/// - Sunucuya gönderilmez (analytics dahil — sadece intent_type + success
///   loglanır, kullanıcı metni ASLA loglanmaz).
/// - "Sohbeti temizle" butonu hem state'i hem persisted veriyi sıfırlar.
/// - Saklama sınırı: son [_maxRetained] mesaj (eski kayıtlar otomatik silinir).
///
/// **Performans:** Tek bir JSON array string. 50 mesaj × ortalama 250 byte =
/// ~12 KB. SharedPreferences için sorun değil.
class ChatbotHistoryRepository {
  ChatbotHistoryRepository._();

  static const String _key = 'chatbot_history_v1';
  static const int _maxRetained = 50;

  /// Persisted mesajları yükler. Hata durumunda boş liste.
  static Future<List<ChatMessage>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];

      final list = jsonDecode(raw);
      if (list is! List) return const [];

      return list
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(growable: false);
    } catch (e, st) {
      debugPrint('[ChatbotHistory] load failed: $e\n$st');
      return const [];
    }
  }

  /// Mesajları diske yazar. Limit aşılıyorsa baştan kırpılır.
  static Future<void> save(List<ChatMessage> messages) async {
    try {
      // Typing indicator gibi geçici mesajları persist etme.
      final clean = messages.where((m) => !m.isTyping).toList();

      // Limit kontrolü
      final trimmed = clean.length > _maxRetained
          ? clean.sublist(clean.length - _maxRetained)
          : clean;

      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        trimmed.map((m) => m.toJson()).toList(growable: false),
      );
      await prefs.setString(_key, encoded);
    } catch (e, st) {
      debugPrint('[ChatbotHistory] save failed: $e\n$st');
    }
  }

  /// "Sohbeti temizle" — tüm geçmişi cihazdan siler.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e, st) {
      debugPrint('[ChatbotHistory] clear failed: $e\n$st');
    }
  }
}
