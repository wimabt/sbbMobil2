import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/place.dart';
import '../../../places/presentation/providers/places_provider.dart';
import '../../data/models/chat_intent.dart';
import '../../data/models/chat_response.dart';
import '../nlu/fuzzy_match.dart';
import '../nlu/text_normalizer.dart';
import 'handler_utils.dart';
import 'intent_handler.dart';

/// "X nedir / X hakkında bilgi" — `place_detail` intent.
///
/// Fuzzy yer adı eşleştirme:
///   1. place_hint slot'u varsa onunla
///   2. yoksa rawText içinde geçen 3+ harfli tüm token'ları dene
///
/// Eşleşme stratejisi:
///   - Tam isim içeren token → +5
///   - İlk kelime eşleşmesi   → +3
///   - 70%+ substring overlap → +2
///
/// Tek bir net eşleşme varsa detay kartı + "Detayını aç"; çoklu eşleşmede üst 3.
class PlaceDetailHandler extends IntentHandler {
  const PlaceDetailHandler();

  static const int _maxInline = 3;

  @override
  String get intentName => 'place_detail';

  @override
  Future<ChatResponse> handle(
    ChatIntent intent,
    ChatContext context,
    Ref ref,
  ) async {
    await waitForData(
      check: () {
        final s = ref.read(placesProvider);
        return !s.isLoading || s.allPlaces.isNotEmpty;
      },
    );

    final allPlaces = ref.read(placesProvider).allPlaces;
    if (allPlaces.isEmpty) {
      return const ChatResponse(
        text: 'Mekan listesi henüz yüklenmedi. Bir saniye sonra tekrar dener '
            'misin?',
      );
    }

    final hint = intent.slot<String>('place_hint');
    final searchTokens = _candidateTokens(intent.normalizedText, hint);

    if (searchTokens.isEmpty) {
      return const ChatResponse(
        text: 'Hangi mekanı sorduğunu anlayamadım. İsmi yazar mısın? '
            'Örnek: "Atatürk Anıtı hakkında bilgi" veya "Amisos nedir?"',
      );
    }

    final matches = _findMatches(allPlaces, searchTokens);

    if (matches.isEmpty) {
      return ChatResponse(
        text: 'Bu adı taşıyan bir mekan bulamadım. Belki şunlardan biri?',
        quickReplies: const [
          QuickReply(
            label: 'Popüler yerler',
            payload: 'Popüler yerleri göster',
            icon: Icons.star_outline_rounded,
          ),
          QuickReply(
            label: 'Tarihi yerler',
            payload: 'Tarihi yerler öner',
            icon: Icons.museum_rounded,
          ),
          QuickReply(
            label: 'Doğa keşfi',
            payload: 'Doğa yerleri',
            icon: Icons.park_rounded,
          ),
        ],
      );
    }

    // Tek net eşleşme — anlatım odaklı cevap
    if (matches.length == 1) {
      final p = matches.first.place;
      final desc = (p.description ?? '').trim();
      final summary = desc.isEmpty
          ? '${p.name} hakkında detay sayfasına geç:'
          : _summary(p);

      return ChatResponse(
        text: summary,
        cards: [
          ChatCard(
            type: ChatCardType.place,
            title: p.name,
            subtitle: p.category,
            imageUrl: p.imageUrl,
            targetRoute: '/places/${p.id}',
          ),
        ],
        quickReplies: [
          QuickReply(
            label: 'Detayını aç',
            payload: 'Detayını aç',
            icon: Icons.open_in_new_rounded,
            navigateTo: '/places/${p.id}',
          ),
          const QuickReply(
            label: 'Haritada göster',
            payload: 'Haritayı aç',
            icon: Icons.map_rounded,
            navigateTo: '/map',
          ),
          const QuickReply(
            label: 'Benzer yerler',
            payload: 'Benzer yerler öner',
            icon: Icons.swap_horiz_rounded,
          ),
        ],
      );
    }

    // Birden çok aday
    final shown = matches.take(_maxInline).toList();
    final cards = shown
        .map(
          (m) => ChatCard(
            type: ChatCardType.place,
            title: m.place.name,
            subtitle: m.place.category,
            imageUrl: m.place.imageUrl,
            targetRoute: '/places/${m.place.id}',
          ),
        )
        .toList();

    return ChatResponse(
      text: 'Birkaç eşleşme buldum, hangisi?',
      cards: cards,
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  List<String> _candidateTokens(String normalized, String? hint) {
    if (hint != null && hint.length >= 3) return [hint];
    return normalized
        .split(' ')
        .where((t) => t.length >= 3)
        .toList(growable: false);
  }

  List<_Match> _findMatches(List<Place> places, List<String> tokens) {
    final scored = <_Match>[];
    final query = tokens.join(' ');

    for (final p in places) {
      final nameNorm = TextNormalizer.normalize(p.name);
      double score = 0.0;

      // Klasik substring/exact eşleşmeleri (yüksek güven)
      for (final t in tokens) {
        if (nameNorm == t) {
          score += 10.0;
        } else if (nameNorm.contains(t)) {
          score += 5.0;
        } else if (_firstWordMatches(nameNorm, t)) {
          score += 3.0;
        }
      }

      // Substring/exact yetersizse, Levenshtein fuzzy ile typo'ları yakala
      // ("Atatrk" → "Atatürk", "Bandimra" → "Bandırma")
      if (score < 5.0) {
        final fuzzy = FuzzyMatch.tokenSimilarity(query, nameNorm);
        if (fuzzy >= 0.78) {
          // 0.78+ → 1-2 karakter hata aralığı; skor 2..4 arası katkı
          score += (fuzzy - 0.6) * 10.0;
        }
      }

      if (score > 0) {
        scored.add(_Match(place: p, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Skor düşükse boş döndür
    if (scored.isEmpty || scored.first.score < 2.5) return const [];
    return scored;
  }

  bool _firstWordMatches(String name, String token) {
    final first = name.split(' ').first;
    return first == token || first.startsWith(token) || token.startsWith(first);
  }

  String _summary(Place p) {
    final desc = (p.description ?? '').trim();
    // İlk cümle veya 200 karakter, hangisi önce gelirse
    final firstSentenceEnd = desc.indexOf(RegExp(r'[.!?]'));
    final cutoff = firstSentenceEnd > 0 && firstSentenceEnd < 200
        ? firstSentenceEnd + 1
        : (desc.length > 200 ? 200 : desc.length);
    var preview = desc.substring(0, cutoff).trim();
    if (cutoff < desc.length) preview += '…';
    return '${p.name}: $preview';
  }
}

class _Match {
  const _Match({required this.place, required this.score});
  final Place place;
  final double score;
}
