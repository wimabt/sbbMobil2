import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_intent.dart';
import '../data/models/chat_response.dart';
import 'handlers/affirm_handler.dart';
import 'handlers/announcement_handler.dart';
import 'handlers/category_handler.dart';
import 'handlers/decline_handler.dart';
import 'handlers/directions_handler.dart';
import 'handlers/emergency_handler.dart';
import 'handlers/event_handler.dart';
import 'handlers/fallback_handler.dart';
import 'handlers/favorites_handler.dart';
import 'handlers/feedback_handler.dart';
import 'handlers/greet_handler.dart';
import 'handlers/help_handler.dart';
import 'handlers/identity_handler.dart';
import 'handlers/intent_handler.dart';
import 'handlers/itinerary_help_handler.dart';
import 'handlers/nearby_handler.dart';
import 'handlers/place_detail_handler.dart';
import 'handlers/recipe_handler.dart';
import 'handlers/route_handler.dart';
import 'handlers/samsun_info_handler.dart';
import 'handlers/transport_handler.dart';
import 'nlu/entity_extractor.dart';
import 'nlu/intent_matcher.dart';
import 'nlu/text_normalizer.dart';

/// Tüm chatbot zincirinin orkestratoru: ham metin → cevap.
///
/// Akış:
/// ```
/// userText
///   ↓ IntentMatcher.match
///   ↓ EntityExtractor.enrich (slot dolumu)
///   ↓ ContextResolver (önceki intent'ten slot taşı)
///   ↓ _handlerFor(intent.name).handle(intent, context, ref)
///   ↓ ChatResponse
/// ```
///
/// **Genişletilebilirlik (§6.9.7.1):** İleride LLM eklemek için
/// `_resolveHandler` içinde fallback yerine `LlmHandler` döndürmek yeterli.
class ChatbotService {
  ChatbotService({
    Map<String, IntentHandler>? overrideHandlers,
  }) : _handlers = overrideHandlers ?? _defaultHandlers();

  final Map<String, IntentHandler> _handlers;

  static const IntentHandler _fallback = FallbackHandler();

  static Map<String, IntentHandler> _defaultHandlers() {
    // Core (3) + Discovery (5) + Detail (3) + Personal (3)
    // + Smalltalk (3: affirm/decline/identity) + Practical (2: transport/emergency)
    // = 19 handler + fallback (sınıf seviyesinde). Sözlükteki tüm intent'ler.
    const handlers = <IntentHandler>[
      // Core
      GreetHandler(),
      HelpHandler(),
      FeedbackHandler(),
      // Discovery
      NearbyHandler(),
      CategoryHandler(),
      EventHandler(),
      RouteHandler(),
      AnnouncementHandler(),
      // Detail
      PlaceDetailHandler(),
      DirectionsHandler(),
      SamsunInfoHandler(),
      // Personal
      FavoritesHandler(),
      ItineraryHelpHandler(),
      RecipeHandler(),
      // Conversation & smalltalk
      AffirmHandler(),
      DeclineHandler(),
      IdentityHandler(),
      // Practical info
      TransportHandler(),
      EmergencyHandler(),
    ];
    return {for (final h in handlers) h.intentName: h};
  }

  /// Yeni handler enjekte (Faz 3+ için public API).
  void register(IntentHandler handler) {
    _handlers[handler.intentName] = handler;
  }

  /// Clarification eşikleri.
  ///
  /// Mantık: İlk ve ikinci adayın arasındaki fark çok azsa (her ikisi de
  /// _minScore üstündeyse) kullanıcı belirsiz konuşmuştur — "şunu mu
  /// kastettin?" diye sor. Tek dominant intent varsa direkt cevap ver.
  static const double _ambiguityGapThreshold = 1.5;

  /// Smalltalk / akış intent'leri — clarification'da içerik adayı sayılmaz.
  static const Set<String> _smalltalkIntents = {
    'greet',
    'feedback',
    'affirm',
    'decline',
    'identity',
    'help',
  };

  /// Ham metin → cevap. Tek public entry point.
  ///
  /// [explicit] true ise mesaj kullanıcının açık seçimidir (hızlı yanıt
  /// chip'ine basmak gibi) ve **bağlam-birleştirme uygulanmaz**: chip'in
  /// payload'u zaten net bir niyettir, "önceki konunun devamı" sayılıp
  /// yeniden yorumlanmamalı. Aksi halde "Etkinlikler" sonrası "Yer öner"e
  /// basmak kullanıcıyı etkinliklere kilitliyordu.
  Future<({ChatIntent intent, ChatResponse response})> resolve({
    required String rawText,
    required ChatContext context,
    required Ref ref,
    bool explicit = false,
  }) async {
    // 1) NLU — tüm aday intent'leri skor sırasıyla al
    final ranked = IntentMatcher.matchAll(rawText);
    final rawIntent = ranked.isEmpty
        ? ChatIntent(
            name: 'fallback',
            confidence: 0.0,
            rawText: rawText,
            normalizedText: rawText.toLowerCase(),
          )
        : ranked.first;

    // 1.5) Minimal İngilizce fallback — Türkçe NLU hiçbir şey yakalamadıysa
    //      ve metin belirgin şekilde İngilizceyse, kibarca Türkçe'ye yönlendir.
    //      ("hello", "help", "thanks" zaten TR sözlükte var; bu yalnız
    //      anlaşılmayan İngilizce cümleler için devreye girer.)
    if (rawIntent.isFallback && _looksEnglish(rawText)) {
      return (
        intent: rawIntent.copyWith(name: 'english_fallback'),
        response: _englishFallbackResponse(),
      );
    }

    // 2) Slot extraction
    final enriched = EntityExtractor.enrich(rawIntent, rawText);

    // 3-4) Bağlam taşıma + birleşik yönlendirme — YALNIZCA serbest metinde.
    //      Açık seçimlerde (chip) kullanıcının niyeti aynen korunur.
    final effective = explicit
        ? enriched
        : _resolveCombinedRouting(_carryContextSlots(enriched, context));

    // 5) Clarification kontrolü — top-2 gap'a göre. İki aday da minScore
    //    üstündeyse ve aralarındaki fark _ambiguityGapThreshold altındaysa,
    //    direkt cevap yerine "şunu mu demek istedin?" chip'leri sun.
    //    Combined akıştan gelenler zaten bağlamla netleşmiş sayılır.
    final isCombined = effective.slot<String>('_combined_from') != null;
    if (!explicit && !isCombined && !effective.isFallback && ranked.length >= 2) {
      final topScore = (ranked[0].slot<double>('_raw_score') ?? 0.0);
      final secondScore = (ranked[1].slot<double>('_raw_score') ?? 0.0);
      // Clarification yalnızca İKİ İÇERİK intent'i yarışırken anlamlı. Adaylardan
      // biri smalltalk ise (selam/teşekkür/onay vb.) "şunu mu demek istedin?"
      // sormak yerine doğrudan en olası içeriğe cevap ver. Bu, "çok güzel bir
      // yer öner" tipindeki cümlelerde feedback ile category çakışmasını önler.
      final bothContent = !_smalltalkIntents.contains(ranked[0].name) &&
          !_smalltalkIntents.contains(ranked[1].name);
      if (bothContent &&
          secondScore >= 2.5 &&
          (topScore - secondScore) < _ambiguityGapThreshold) {
        return (
          intent: effective.copyWith(name: 'clarification'),
          response: _buildClarification(ranked),
        );
      }
    }

    // 6) Handler dispatch
    final handler = _resolveHandler(effective);
    final response = await handler.handle(effective, context, ref);

    return (intent: effective, response: response);
  }

  /// Top 2-3 adaydan "şunu mu kastettin?" yanıtı oluşturur.
  ChatResponse _buildClarification(List<ChatIntent> ranked) {
    // En yüksek 3 farklı intent (fallback dışı)
    final unique = <String>{};
    final picks = <ChatIntent>[];
    for (final r in ranked) {
      if (r.name == 'fallback') continue;
      if (unique.add(r.name)) picks.add(r);
      if (picks.length >= 3) break;
    }

    if (picks.isEmpty) {
      // Garanti olsun: hiç aday yoksa standart fallback metni
      return const ChatResponse(
        text: 'Tam anlamadım. Şunlardan biri yardımcı olabilir mi?',
        quickReplies: [
          QuickReply(
            label: 'Yakındakiler',
            payload: 'Yakınımdaki yerler',
            icon: Icons.near_me_rounded,
          ),
          QuickReply(
            label: 'Etkinlikler',
            payload: 'Yaklaşan etkinlikler',
            icon: Icons.event_rounded,
          ),
        ],
      );
    }

    final replies = picks
        .map(
          (p) => QuickReply(
            label: _clarifyLabel(p.name),
            payload: _clarifyPayload(p.name),
            icon: _clarifyIcon(p.name),
          ),
        )
        .toList(growable: false);

    return ChatResponse(
      text: 'Tam emin olamadım — şunlardan birini mi sormak istedin?',
      quickReplies: replies,
      followUpHint: 'Daha açıklayıcı yazarsan da olur. Örnek: "tarihi yerler" '
          'veya "bu hafta sonu etkinlik".',
    );
  }

  // Clarification chip etiketleri — kullanıcı dostu, intent slug'larından
  // doğal Türkçe ifadelere çevirir.
  String _clarifyLabel(String intent) => switch (intent) {
        'nearby_query' => 'Yakındaki yerler',
        'category_query' => 'Bir kategoride yer',
        'event_query' => 'Etkinlikler',
        'route_query' => 'Hazır rotalar',
        'announcement_query' => 'Son duyurular',
        'place_detail' => 'Bir yer hakkında bilgi',
        'directions' => 'Yol tarifi',
        'samsun_info' => 'Samsun hakkında',
        'favorites_query' => 'Favorilerim',
        'itinerary_help' => 'Gezi planı',
        'recipe_query' => 'Yöresel yemek',
        'transport' => 'Ulaşım',
        'emergency' => 'Acil numaralar',
        'identity' => 'Sen kimsin?',
        'greet' => 'Sadece selam',
        'help' => 'Yardım',
        'feedback' => 'Teşekkür',
        _ => intent,
      };

  String _clarifyPayload(String intent) => switch (intent) {
        'nearby_query' => 'Yakınımdaki yerleri göster',
        'category_query' => 'Bir yer öner',
        'event_query' => 'Yaklaşan etkinlikler',
        'route_query' => 'Hazır rotaları göster',
        'announcement_query' => 'Son duyurular',
        'place_detail' => 'Bir yer hakkında bilgi ver',
        'directions' => 'Yol tarifi',
        'samsun_info' => 'Samsun hakkında bilgi',
        'favorites_query' => 'Favorilerimi göster',
        'itinerary_help' => 'Gezi planı oluştur',
        'recipe_query' => 'Yöresel yemek öner',
        'transport' => 'Ulaşım bilgisi',
        'emergency' => 'Acil numaralar',
        'identity' => 'Sen kimsin?',
        'greet' => 'Merhaba',
        'help' => 'Neler yapabilirsin?',
        _ => intent,
      };

  IconData _clarifyIcon(String intent) => switch (intent) {
        'nearby_query' => Icons.near_me_rounded,
        'category_query' => Icons.category_rounded,
        'event_query' => Icons.event_rounded,
        'route_query' => Icons.alt_route_rounded,
        'announcement_query' => Icons.campaign_rounded,
        'place_detail' => Icons.info_outline_rounded,
        'directions' => Icons.directions_rounded,
        'samsun_info' => Icons.location_city_rounded,
        'favorites_query' => Icons.favorite_rounded,
        'itinerary_help' => Icons.event_note_rounded,
        'recipe_query' => Icons.restaurant_rounded,
        'transport' => Icons.directions_bus_rounded,
        'emergency' => Icons.emergency_rounded,
        'identity' => Icons.smart_toy_rounded,
        'greet' => Icons.waving_hand_rounded,
        'help' => Icons.help_outline_rounded,
        _ => Icons.chat_bubble_outline_rounded,
      };

  IntentHandler _resolveHandler(ChatIntent intent) {
    if (intent.isFallback) return _fallback;
    return _handlers[intent.name] ?? _fallback;
  }

  // ─── İngilizce minimal fallback ───────────────────────────────────────────

  /// Belirgin İngilizce göstergesi olan kelimeler. Türkçe NLU eşleşmediğinde,
  /// bunlardan ≥2 tane geçiyorsa metin İngilizce sayılır.
  static const Set<String> _englishMarkers = {
    'the', 'what', 'where', 'when', 'how', 'why', 'who', 'which',
    'can', 'could', 'would', 'should', 'you', 'your', 'are', 'is', 'am',
    'do', 'does', 'did', 'want', 'need', 'near', 'me', 'my', 'place',
    'places', 'food', 'eat', 'restaurant', 'event', 'events', 'show',
    'tell', 'find', 'please', 'around', 'here', 'there', 'recommend',
    'visit', 'see', 'best', 'top', 'good', 'morning', 'evening',
    'something', 'anything', 'about', 'this', 'that', 'and', 'for',
    'with', 'have', 'give', 'looking', 'nearby', 'history', 'museum',
  };

  bool _looksEnglish(String rawText) {
    final tokens = TextNormalizer.normalizeAndTokenize(rawText);
    if (tokens.isEmpty) return false;
    var hits = 0;
    for (final t in tokens) {
      if (_englishMarkers.contains(t)) {
        hits++;
        if (hits >= 2) return true;
      }
    }
    return false;
  }

  ChatResponse _englishFallbackResponse() {
    return const ChatResponse(
      text: 'Hi! For now I understand Turkish best. 🙂 You can tap a '
          'suggestion below, or type in Turkish — for example: '
          '"Yakınımda ne var?" (What\'s near me?).',
      quickReplies: [
        QuickReply(
          label: 'Nearby places',
          payload: 'Yakınımdaki yerleri göster',
          icon: Icons.near_me_rounded,
        ),
        QuickReply(
          label: 'Events',
          payload: 'Yaklaşan etkinlikler',
          icon: Icons.event_rounded,
        ),
        QuickReply(
          label: 'About Samsun',
          payload: 'Samsun hakkında bilgi',
          icon: Icons.location_city_rounded,
        ),
      ],
      followUpHint: 'Tip: Turkish works best — "tarihi yerler", '
          '"hafta sonu etkinlik", "nerede yemek yiyebilirim".',
    );
  }

  /// Önceki intent'in henüz kullanılmayan slot'larını yeni intent'e taşır.
  ///
  /// Örn:
  /// - t1: "Yakınımdaki yerler" → intent=nearby_query, slots={}
  /// - t2: "Yemek olanlar?"     → intent=category_query, slots={category:food}
  ///   sonuç: category_query + slots={category:food, _prev:nearby_query}
  ChatIntent _carryContextSlots(ChatIntent current, ChatContext context) {
    final prev = context.previousIntent;
    if (prev == null) return current;

    final merged = <String, dynamic>{...prev.slots, ...current.slots};
    if (prev.name != current.name) {
      merged['_prev_intent'] = prev.name;
    }
    // Önceki intent'in adını ayrıca dolaylı slot olarak da koru (debugging için)
    return current.copyWith(slots: merged);
  }

  /// Intent çiftlerini tek bir effective intent'e yönlendirir.
  ///
  /// **Kombinasyon kuralları:**
  ///
  /// | Önceki        | Şimdiki        | Effective       | Sebep                       |
  /// |---------------|----------------|-----------------|-----------------------------|
  /// | nearby_query  | category_query | nearby_query    | "yakındakiler → yemek olan" |
  /// | category_query| nearby_query   | nearby_query    | "tarihi → yakındakiler"     |
  /// | event_query   | category_query | event_query     | "etkinlik → bedava olan"    |
  /// | nearby_query  | event_query    | event_query     | "yakındakiler → etkinlik"   |
  ///
  /// Yalnızca [_combinationMap]'te tanımlı (prev, current) çiftleri yeniden
  /// yönlendirilir; tanımsız çiftlerde kullanıcının yeni intent'i aynen korunur.
  ChatIntent _resolveCombinedRouting(ChatIntent current) {
    final prevName = current.slot<String>('_prev_intent');
    if (prevName == null || current.isFallback) return current;

    // Kombinasyon map'i zaten "bağlama uygun mu?" sorusunu cevaplar.
    // Map'te olmayan çiftler için kombi yapılmaz; olanlar için her zaman yapılır.
    final routing = _combinationMap[(prevName, current.name)];
    if (routing == null) return current;

    // Aynı intent'e routing yapılıyorsa (kombi yok) early return
    if (routing == current.name) {
      return current.copyWith(slots: {
        ...current.slots,
        '_combined_from': current.name,
      });
    }

    return current.copyWith(
      name: routing,
      slots: {
        ...current.slots,
        '_combined_from': current.name,
      },
    );
  }

  /// Combined query routing table.
  ///
  /// Genişletme: yeni bir kombinasyon eklemek için sadece map'e satır eklenir.
  static const Map<(String, String), String> _combinationMap = {
    // (prev_intent, current_intent) → effective_intent
    //
    // Kural: birleştirme YALNIZCA kullanıcının yeni mesajını anlamlı kılan
    // (elliptik filtre) durumlarda yapılır ve sonucu kullanıcının açıkça
    // istediği konudan UZAKLAŞTIRMAMALIDIR. Örn. "yakındakiler" → "yemek
    // olanlar" → yakındaki yemek yerleri. Aşağıdaki çiftler bu kurala uyar.
    //
    // ÖNEMLİ: "event → category" ve "event → recipe" gibi, kullanıcı yeni bir
    // konu açmasına rağmen onu etkinliklere geri çeken kurallar KASTEN
    // kaldırıldı (kullanıcıyı bir konuya hapsediyordu).
    ('nearby_query', 'category_query'): 'nearby_query',
    ('category_query', 'nearby_query'): 'nearby_query',
    ('nearby_query', 'event_query'): 'event_query',
    ('event_query', 'nearby_query'): 'nearby_query',
    ('category_query', 'event_query'): 'event_query',
    // Bağlam nearby'sa "yemek/restoran" tarif değil yer demektir.
    ('nearby_query', 'recipe_query'): 'nearby_query',
  };
}

/// Riverpod provider — singleton service.
final chatbotServiceProvider = Provider<ChatbotService>((ref) {
  return ChatbotService();
});
