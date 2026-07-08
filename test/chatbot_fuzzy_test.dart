import 'package:flutter_test/flutter_test.dart';
import 'package:sbb_mobile/features/chatbot/domain/nlu/fuzzy_match.dart';

void main() {
  group('FuzzyMatch.distance', () {
    test('aynı string → 0', () {
      expect(FuzzyMatch.distance('kale', 'kale'), 0);
    });

    test('boş string → diğerinin uzunluğu', () {
      expect(FuzzyMatch.distance('', 'samsun'), 6);
      expect(FuzzyMatch.distance('samsun', ''), 6);
    });

    test('tek harf değişim → 1', () {
      expect(FuzzyMatch.distance('kale', 'kala'), 1);
    });

    test('tek harf silme → 1', () {
      expect(FuzzyMatch.distance('atatrk', 'atatürk'), 1);
    });

    test('iki ardışık harf substitution', () {
      // "kabe" vs "kale" → b/l = 1 substitution
      expect(FuzzyMatch.distance('kabe', 'kale'), 1);
      // "atte" vs "atta" → t/t aynı, t/t aynı, e/a = 1
      expect(FuzzyMatch.distance('atte', 'atta'), 1);
    });
  });

  group('FuzzyMatch.similarity', () {
    test('aynı string → 1.0', () {
      expect(FuzzyMatch.similarity('kale', 'kale'), 1.0);
    });

    test('1-harf hatası ~0.8+', () {
      final s = FuzzyMatch.similarity('atatrk', 'atatürk');
      expect(s, greaterThan(0.8));
      expect(s, lessThan(1.0));
    });

    test('tamamen farklı → düşük skor', () {
      final s = FuzzyMatch.similarity('selam', 'kapısı');
      expect(s, lessThan(0.5));
    });
  });

  group('FuzzyMatch.tokenSimilarity', () {
    test('tek typo ile yer adı tespiti', () {
      // "atatrk anıtı" → "Atatürk Anıtı"
      final s = FuzzyMatch.tokenSimilarity(
        'atatrk anıtı',
        'atatürk anıtı',
      );
      expect(s, greaterThan(0.85),
          reason: 'Tek harf typo yine de yüksek skor vermeli');
    });

    test('tam isim eşleşmesi → 1.0', () {
      final s = FuzzyMatch.tokenSimilarity(
        'atatürk anıtı',
        'atatürk anıtı',
      );
      expect(s, 1.0);
    });

    test('kısmi eşleşme — tek doğru token, biri yanlış', () {
      final s = FuzzyMatch.tokenSimilarity(
        'bandirma vapuru',
        'bandırma vapuru',
      );
      expect(s, greaterThan(0.85));
    });

    test('alakasız metin → düşük skor', () {
      final s = FuzzyMatch.tokenSimilarity('kale', 'restoran menüsü');
      expect(s, lessThan(0.5));
    });
  });

  group('FuzzyMatch.rank', () {
    final places = [
      _Item('Atatürk Anıtı'),
      _Item('Atatürk Müzesi'),
      _Item('Bandırma Vapuru'),
      _Item('Amisos Tepesi'),
      _Item('Toraman Kalesi'),
    ];

    test('typo ile sıralama doğru', () {
      final results = FuzzyMatch.rank<_Item>(
        'atatrk anıtı',
        places,
        extractor: (i) => i.name.toLowerCase(),
        threshold: 0.7,
      );
      expect(results.isNotEmpty, true);
      expect(results.first.item.name, 'Atatürk Anıtı');
    });

    test('threshold filtresi çalışıyor', () {
      // Hiç tutmayan query → boş sonuç
      final results = FuzzyMatch.rank<_Item>(
        'qwertyasdf zxcv',
        places,
        extractor: (i) => i.name.toLowerCase(),
        threshold: 0.7,
      );
      expect(results, isEmpty);
    });

    test('limit uygulanır', () {
      final results = FuzzyMatch.rank<_Item>(
        'atatürk',
        places,
        extractor: (i) => i.name.toLowerCase(),
        threshold: 0.3,
        limit: 1,
      );
      expect(results.length, 1);
      expect(results.first.item.name, contains('Atatürk'));
    });
  });
}

class _Item {
  const _Item(this.name);
  final String name;
}
