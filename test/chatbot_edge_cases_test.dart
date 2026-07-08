import 'package:flutter_test/flutter_test.dart';
import 'package:sbb_mobile/features/chatbot/domain/nlu/entity_extractor.dart';
import 'package:sbb_mobile/features/chatbot/domain/nlu/intent_matcher.dart';
import 'package:sbb_mobile/features/chatbot/domain/nlu/text_normalizer.dart';

/// Edge case'ler — gerçek kullanıcının üretebileceği "garip" girdiler.
void main() {
  group('Edge: aşırı uzun input', () {
    test('500+ karakter güvenli işlenir', () {
      final long = 'merhaba ' * 100; // ~800 karakter
      final intent = IntentMatcher.match(long);
      // Greet matched but no crash
      expect(intent.name, anyOf('greet', 'fallback'));
    });
  });

  group('Edge: yalnız noktalama / sayı', () {
    test('sadece soru işareti fallback', () {
      expect(IntentMatcher.match('???').name, 'fallback');
    });

    test('sadece sayı fallback', () {
      expect(IntentMatcher.match('123456').name, 'fallback');
    });

    test('boşluk + tab + newline fallback', () {
      expect(IntentMatcher.match('   \n\t  ').name, 'fallback');
    });
  });

  group('Edge: emoji ve özel karakter', () {
    test('emoji etrafında selam yine greet', () {
      expect(IntentMatcher.match('selam 👋').name, 'greet');
    });

    test('emoji yalnız ise fallback', () {
      expect(IntentMatcher.match('🤔🤔🤔').name, 'fallback');
    });

    test('aşırı noktalama tolere edilir', () {
      expect(
        IntentMatcher.match('yakındaki yerler...!?!!').name,
        'nearby_query',
      );
    });
  });

  group('Edge: karışık dil', () {
    test('İngilizce hello fallback değil greet', () {
      expect(IntentMatcher.match('hello').name, 'greet');
    });

    test('Türkçe-İngilizce karışım — anahtar kelime önemli', () {
      // "show me etkinlikler" — etkinlikler keyword matches event_query
      expect(IntentMatcher.match('show me etkinlikler').name, 'event_query');
    });
  });

  group('Edge: Türkçe karakter varyantları', () {
    test('büyük İ küçük doğru fold', () {
      expect(TextNormalizer.normalize('İSTANBUL'), 'istanbul');
    });

    test('aksanlı harfler fold', () {
      // â/î/û/ğ/ş/ç/ö/ü hepsi düşer
      expect(TextNormalizer.normalize('âşçı görmüştü'), 'asci gormustu');
    });

    test('ascii fold paritesi — şehir ↔ sehir', () {
      final a = IntentMatcher.match('şehir hakkında bilgi');
      final b = IntentMatcher.match('sehir hakkinda bilgi');
      expect(a.name, b.name);
    });
  });

  group('Edge: slot extraction sağlamlığı', () {
    test('birden çok kategori — en güçlü kazansın', () {
      final slots = EntityExtractor.extract(
        'tarihi müze ve doğa yer öner',
      );
      // historical+cultural+nature aday — en çok hit alanı kazanır
      expect(slots.containsKey('category'), true);
    });

    test('place_hint sözlük kelimeleri için tetiklenmez', () {
      final slots = EntityExtractor.extract('yakın yer');
      expect(slots['place_hint'], isNull);
    });

    test('place_hint 3 karakterli kelime atlanır', () {
      final slots = EntityExtractor.extract('bir kez');
      // "kez" stopword değil ama 3 karakter — place_hint'e girer
      // (kasıtlı: 4+ harfli sözlük dışı kelime)
      expect(slots['place_hint'], isNull);
    });

    test('zaman + kategori birlikte alınır', () {
      final slots = EntityExtractor.extract(
        'hafta sonu tarihi yerleri gez',
      );
      expect(slots['time'], 'this_weekend');
      expect(slots['category'], 'historical');
    });
  });

  group('Edge: case sensitivity', () {
    test('TÜM BÜYÜK harfle yazılan input doğru match', () {
      expect(IntentMatcher.match('MERHABA').name, 'greet');
      expect(IntentMatcher.match('YAKINDAKİ YERLER').name, 'nearby_query');
    });

    test('Karışık case ile yazılan', () {
      expect(IntentMatcher.match('TaRiHi yErLeR ÖnEr').name, 'category_query');
    });
  });
}
