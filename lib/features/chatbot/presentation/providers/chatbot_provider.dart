import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/user_location_provider.dart';
import '../../../../core/services/analytics_events.dart';
import '../../../../core/services/analytics_service.dart';
import '../../data/chatbot_history_repository.dart';
import '../../data/models/chat_intent.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_response.dart';
import '../../domain/chatbot_service.dart';

/// Chatbot oturum durumu — mesaj listesi + bağlam + isteğin durumu.
@immutable
class ChatbotState {
  const ChatbotState({
    this.messages = const [],
    this.context = const ChatContext(lastIntents: []),
    this.isProcessing = false,
  });

  final List<ChatMessage> messages;
  final ChatContext context;
  final bool isProcessing;

  bool get isEmpty => messages.isEmpty;
  bool get hasMessages => messages.isNotEmpty;

  ChatbotState copyWith({
    List<ChatMessage>? messages,
    ChatContext? context,
    bool? isProcessing,
  }) {
    return ChatbotState(
      messages: messages ?? this.messages,
      context: context ?? this.context,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

/// Mesajları yöneten Notifier (Riverpod 3.x).
///
/// `ChatbotService` aracılığıyla NLU → handler → response zincirini çalıştırır.
/// Geçmiş `ChatbotHistoryRepository` üzerinden cihazda (sadece) saklanır.
class ChatbotNotifier extends Notifier<ChatbotState> {
  @override
  ChatbotState build() {
    // Cold start'ta persisted geçmişi yükle (mikrotask ile UI'ı bloklama).
    Future.microtask(_restore);
    return ChatbotState(messages: [_welcomeMessage()]);
  }

  Future<void> _restore() async {
    final persisted = await ChatbotHistoryRepository.load();
    if (persisted.isEmpty) return;
    state = state.copyWith(messages: [_welcomeMessage(), ...persisted]);
  }

  Future<void> _persist() async {
    // Karşılama mesajını persist etme — her açılışta yeniden inşa ediliyor.
    final toSave = state.messages.where((m) {
      if (m.isTyping) return false;
      if (m.role == ChatRole.bot && m.id.startsWith('b_welcome_')) return false;
      return true;
    }).toList();
    await ChatbotHistoryRepository.save(toSave);
  }

  /// İlk açılışta karşılama mesajı + 4 starter chip.
  ChatMessage _welcomeMessage() {
    return ChatMessage(
      id: 'b_welcome_${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.bot,
      text: 'Merhaba! Ben Samsun Asistan. Şehir hakkında ne öğrenmek istersin?',
      timestamp: DateTime.now(),
      payload: const ChatResponse(
        text: '',
        quickReplies: [
          QuickReply(
            label: 'Yakınımdaki yerler',
            payload: 'Yakınımdaki yerleri göster',
            icon: Icons.near_me_rounded,
          ),
          QuickReply(
            label: 'Bugünkü etkinlikler',
            payload: 'Bugün hangi etkinlikler var?',
            icon: Icons.event_rounded,
          ),
          QuickReply(
            label: 'Tarihi yerler',
            payload: 'Tarihi yerler öner',
            icon: Icons.museum_rounded,
          ),
          QuickReply(
            label: 'Yemek nerede yiyebilirim?',
            payload: 'Nerede yemek yiyebilirim?',
            icon: Icons.restaurant_rounded,
          ),
        ],
      ),
    );
  }

  /// Kullanıcının mesajını gönderir, bot cevabını işler.
  ///
  /// [fromQuickReply] true ise mesaj bir hızlı yanıt chip'inden gelmiştir;
  /// bu açık bir seçim olduğu için bağlam-birleştirme (combined routing)
  /// uygulanmaz — aksi halde "Etkinlikler" sonrası "Yer öner" chip'i
  /// kullanıcıyı tekrar etkinliklere yönlendiriyordu.
  Future<void> sendMessage(String text, {bool fromQuickReply = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isProcessing) return;

    // Çok uzun girdiyi (>500 karakter) kibarca kırp — model abuse koruması.
    final capped = trimmed.length > 500 ? trimmed.substring(0, 500) : trimmed;

    // 1) Kullanıcı mesajını listeye ekle + typing göster
    final userMsg = ChatMessage.user(capped);
    final typingMsg = ChatMessage.typing();
    state = state.copyWith(
      messages: [...state.messages, userMsg, typingMsg],
      isProcessing: true,
    );

    // Analytics — sadece intent_type loglanacak, içerik ASLA. (KVKK §6.9.6)
    _logEvent(AnalyticsEvents.chatbotMessageSent);

    // 2) Konum bağlamı — cache'te yoksa izinli ise lazy fetch.
    //    Bu sayede kullanıcı önce harita ekranına gitmeden de "yakındakiler"
    //    sorusunu sorabilir. İzin kapalıysa sessizce null kalır, handler
    //    graceful fallback üretir.
    var loc = ref.read(userLocationProvider);
    if (loc == null) {
      try {
        loc = await ref
            .read(userLocationProvider.notifier)
            .getOrFetch()
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // Timeout veya izin reddi — null kalır, handler graceful davranır.
        loc = null;
      }
    }
    final ctx = ChatContext(
      lastIntents: state.context.lastIntents,
      userLatitude: loc?.latitude ?? state.context.userLatitude,
      userLongitude: loc?.longitude ?? state.context.userLongitude,
      locale: state.context.locale,
    );

    // 3) NLU + handler dispatch — service akışı
    final service = ref.read(chatbotServiceProvider);
    final result = await service.resolve(
      rawText: capped,
      context: ctx,
      ref: ref,
      explicit: fromQuickReply,
    );

    // 4) Doğal hissetsin diye minimum 350 ms gecikme
    await Future<void>.delayed(const Duration(milliseconds: 350));

    // 5) Typing'i çıkar, gerçek cevabı ekle
    final withoutTyping =
        state.messages.where((m) => m.id != typingMsg.id).toList();
    state = state.copyWith(
      messages: [
        ...withoutTyping,
        ChatMessage.bot(result.response.text, payload: result.response),
      ],
      context: ctx.withNewIntent(result.intent),
      isProcessing: false,
    );

    // Analytics — niyet ve başarı (içerik yok!)
    _logEvent(
      AnalyticsEvents.chatbotIntentResolved,
      properties: {
        'intent': result.intent.name,
        'confidence': result.intent.confidence.toStringAsFixed(2),
        'card_count': result.response.cards.length,
        'is_fallback': result.intent.isFallback,
      },
    );

    // Persist (mikrotask — UI'ı bekletmesin)
    Future.microtask(_persist);
  }

  /// Quick reply chip tap'ı — payload'u mesaj olarak gönder.
  Future<void> sendQuickReply(QuickReply reply) async {
    _logEvent(AnalyticsEvents.chatbotQuickReplyTapped);
    await sendMessage(reply.payload, fromQuickReply: true);
  }

  /// "Sohbetimi sil" — KVKK §14.4.2 + §6.9.6.
  /// Hem in-memory state'i hem persisted SharedPreferences kaydını siler.
  Future<void> clearConversation() async {
    state = ChatbotState(messages: [_welcomeMessage()]);
    await ChatbotHistoryRepository.clear();
    _logEvent(AnalyticsEvents.chatbotCleared);
  }

  void _logEvent(String name, {Map<String, Object?>? properties}) {
    try {
      ref.read(analyticsServiceProvider).track(
            name,
            properties: properties,
          );
    } catch (_) {
      // Analytics fail olursa sohbet etkilenmesin.
    }
  }
}

/// Riverpod giriş noktası (Riverpod 3.x — NotifierProvider).
final chatbotProvider =
    NotifierProvider<ChatbotNotifier, ChatbotState>(ChatbotNotifier.new);
