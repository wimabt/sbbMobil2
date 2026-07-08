import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/discovery_feed.dart';
import '../../../../data/repositories/discovery_repository.dart';
import '../../../../core/providers/user_location_provider.dart';

/// mobile_integ.md §3.2 — Home ekranındaki 4 carousel için backend feed.
///
/// Konum sağlanırsa `nearby` dolar; aksi halde sunucu boş döner ve UI
/// "Konum erişimi açın" CTA gösterir.
///
/// Foreground'a dönüşte 5 dk'dan eskiyse otomatik refresh için
/// `ref.invalidate(discoveryFeedProvider)` çağrılır (lifecycle handler).
final discoveryFeedProvider =
    FutureProvider.autoDispose<DiscoveryFeed>((ref) async {
  final repo = ref.watch(discoveryRepositoryProvider);
  final loc = ref.watch(userLocationProvider);
  return repo.fetchFeed(
    lat: loc?.latitude,
    lng: loc?.longitude,
  );
});
