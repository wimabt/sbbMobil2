import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbb_mobile/features/chatbot/data/models/chat_intent.dart';
import 'package:sbb_mobile/features/chatbot/domain/chatbot_service.dart';
import 'package:sbb_mobile/features/chatbot/domain/handlers/intent_handler.dart';
import 'package:sbb_mobile/features/chatbot/data/models/chat_response.dart';

/// Mock handler — sadece intent'i echo eder, gerçek provider gerektirmez.
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
  ) async {
    return ChatResponse(
      text: 'echo:${intent.name}',
      followUpHint: intent.slots.toString(),
    );
  }
}

void main() {
  // Container — Ref'leri taklit etmek için gerçek ProviderContainer kullan
  late ProviderContainer container;
  late ChatbotService service;

  setUp(() {
    container = ProviderContainer();
    service = ChatbotService(
      overrideHandlers: {
        'greet': const _EchoHandler('greet'),
        'nearby_query': const _EchoHandler('nearby_query'),
        'category_query': const _EchoHandler('category_query'),
        'event_query': const _EchoHandler('event_query'),
      },
    );
  });

  tearDown(() => container.dispose());

  // Helper — provider tree gerektirmeden bir Ref örneği üretir.
  Ref makeRef() => container.read(_dummyProvider);

  group('Combined query routing', () {
    test('nearby_query → "yemek olanları" → effective nearby_query (yer arama)', () async {
      // İlk tur: yakındaki yerler
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
      expect(r1.intent.name, 'nearby_query');

      // İkinci tur: "yemek olanları" — recipe_query veya category_query
      // matchleyebilir, ama bağlam nearby'sa effective intent nearby_query olur.
      final ctx2 = ctx1.withNewIntent(r1.intent);
      final r2 = await service.resolve(
        rawText: 'yemek olanları',
        context: ctx2,
        ref: makeRef(),
      );
      expect(r2.intent.name, 'nearby_query',
          reason: 'Bağlam nearby olduğundan effective intent nearby_query');
      expect(r2.intent.slot<String>('_combined_from'), isNotNull,
          reason: 'Kombinasyon kaynağı (recipe_query veya category_query) saklanmalı');
      expect(r2.intent.slot<String>('category'), 'food');
    });

    test('category_query → nearby_query "yakındakiler" akışı', () async {
      final ctx1 = ChatContext(lastIntents: const []);
      final r1 = await service.resolve(
        rawText: 'tarihi yerler öner',
        context: ctx1,
        ref: makeRef(),
      );
      expect(r1.intent.name, 'category_query');

      final ctx2 = ctx1.withNewIntent(r1.intent);
      final r2 = await service.resolve(
        rawText: 'yakındakiler',
        context: ctx2,
        ref: makeRef(),
      );
      expect(r2.intent.name, 'nearby_query');
      expect(r2.intent.slot<String>('category'), 'historical');
    });

    test('nearby_query → event_query "etkinlikler" akışı', () async {
      final ctx1 = ChatContext(lastIntents: const []);
      final r1 = await service.resolve(
        rawText: 'yakındaki yerler',
        context: ctx1,
        ref: makeRef(),
      );

      final ctx2 = ctx1.withNewIntent(r1.intent);
      final r2 = await service.resolve(
        rawText: 'etkinlikler',
        context: ctx2,
        ref: makeRef(),
      );
      expect(r2.intent.name, 'event_query');
    });

    test('Bağımsız konu açılışı kombine etmez (selam → yakındakiler)', () async {
      final ctx1 = ChatContext(lastIntents: const []);
      final r1 = await service.resolve(
        rawText: 'merhaba',
        context: ctx1,
        ref: makeRef(),
      );

      final ctx2 = ctx1.withNewIntent(r1.intent);
      final r2 = await service.resolve(
        rawText: 'yakındaki yerler',
        context: ctx2,
        ref: makeRef(),
      );
      // greet+nearby kombinasyonda yok — direkt nearby_query
      expect(r2.intent.name, 'nearby_query');
      expect(r2.intent.slot<String>('_combined_from'), isNull);
    });
  });
}

// Dummy provider — Ref'i taklit etmek için tek bir noktada container'dan al.
final _dummyProvider = Provider<Ref>((ref) => ref);
