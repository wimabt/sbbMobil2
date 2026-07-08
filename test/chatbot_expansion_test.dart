import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbb_mobile/features/chatbot/data/models/chat_intent.dart';
import 'package:sbb_mobile/features/chatbot/data/models/chat_response.dart';
import 'package:sbb_mobile/features/chatbot/domain/chatbot_service.dart';
import 'package:sbb_mobile/features/chatbot/domain/handlers/intent_handler.dart';
import 'package:sbb_mobile/features/chatbot/domain/nlu/intent_matcher.dart';

/// Kapsam genişletme + intent over-trigger düzeltmeleri için regresyon testleri.
class _EchoHandler extends IntentHandler {
  const _EchoHandler(this.name);
  final String name;
  @override
  String get intentName => name;
  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async =>
      ChatResponse(text: 'echo:${intent.name}');
}

void main() {
  group('Yeni intent tanıma', () {
    final cases = {
      'evet': 'affirm',
      'olur': 'affirm',
      'devam et': 'affirm',
      'tabii ki': 'affirm',
      'hayır': 'decline',
      'yeter': 'decline',
      'gerek yok': 'decline',
      'sen kimsin': 'identity',
      'robot musun': 'identity',
      'adın ne': 'identity',
      'espri yap': 'identity',
      'otobüs saatleri': 'transport',
      'toplu taşıma': 'transport',
      'tramvay': 'transport',
      'acil numaralar': 'emergency',
      'en yakın hastane': 'emergency',
      'nöbetçi eczane': 'emergency',
      '112': 'emergency',
    };

    cases.forEach((input, expected) {
      test('"$input" → $expected', () {
        final intent = IntentMatcher.match(input);
        expect(intent.name, expected,
            reason: 'conf=${intent.confidence}, score='
                '${intent.slot<double>('_raw_score')}');
      });
    });
  });

  group('Samsun-tercihi: şehir adı somut konuyu ezmemeli', () {
    test('"samsunda tarihi yerler öner" → category_query', () {
      expect(IntentMatcher.match('samsunda tarihi yerler öner').name,
          'category_query');
    });

    test('"samsun\'da bugün etkinlik var mı" → event_query', () {
      expect(IntentMatcher.match('samsunda bugün etkinlik var mı').name,
          'event_query');
    });

    test('"samsunda nerede yemek yiyebilirim" → recipe_query', () {
      expect(IntentMatcher.match('samsunda nerede yemek yiyebilirim').name,
          'recipe_query');
    });

    test('"samsun nedir" → samsun_info (somut konu yoksa korunur)', () {
      expect(IntentMatcher.match('samsun nedir').name, 'samsun_info');
    });

    test('"samsun hakkında bilgi" → samsun_info', () {
      expect(IntentMatcher.match('samsun hakkında bilgi').name, 'samsun_info');
    });

    test('çekim ekli "samsunun tarihi" mustContain önekiyle eşleşir', () {
      // 'samsunun' → 'samsun' önekiyle samsun_info gate'i geçer; somut konu yok.
      expect(IntentMatcher.match('samsunun tarihi').name, 'samsun_info');
    });
  });

  group('Over-trigger düzeltmeleri', () {
    test('"iyi yerler öner" greet DEĞİL category_query', () {
      expect(IntentMatcher.match('iyi yerler öner').name, 'category_query');
    });

    test('"çok güzel bir yer öner" feedback DEĞİL category_query', () {
      expect(IntentMatcher.match('çok güzel bir yer öner').name,
          'category_query');
    });

    test('"iyi akşamlar" hâlâ greet', () {
      expect(IntentMatcher.match('iyi akşamlar').name, 'greet');
    });

    test('"teşekkür ederim" hâlâ feedback', () {
      expect(IntentMatcher.match('teşekkür ederim').name, 'feedback');
    });
  });

  group('Service akışı: EN fallback + affirm continuation', () {
    late ProviderContainer container;
    late ChatbotService service;

    setUp(() {
      container = ProviderContainer();
      service = ChatbotService(
        overrideHandlers: {
          'affirm': const _EchoHandler('affirm'),
          'nearby_query': const _EchoHandler('nearby_query'),
        },
      );
    });
    tearDown(() => container.dispose());
    Ref makeRef() => container.read(_dummyProvider);

    test('Anlaşılmayan İngilizce cümle → english_fallback', () async {
      final r = await service.resolve(
        rawText: 'where can i find good food around here',
        context: const ChatContext(lastIntents: []),
        ref: makeRef(),
      );
      expect(r.intent.name, 'english_fallback');
      expect(r.response.quickReplies, isNotEmpty);
    });

    test('İngilizce "hello" yine de greet (TR sözlükte var)', () {
      expect(IntentMatcher.match('hello').name, 'greet');
    });

    test('"evet" → affirm intent olarak çözülür', () async {
      final r = await service.resolve(
        rawText: 'evet',
        context: const ChatContext(lastIntents: []),
        ref: makeRef(),
      );
      expect(r.intent.name, 'affirm');
    });
  });

  group('Bağlam tuzağı: etkinlik sonrası kategori chip\'i kilitlememeli', () {
    late ProviderContainer container;
    late ChatbotService service;

    setUp(() {
      container = ProviderContainer();
      service = ChatbotService(
        overrideHandlers: {
          'event_query': const _EchoHandler('event_query'),
          'category_query': const _EchoHandler('category_query'),
          'nearby_query': const _EchoHandler('nearby_query'),
          'recipe_query': const _EchoHandler('recipe_query'),
        },
      );
    });
    tearDown(() => container.dispose());
    Ref makeRef() => container.read(_dummyProvider);

    test('event → "Bana bir yer öner" CHIP (explicit) → category_query',
        () async {
      final ctx1 = ChatContext(lastIntents: const []);
      final r1 = await service.resolve(
        rawText: 'bugün etkinlik var mı',
        context: ctx1,
        ref: makeRef(),
      );
      expect(r1.intent.name, 'event_query');

      final ctx2 = ctx1.withNewIntent(r1.intent);
      final r2 = await service.resolve(
        rawText: 'Bana bir yer öner',
        context: ctx2,
        ref: makeRef(),
        explicit: true, // chip
      );
      expect(r2.intent.name, 'category_query',
          reason: 'Açık seçim etkinliklere kilitlenmemeli');
    });

    test('event → "yer öner" SERBEST METİN de artık category_query', () async {
      final ctx1 = ChatContext(lastIntents: const []);
      final r1 = await service.resolve(
        rawText: 'bugün etkinlik var mı',
        context: ctx1,
        ref: makeRef(),
      );
      final ctx2 = ctx1.withNewIntent(r1.intent);
      final r2 = await service.resolve(
        rawText: 'tarihi yerler öner',
        context: ctx2,
        ref: makeRef(),
      );
      expect(r2.intent.name, 'category_query',
          reason: 'event→category tuzak kuralı kaldırıldı');
    });

    test('serbest metin elliptik filtre hâlâ çalışır (nearby → yemek olanlar)',
        () async {
      final ctx1 = ChatContext(
        lastIntents: const [],
        userLatitude: 41.28,
        userLongitude: 36.33,
      );
      final r1 = await service.resolve(
        rawText: 'yakındaki yerler',
        context: ctx1,
        ref: makeRef(),
      );
      final ctx2 = ctx1.withNewIntent(r1.intent);
      final r2 = await service.resolve(
        rawText: 'yemek olanları',
        context: ctx2,
        ref: makeRef(),
      );
      expect(r2.intent.name, 'nearby_query');
      expect(r2.intent.slot<String>('category'), 'food');
    });
  });
}

final _dummyProvider = Provider<Ref>((ref) => ref);
