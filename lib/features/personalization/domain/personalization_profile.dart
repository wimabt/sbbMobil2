import 'package:flutter/foundation.dart';

/// Şartname §6.4 — Birleşik kişiselleştirme profili.
///
/// Kullanıcının **açık** ilgi alanlarını (onboarding / sunucu profili) ve
/// **örtük** davranış sinyallerini (ziyaret, favori, tamamlanan rota) tek bir
/// `slug → ağırlık` haritasında toplar. Ağırlık `(0, 1]` aralığındadır:
///   • Açık seçim          → 1.0 (baskın)
///   • Davranış-only slug   → ≤ 0.9 (sıklığa göre)
///
/// Boş harita = hiç sinyal yok (gerçek cold-start) → kişiselleştirme uygulanmaz,
/// mevcut (global) sıralama korunur.
@immutable
class PersonalizationProfile {
  const PersonalizationProfile(this.weights);

  /// slug → ağırlık. Değiştirilemez (unmodifiable) olması beklenir.
  final Map<String, double> weights;

  static const empty = PersonalizationProfile(<String, double>{});

  bool get isEmpty => weights.isEmpty;
  bool get isNotEmpty => weights.isNotEmpty;

  /// Bir slug'ın ağırlığı; yoksa 0.
  double weightFor(String slug) => weights[slug] ?? 0.0;

  /// Ağırlığa göre azalan sıralı slug listesi.
  List<String> get rankedSlugs {
    final entries = weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries) e.key];
  }

  @override
  bool operator ==(Object other) =>
      other is PersonalizationProfile && mapEquals(other.weights, weights);

  @override
  int get hashCode => Object.hashAll(
        weights.entries
            .map((e) => Object.hash(e.key, e.value))
            .toList(growable: false)
          ..sort(),
      );
}
