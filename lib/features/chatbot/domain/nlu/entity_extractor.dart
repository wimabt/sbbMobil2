import '../../data/intent_dictionary.dart';
import '../../data/models/chat_intent.dart';
import 'text_normalizer.dart';

/// Niyetten bağımsız çalışan slot çıkarıcı.
///
/// Çıkardığı slot'lar:
/// - `category`: 8 değerden biri ([kCategorySlots])
/// - `time`: 5 değerden biri ([kTimeSlots])
/// - `distance_km`: km cinsinden double (mesafe modifier'larından)
/// - `place_hint`: muhtemel yer adı (intent_dictionary'den olmayan kelimeler
///   içinden çıkarılır; place_repository tarafında fuzzy match için ipucu)
class EntityExtractor {
  EntityExtractor._();

  static Map<String, dynamic> extract(String rawText) {
    final normalized = TextNormalizer.normalize(rawText);
    final tokens = TextNormalizer.tokenize(normalized);
    final tokenSet = tokens.toSet();
    final out = <String, dynamic>{};

    // Kategori slot ─────────────────────────────────────────────────────────
    final category = _extractCategory(normalized, tokenSet);
    if (category != null) out['category'] = category;

    // Featured/popüler bayrağı — boolean slot
    if (_isFeaturedQuery(normalized, tokenSet)) {
      out['featured'] = true;
    }

    // Zaman slot ────────────────────────────────────────────────────────────
    final time = _extractTime(normalized);
    if (time != null) out['time'] = time;

    // Mesafe slot ───────────────────────────────────────────────────────────
    final distance = _extractDistance(normalized);
    if (distance != null) out['distance_km'] = distance;

    // Yer adı ipucu — sözlükte olmayan kelimeler (potansiyel POI ismi)
    final placeHint = _extractPlaceHint(tokens);
    if (placeHint != null) out['place_hint'] = placeHint;

    return out;
  }

  static bool _isFeaturedQuery(String normalized, Set<String> tokens) {
    for (final kw in kFeaturedKeywords) {
      if (kw.contains(' ')) {
        if (normalized.contains(kw)) return true;
      } else if (tokens.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  static String? _extractCategory(String normalized, Set<String> tokens) {
    String? bestCategory;
    int bestHits = 0;

    for (final entry in kCategoryKeywords.entries) {
      var hits = 0;
      for (final kw in entry.value) {
        if (kw.contains(' ')) {
          // Çok kelimeli: "el sanatı"
          if (normalized.contains(kw)) hits++;
        } else if (tokens.contains(kw)) {
          hits++;
        }
      }
      if (hits > bestHits) {
        bestHits = hits;
        bestCategory = entry.key;
      }
    }
    return bestCategory;
  }

  static String? _extractTime(String normalized) {
    String? bestTime;
    int bestLen = 0;
    for (final entry in kTimeKeywords.entries) {
      for (final kw in entry.value) {
        if (normalized.contains(kw)) {
          // Daha uzun eşleşme tercih edilir ("hafta sonu" > "hafta")
          if (kw.length > bestLen) {
            bestLen = kw.length;
            bestTime = entry.key;
          }
        }
      }
    }
    return bestTime;
  }

  static double? _extractDistance(String normalized) {
    String? bucket;
    for (final entry in kDistanceKeywords.entries) {
      for (final kw in entry.value) {
        if (normalized.contains(kw)) {
          bucket = entry.key;
          break;
        }
      }
      if (bucket != null) break;
    }
    return bucket == null ? null : kDistanceSlots[bucket];
  }

  /// Sözlük kelimesi DEĞİL ve uzunluğu >= 4 olan token'lardan
  /// büyük olasılıkla place_name olan ipucu.
  ///
  /// Önemli not: gerçek isim eşleştirmesi place_detail_handler içinde
  /// place_repository üzerinden Levenshtein veya substring ile yapılacak.
  static String? _extractPlaceHint(List<String> tokens) {
    // Tüm sözlük keyword'lerini bir set'te topla — O(1) lookup
    final dictWords = <String>{};
    for (final def in kIntentDictionary.values) {
      dictWords.addAll(def.keywords);
      dictWords.addAll(def.stems);
    }
    for (final kws in kCategoryKeywords.values) {
      dictWords.addAll(kws);
    }
    for (final kws in kTimeKeywords.values) {
      dictWords.addAll(kws);
    }
    for (final kws in kDistanceKeywords.values) {
      dictWords.addAll(kws);
    }
    dictWords.addAll(kStopwords);

    for (final t in tokens) {
      if (t.length < 4) continue;
      if (dictWords.contains(t)) continue;
      // İlk uygun token'ı döndür — tipik olarak "Bandırma" gibi tek özel isim
      return t;
    }
    return null;
  }

  /// Niyet üzerine slot'ları yerleştirir.
  static ChatIntent enrich(ChatIntent intent, String rawText) {
    final slots = extract(rawText);
    if (slots.isEmpty) return intent;
    return intent.copyWith(slots: slots);
  }
}
