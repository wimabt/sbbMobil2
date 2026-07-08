import 'dart:math' as math;

/// Levenshtein tabanlı yumuşak metin eşleştirme.
///
/// **Kullanım amacı:** Kullanıcı bir yer adını hatalı yazdığında ("Atatrk" →
/// "Atatürk") veya iki harfi yer değiştirdiğinde ("Bandimra" → "Bandırma")
/// place_detail_handler yine de doğru POI'yi bulabilsin.
///
/// **Algoritma:**
/// 1. Klasik Levenshtein distance (DP, O(m·n))
/// 2. Skor → `1 - (distance / max(m, n))` (normalize edilmiş benzerlik 0..1)
/// 3. Token bazlı arama: query'nin her token'ı için en iyi candidate token
///    eşleşmesi seçilir; ortalama skor döndürülür.
///
/// **Performans bütçesi:**
/// - Tipik POI listesi: ~500 yer × ortalama 3 token = ~1500 string karşılaştırma
/// - Levenshtein tek karşılaştırma: ~10×10 matrix = 100 hücre
/// - Toplam tek sorgu: ~150K hücre = <5ms tipik mobilde
///
/// Threshold önerileri:
/// - 0.9+ → neredeyse kesin eşleşme (1 karakter hatası)
/// - 0.7–0.9 → yüksek olasılık (2 karakter hatası, küçük metin için)
/// - 0.5–0.7 → muhtemelen ama belirsiz
/// - <0.5 → eşleşme yok say
class FuzzyMatch {
  FuzzyMatch._();

  /// İki string arasındaki Levenshtein edit distance.
  ///
  /// Standard 3-operasyon: insertion, deletion, substitution. Her biri +1.
  static int distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // İki satırlı DP — bellek O(min(m,n))
    final m = a.length;
    final n = b.length;

    // a kısa olsun (bellek için)
    if (m > n) return distance(b, a);

    var prev = List<int>.generate(m + 1, (i) => i);
    var curr = List<int>.filled(m + 1, 0);

    for (var j = 1; j <= n; j++) {
      curr[0] = j;
      for (var i = 1; i <= m; i++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[i] = math.min(
          math.min(curr[i - 1] + 1, prev[i] + 1),
          prev[i - 1] + cost,
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }

    return prev[m];
  }

  /// Normalize edilmiş benzerlik skoru (0..1).
  /// 1.0 = tam aynı, 0.0 = hiç ortak yok.
  static double similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final d = distance(a, b);
    final maxLen = math.max(a.length, b.length);
    return 1.0 - (d / maxLen);
  }

  /// `query` ile `target` arasında token tabanlı en iyi skoru hesaplar.
  ///
  /// Query'nin her token'ı için target'taki en yakın token bulunur; ortalama
  /// alınır. 3 harf altı token'lar değerlendirilmez (gürültü).
  ///
  /// Örnek:
  /// - query="atatrk anıtı", target="Atatürk Anıtı" → ~0.93
  /// - query="bandirma", target="Bandırma Vapuru" → ~0.85
  /// - query="kale", target="Toraman Kalesi" → ~0.50 (kısmi)
  static double tokenSimilarity(String query, String target) {
    final qTokens = _tokens(query);
    final tTokens = _tokens(target);
    if (qTokens.isEmpty || tTokens.isEmpty) return 0.0;

    var totalScore = 0.0;
    for (final qt in qTokens) {
      var best = 0.0;
      for (final tt in tTokens) {
        final s = similarity(qt, tt);
        if (s > best) best = s;
      }
      totalScore += best;
    }
    return totalScore / qTokens.length;
  }

  /// `query`'yi `candidates`'a karşı eşleştirir, threshold üstü olanları döner.
  /// Skor azalan sırada.
  ///
  /// `extractor` her candidate'tan eşleştirilecek string'i çıkarır
  /// (örn. place.name).
  static List<FuzzyMatchResult<T>> rank<T>(
    String query,
    List<T> candidates, {
    required String Function(T) extractor,
    double threshold = 0.7,
    int? limit,
  }) {
    final results = <FuzzyMatchResult<T>>[];
    for (final c in candidates) {
      final target = extractor(c);
      if (target.isEmpty) continue;
      final score = tokenSimilarity(query, target);
      if (score >= threshold) {
        results.add(FuzzyMatchResult(item: c, score: score));
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    if (limit != null && results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  static List<String> _tokens(String s) {
    return s
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3)
        .toList(growable: false);
  }
}

class FuzzyMatchResult<T> {
  const FuzzyMatchResult({required this.item, required this.score});
  final T item;
  final double score;
}
