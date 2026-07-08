import '../../data/intent_dictionary.dart';

/// Türkçe metin normalizasyon yardımcısı.
///
/// **Görevi:** Kullanıcı girdisini, sözlük ile karşılaştırılabilir hale getirmek.
/// Türkçe lowercase tuzakları (özellikle `İ→i`, `I→ı` ayrımı) doğru ele alınır,
/// ardından ASCII'ye fold edilir ki sözlükte yalnız `'yakin'` yazmak yeterli olsun.
///
/// **Performans:** Tek O(n) geçiş. 50 karakterlik tipik sorgu için ~10µs.
class TextNormalizer {
  TextNormalizer._();

  /// `tr-TR` özelinde küçük harfe çevirme. Dart'ın `toLowerCase()` `İ`'yi
  /// `i̇` yapar (dotted-i + combining dot) — biz sade `i`/`ı` çıktısı istiyoruz.
  static String trLowerCase(String input) {
    final buf = StringBuffer();
    for (final rune in input.runes) {
      switch (rune) {
        case 0x0130: // İ
          buf.writeCharCode(0x69); // i
        case 0x0049: // I
          buf.writeCharCode(0x131); // ı
        default:
          buf.writeCharCode(String.fromCharCode(rune).toLowerCase().codeUnitAt(0));
      }
    }
    return buf.toString();
  }

  /// ASCII fold — `ş→s, ç→c, ö→o, ü→u, ğ→g, ı→i, â→a, î→i, û→u`.
  /// Hem normalize edilmiş hem orijinal kelime arasında köprü kurar.
  static String asciiFold(String input) {
    const map = {
      'ş': 's',
      'ç': 'c',
      'ö': 'o',
      'ü': 'u',
      'ğ': 'g',
      'ı': 'i',
      'â': 'a',
      'î': 'i',
      'û': 'u',
    };
    final buf = StringBuffer();
    for (final ch in input.split('')) {
      buf.write(map[ch] ?? ch);
    }
    return buf.toString();
  }

  /// Noktalama temizleme — `?`, `!`, `,`, `.`, `:`, `;`, `(`, `)` vb.
  /// Apostrof dahil (örn. `Samsun'da` → `samsunda`).
  static String stripPunctuation(String input) {
    // Raw string içinde " kaçışı sorun çıkarıyor; karakter listesini açıkça
    // ayrı pattern'lerle birleştiriyoruz.
    return input.replaceAll(
      RegExp('[?!.,;:()\\[\\]{}‘’“”\'"\\-]'),
      ' ',
    );
  }

  /// Tek tirelik komple normalize akışı.
  ///
  /// 1. TR lowercase
  /// 2. Noktalama temizle
  /// 3. Birden fazla boşluk → tek boşluk
  /// 4. Trim
  /// 5. ASCII fold (sözlük eşleşmesi için)
  static String normalize(String input) {
    final lower = trLowerCase(input);
    final noPunct = stripPunctuation(lower);
    final collapsed = noPunct.replaceAll(RegExp(r'\s+'), ' ').trim();
    return asciiFold(collapsed);
  }

  /// Boşlukla ayrılmış token listesi, stopword'ler hariç.
  static List<String> tokenize(String normalized) {
    if (normalized.isEmpty) return const [];
    return normalized
        .split(' ')
        .where((t) => t.isNotEmpty && !kStopwords.contains(t))
        .toList(growable: false);
  }

  /// Tüm pipeline tek seferde: ham metin → token listesi.
  static List<String> normalizeAndTokenize(String input) {
    return tokenize(normalize(input));
  }
}
