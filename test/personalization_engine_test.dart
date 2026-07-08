import 'package:flutter_test/flutter_test.dart';
import 'package:sbb_mobile/data/models/place.dart';
import 'package:sbb_mobile/features/personalization/domain/interest_taxonomy.dart';
import 'package:sbb_mobile/features/personalization/domain/personalization_engine.dart';
import 'package:sbb_mobile/features/personalization/domain/personalization_profile.dart';

Place _place(
  String id, {
  String name = 'Test',
  String? category,
  List<String> tags = const [],
  List<String> subcategories = const [],
  bool featured = false,
  bool visited = false,
  String? arModelUrl,
}) {
  return Place(
    id: id,
    name: name,
    category: category,
    tags: tags,
    subcategories: subcategories,
    featured: featured,
    visited: visited,
    arModelUrl: arModelUrl,
  );
}

void main() {
  group('InterestTaxonomy.slugsForText', () {
    test('TR ve EN anahtar kelimeleri doğru slug üretir', () {
      expect(InterestTaxonomy.slugsForText('Tarihi Müze'), contains('historic'));
      expect(InterestTaxonomy.slugsForText('seaside beach'), contains('nature'));
      expect(InterestTaxonomy.slugsForText('lokanta restoran'),
          contains('food'));
    });

    test('eşleşme yoksa boş döner', () {
      expect(InterestTaxonomy.slugsForText('xyz qwerty'), isEmpty);
    });
  });

  group('PersonalizationEngine.resolvePlaceInterests', () {
    test('eşleşme yoksa boş döner', () {
      final p = _place('1', name: 'Nötr Yer'); // category null, categoryId null
      expect(
        PersonalizationEngine.resolvePlaceInterests(p, const {}),
        isEmpty,
      );
    });

    test('categoryId haritasından slug çözer (serbest metin olmadan)', () {
      final p = Place(id: '1', name: 'Bir Yer', categoryId: 7);
      final slugs = PersonalizationEngine.resolvePlaceInterests(p, {
        7: {'historic'},
      });
      expect(slugs, {'historic'});
    });

    test('categoryId eşleşmesi + metin + AR birleşir', () {
      final p = Place(
        id: '1',
        name: 'Amisos',
        categoryId: 7,
        category: 'lokanta', // food metin sinyali
        arModelUrl: 'https://x/m.glb',
      );
      final slugs = PersonalizationEngine.resolvePlaceInterests(p, {
        7: {'historic'},
      });
      expect(slugs, containsAll(<String>{'historic', 'food', 'ar_qr'}));
    });
  });

  group('PersonalizationEngine.scorePlace', () {
    test('boş profil her zaman 0 döner', () {
      final p = _place('1', category: 'Müze');
      expect(
        PersonalizationEngine.scorePlace(
            p, {'historic'}, PersonalizationProfile.empty, {}),
        0,
      );
    });

    test('boş slug seti 0 döner', () {
      final p = _place('1', category: 'Müze');
      expect(
        PersonalizationEngine.scorePlace(
            p, const <String>{}, const PersonalizationProfile({'historic': 1.0}), {}),
        0,
      );
    });

    test('ilgi eşleşmesi ağırlıkla ölçeklenir', () {
      final p = _place('1', category: 'Tarihi Müze');
      final full = PersonalizationEngine.scorePlace(
          p, {'historic'}, const PersonalizationProfile({'historic': 1.0}), {});
      final half = PersonalizationEngine.scorePlace(
          p, {'historic'}, const PersonalizationProfile({'historic': 0.5}), {});
      expect(full, greaterThan(half));
      expect(half, greaterThan(0));
    });

    test('ar_qr ilgisi + AR modeli ekstra puan verir', () {
      final withAr =
          _place('1', category: 'Müze', arModelUrl: 'https://x/model.glb');
      final withoutAr = _place('2', category: 'Müze');
      final profile = const PersonalizationProfile({'ar_qr': 1.0});
      expect(
        PersonalizationEngine.scorePlace(withAr, {'ar_qr'}, profile, {}),
        greaterThan(
          PersonalizationEngine.scorePlace(withoutAr, {'ar_qr'}, profile, {}),
        ),
      );
    });

    test('ziyaret edilmiş yer ceza alır', () {
      final fresh = _place('1', category: 'Müze');
      final seen = _place('2', category: 'Müze', visited: true);
      final profile = const PersonalizationProfile({'historic': 1.0});
      expect(
        PersonalizationEngine.scorePlace(fresh, {'historic'}, profile, {}),
        greaterThan(
          PersonalizationEngine.scorePlace(seen, {'historic'}, profile, {}),
        ),
      );
    });
  });

  group('PersonalizationEngine.rankByProfile', () {
    test('boş profilde giriş sırası korunur', () {
      final input = [
        _place('a', category: 'Müze'),
        _place('b', category: 'Restoran'),
        _place('c', category: 'Park'),
      ];
      final out = PersonalizationEngine.rankByProfile(
          input, PersonalizationProfile.empty, {}, {});
      expect(out.map((p) => p.id).toList(), ['a', 'b', 'c']);
    });

    test('ilgili yer öne çekilir, eşitlikte orijinal sıra korunur', () {
      final input = [
        _place('park', category: 'Park'), // nature
        _place('resto', category: 'lokanta'), // food (ilgi)
        _place('resto2', category: 'restoran'), // food (ilgi)
      ];
      final out = PersonalizationEngine.rankByProfile(
        input,
        const PersonalizationProfile({'food': 1.0}),
        const {},
        {},
      );
      // food eşleşenler başa, kendi aralarında giriş sırası korunur.
      expect(out.first.id, 'resto');
      expect(out[1].id, 'resto2');
      expect(out.last.id, 'park');
    });

    test('categoryId haritasıyla re-rank çalışır', () {
      final input = [
        Place(id: 'p1', name: 'Park', categoryId: 1), // nature
        Place(id: 'f1', name: 'Yer', categoryId: 2), // food (ilgi)
      ];
      final out = PersonalizationEngine.rankByProfile(
        input,
        const PersonalizationProfile({'food': 1.0}),
        {
          1: {'nature'},
          2: {'food'},
        },
        {},
      );
      expect(out.first.id, 'f1');
    });
  });
}
