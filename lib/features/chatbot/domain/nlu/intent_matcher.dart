import '../../data/intent_dictionary.dart';
import '../../data/models/chat_intent.dart';
import 'text_normalizer.dart';

/// Sözlük tabanlı niyet skorlama.
///
/// **Algoritma:**
/// ```
/// for each intent:
///   score += keyword_hits * 3.0
///   score += stem_hits     * 2.0
///   score += phrase_hits   * 2.5
///   score += priority_bias (50→0.5, 100→1.0)
///   if mustContain not satisfied → reset
/// ```
///
/// Skor en yüksek olan kazanır; eşik ([_minScore]) altında fallback'e düşülür.
///
/// **Performans:** 12 intent × ortalama 15 keyword = ~180 string karşılaştırma.
/// `Set<String>` kullanmıyoruz çünkü stem eşleşmesinde `startsWith` lazım.
/// Tipik sorgu: <2 ms.
class IntentMatcher {
  IntentMatcher._();

  /// Bir intent'in seçilmesi için minimum skor. Altı → fallback.
  static const double _minScore = 2.5;

  /// Skoru normalize ederken kullanılan üst sınır (confidence 0..1).
  static const double _scoreCeiling = 12.0;

  /// "Somut konu" intent'leri — kullanıcı bunlardan birini açıkça sorduysa,
  /// cümlede "samsun" geçse bile genel şehir tanıtımına (samsun_info) değil
  /// bu somut konuya gidilmeli.
  static const Set<String> _concreteTopics = {
    'nearby_query',
    'category_query',
    'event_query',
    'route_query',
    'announcement_query',
    'recipe_query',
    'favorites_query',
    'itinerary_help',
    'transport',
    'emergency',
    'directions',
  };

  /// Normalize edilmiş metin, samsun_info'nun "şehir hakkında" kalıplarından
  /// birini içeriyor mu? İçeriyorsa bu genel bir tanıtım sorgusudur ve
  /// samsun-tercihi demote'u uygulanmaz.
  static bool _matchedSamsunInfoPhrase(String normalized) {
    final def = kIntentDictionary['samsun_info'];
    if (def == null) return false;
    for (final phrase in def.phrases) {
      if (normalized.contains(phrase)) return true;
    }
    return false;
  }

  /// Ham mesaj → `ChatIntent` (en yüksek skorlu).
  static ChatIntent match(String rawText) {
    final ranked = matchAll(rawText);
    if (ranked.isEmpty) {
      return ChatIntent(
        name: 'fallback',
        confidence: 0.0,
        rawText: rawText,
        normalizedText: TextNormalizer.normalize(rawText),
      );
    }
    return ranked.first;
  }

  /// Tüm intent adaylarını skor sırasına göre döndürür.
  ///
  /// Belirsiz sorgularda "şunu mu kastettin?" clarification chip'leri için
  /// kullanılır. Skor < eşik olanlar dahildir — caller filtreler.
  static List<ChatIntent> matchAll(String rawText) {
    final normalized = TextNormalizer.normalize(rawText);
    final tokens = TextNormalizer.tokenize(normalized);

    if (tokens.isEmpty) {
      return const [];
    }

    final tokenSet = tokens.toSet();
    final scored = <(String, double)>[];

    for (final entry in kIntentDictionary.entries) {
      final def = entry.value;

      // mustContain kontrolü — kelime bulunmazsa intent diskalifiye.
      // Önek eşleşmesi de kabul edilir: 'samsun' → "Samsun'da" (samsunda),
      // "Samsun'un" (samsunun), "Samsun'a" (samsuna). Aksi halde çekim ekli
      // her kullanımda samsun_info elenir (memory: "tarama Türkçe ekleri kaçırır").
      if (def.mustContain.isNotEmpty &&
          !def.mustContain.every((m) =>
              tokenSet.contains(m) || tokens.any((t) => t.startsWith(m)))) {
        continue;
      }

      double score = 0.0;

      // mustContain karşılandıysa güçlü bonus — bu intent'in kendine özgü
      // anahtarı bulunmuş demek (örn. "samsun" → samsun_info).
      if (def.mustContain.isNotEmpty) {
        score += 5.0;
      }

      // Keyword hits — tam kelime eşleşmesi.
      // Eşleşen token'ları işaretle ki stem'de tekrar sayılmasın
      // (örn. "merhaba" hem keyword hem "merhab" stem'iyle — çift skor olmasın).
      final consumed = <String>{};
      for (final kw in def.keywords) {
        if (tokenSet.contains(kw)) {
          score += 3.0;
          consumed.add(kw);
        }
      }

      // Stem hits — token kök eşleşmesi (en az 4 harf, prefix match).
      // Keyword tarafından zaten tüketilmiş token'lar atlanır.
      for (final stem in def.stems) {
        if (stem.length < 3) continue;
        for (final t in tokens) {
          if (consumed.contains(t)) continue;
          if (t.length >= 4 && t.startsWith(stem)) {
            score += 2.0;
            consumed.add(t);
            break; // bir stem birden fazla token'da sayılmasın
          }
        }
      }

      // Phrase hits — ardışık bigram eşleşmesi
      if (def.phrases.isNotEmpty && tokens.length >= 2) {
        for (final phrase in def.phrases) {
          if (normalized.contains(phrase)) {
            score += 2.5;
          }
        }
      }

      // Priority bias — eşit skor durumunda yüksek priority kazansın
      if (score > 0) {
        score += def.priority / 200.0; // 100 priority → +0.5 bias
      }

      if (score > 0) {
        scored.add((def.name, score));
      }
    }

    if (scored.isEmpty) return const [];

    // En yüksek skor önde olacak şekilde sırala
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    // Samsun-tercihi: "samsun" kelimesi uygulamanın varsayılan bağlamıdır;
    // tek başına samsun_info'yu kazandırmamalı. Tepe aday samsun_info ise ve
    // somut bir konu (kategori/etkinlik/yemek/rota/yakın/duyuru/ulaşım) eşik
    // üstü skor almışsa, o somut konuyu öne al. Böylece "Samsun'da tarihi
    // yerler öner" → category_query.
    //
    // İstisna: Kullanıcı gerçekten "Samsun hakkında" bir KALIP kullandıysa
    // (örn. "samsun nedir", "samsunun tarihi", "samsun hakkında") bu genel
    // tanıtım sorgusudur → samsun_info korunur. "samsun" yalnız konum
    // niteleyici ("samsunda ... öner") olduğunda demote uygulanır.
    if (scored.first.$1 == 'samsun_info' &&
        !_matchedSamsunInfoPhrase(normalized)) {
      final concreteIdx = scored.indexWhere(
        (e) => e.$2 >= _minScore && _concreteTopics.contains(e.$1),
      );
      if (concreteIdx > 0) {
        final concrete = scored.removeAt(concreteIdx);
        scored.insert(0, concrete);
      }
    }

    return scored
        .map((e) => ChatIntent(
              name: e.$2 < _minScore ? 'fallback' : e.$1,
              confidence: (e.$2 / _scoreCeiling).clamp(0.0, 1.0),
              rawText: rawText,
              normalizedText: normalized,
              slots: {'_raw_score': e.$2},
            ))
        .toList(growable: false);
  }
}
