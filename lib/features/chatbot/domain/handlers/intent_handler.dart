import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';

/// Tüm intent handler'larının ortak sözleşmesi.
///
/// **Tasarım kararı:** Her handler tek bir intent'ten sorumlu. Yeni intent
/// eklemek için: (1) `intent_dictionary.dart`'a tanım, (2) bu sınıfı extend
/// eden yeni dosya, (3) `chatbot_service.dart`'ta map'e ekleme.
///
/// İleride LLM entegrasyonu için (§6.9.7.1): aynı interface'i implemente eden
/// `LlmIntentHandler` yazılır, mevcut handler'lar shortcut olarak kalır.
abstract class IntentHandler {
  const IntentHandler();

  /// Hangi intent ile çağrılacağını döner.
  String get intentName;

  /// Niyet + bağlam ile cevap üretir.
  ///
  /// `ref` ile mevcut Riverpod provider'lara erişebilir (placesProvider vb.).
  /// Network çağrısı yapmamalı — provider cache'inden okumalı.
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  );
}
