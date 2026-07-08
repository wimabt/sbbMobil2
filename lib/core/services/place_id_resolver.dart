import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bidirectional mapping between System B (Gamification/NestJS) place IDs
/// and System A (CMS/PHP) place IDs.
///
/// The gamification backend `/api/v1/mobile/places` returns each place with:
///   - `id`          → gamification internal ID (for visits, points, campaigns)
///   - `external_id` → CMS content ID (for descriptions, images, static assets)
///
/// The CMS `/places/:id` endpoint only recognises its own IDs; calling it
/// with a gamification ID returns 404. This resolver ensures the correct
/// ID is used for each backend.
class PlaceIdResolver extends Notifier<PlaceIdResolverState> {
  @override
  PlaceIdResolverState build() => const PlaceIdResolverState();

  /// Called when gamification data is loaded.
  /// [items]: raw maps from `/api/v1/mobile/places` response.
  void populate(List<Map<String, dynamic>> items) {
    final gamificationToCms = <String, String>{};
    final cmsToGamification = <String, String>{};
    int skippedNoExternal = 0;

    for (final item in items) {
      final gamificationId = item['id']?.toString();
      final cmsId = item['external_id']?.toString();
      if (gamificationId == null) continue;
      if (cmsId == null) {
        skippedNoExternal++;
        continue;
      }
      gamificationToCms[gamificationId] = cmsId;
      cmsToGamification[cmsId] = gamificationId;
    }

    state = PlaceIdResolverState(
      gamificationToCms: gamificationToCms,
      cmsToGamification: cmsToGamification,
    );

    if (kDebugMode) {
      debugPrint(
        '📍 [PlaceIdResolver] Populated ${gamificationToCms.length} mappings '
        'from ${items.length} items '
        '(skipped $skippedNoExternal without external_id) '
        '(e.g. ${gamificationToCms.entries.take(3).map((e) => '${e.key}→${e.value}').join(', ')})',
      );
    }
  }

  /// Converts a gamification ID to the CMS content ID.
  /// Returns the input unchanged if no mapping exists.
  String toCmsId(String id) {
    return state.gamificationToCms[id] ?? id;
  }

  /// Converts a CMS content ID to the gamification internal ID.
  /// Returns the input unchanged if no mapping exists.
  String toGamificationId(String id) {
    return state.cmsToGamification[id] ?? id;
  }
}

class PlaceIdResolverState {
  const PlaceIdResolverState({
    this.gamificationToCms = const {},
    this.cmsToGamification = const {},
  });

  /// gamification (System B) ID → CMS (System A) ID
  final Map<String, String> gamificationToCms;

  /// CMS (System A) ID → gamification (System B) ID
  final Map<String, String> cmsToGamification;
}

final placeIdResolverProvider =
    NotifierProvider<PlaceIdResolver, PlaceIdResolverState>(
  PlaceIdResolver.new,
);
