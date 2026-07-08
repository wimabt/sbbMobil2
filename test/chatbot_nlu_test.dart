import 'package:flutter_test/flutter_test.dart';
import 'package:sbb_mobile/features/chatbot/domain/nlu/entity_extractor.dart';
import 'package:sbb_mobile/features/chatbot/domain/nlu/intent_matcher.dart';
import 'package:sbb_mobile/features/chatbot/domain/nlu/text_normalizer.dart';

void main() {
  group('TextNormalizer', () {
    test('TR lowercase: İ→i, I→ı', () {
      expect(TextNormalizer.trLowerCase('İSTANBUL'), 'istanbul');
      expect(TextNormalizer.trLowerCase('TANIMA'), 'tanıma');
    });

    test('ASCII fold preserves intent', () {
      expect(TextNormalizer.asciiFold('şehir'), 'sehir');
      expect(TextNormalizer.asciiFold('görmeli'), 'gormeli');
      expect(TextNormalizer.asciiFold('müze'), 'muze');
    });

    test('strip punctuation', () {
      final out = TextNormalizer.stripPunctuation('Samsun\'da ne var? Bana söyle!');
      expect(out, isNot(contains('?')));
      expect(out, isNot(contains('!')));
      expect(out, isNot(contains("'")));
      expect(out.toLowerCase(), contains('samsun'));
    });

    test('full pipeline removes stopwords', () {
      final tokens = TextNormalizer.normalizeAndTokenize(
        'Bu yakındaki yerleri bana göster',
      );
      expect(tokens, contains('yakindaki'));
      expect(tokens, contains('yerleri'));
      expect(tokens, isNot(contains('bu')));
      expect(tokens, isNot(contains('bana')));
    });
  });

  group('IntentMatcher — golden inputs', () {
    final cases = {
      'merhaba': 'greet',
      'selam asistan': 'greet',
      'günaydın': 'greet',
      'neler yapabilirsin': 'help',
      'yardım eder misin': 'help',
      'teşekkür ederim': 'feedback',
      'sağ ol': 'feedback',
      'yakınımdaki yerler': 'nearby_query',
      'etrafımda ne var': 'nearby_query',
      'tarihi yerler öner': 'category_query',
      'müze öner': 'category_query',
      'park nerede': 'category_query',
      'bugün etkinlik var mı': 'event_query',
      'hafta sonu konser': 'event_query',
      'rota öner': 'route_query',
      'gezi rotası': 'route_query',
      'son duyurular neler': 'announcement_query',
      'samsun nedir': 'samsun_info',
      'samsun hakkında bilgi': 'samsun_info',
      'favorilerimi göster': 'favorites_query',
      'gezi planı oluştur': 'itinerary_help',
      'yöresel yemekler': 'recipe_query',
      'nerede yemek yiyebilirim': 'recipe_query',
      'atatürk anıtına nasıl giderim': 'directions',
      'amisos antik kenti nedir': 'place_detail',
    };

    cases.forEach((input, expected) {
      test('"$input" → $expected', () {
        final intent = IntentMatcher.match(input);
        expect(
          intent.name,
          expected,
          reason: 'Got "${intent.name}" with confidence ${intent.confidence}',
        );
      });
    });

    test('boş input fallback', () {
      expect(IntentMatcher.match('').name, 'fallback');
      expect(IntentMatcher.match('   ').name, 'fallback');
    });

    test('saçma input fallback', () {
      expect(IntentMatcher.match('xyzabc qwerty').name, 'fallback');
    });
  });

  group('EntityExtractor', () {
    test('kategori slot — tarihi', () {
      final slots = EntityExtractor.extract('tarihi yerler göster');
      expect(slots['category'], 'historical');
    });

    test('kategori slot — yemek', () {
      final slots = EntityExtractor.extract('nerede yemek yiyebilirim');
      expect(slots['category'], 'food');
    });

    test('zaman slot — bugün', () {
      final slots = EntityExtractor.extract('bugün etkinlik var mı');
      expect(slots['time'], 'today');
    });

    test('zaman slot — hafta sonu (uzun match wins)', () {
      final slots = EntityExtractor.extract('hafta sonu programı');
      expect(slots['time'], 'this_weekend');
    });

    test('mesafe slot — yakın', () {
      final slots = EntityExtractor.extract('yakın yerler');
      expect(slots['distance_km'], 2.5);
    });

    test('place hint — özel isim', () {
      final slots = EntityExtractor.extract('amisos hakkında');
      expect(slots['place_hint'], 'amisos');
    });

    test('boş slot — tek selam', () {
      final slots = EntityExtractor.extract('merhaba');
      expect(slots, isEmpty);
    });
  });
}
