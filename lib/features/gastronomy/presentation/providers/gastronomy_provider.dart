import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/gastronomy.dart';
import '../../../../data/repositories/gastronomy_repository.dart';

/// Provider for fetching gastronomy detail by ID
final gastronomyDetailProvider = FutureProvider.family<Gastronomy?, String>((ref, id) async {
  final repository = ref.watch(gastronomyRepositoryProvider);
  return repository.getById(id);
});

/// Provider for fetching all gastronomy items
final gastronomyListProvider = FutureProvider<List<Gastronomy>>((ref) async {
  final repository = ref.watch(gastronomyRepositoryProvider);
  return repository.getAll();
});

/// Mock Provider for development/testing
final mockGastronomyDetailProvider = Provider.family<Gastronomy, String>((ref, id) {
  return Gastronomy(
    id: id,
    name: 'Bafra Manda Kaymaklı Lokumu',
    description:
        'Kızılırmak Deltası\'nda mandalar kimi zaman kış boyunca tamamen özgür olarak yaşamlarını sürdürürler. '
        'Diğer hayvanların yiyemeyeceği sertlikteki ot ve sazlarla da beslenen mandaların sütü son derece besleyici '
        've bu sütten elde edilen kaymak da bir o kadar özeldir. İşte Bafra lokumu bu mandaların sütünden elde edilen '
        'kaymaktan üretilir. Son derece besleyici, yumuşak ve hafiftir. Üretimi sırasında hiçbir yabancı katkı maddesi '
        'kullanılmadığı için boğazda yanma hissi oluşturmaz. Bu nedenle raf ömrü de az olan Bafra kaymaklı lokumunun '
        'kısa sürede tüketilmesi gerekir.',
    imageUrl: 'https://your-cdn.com/gastronomy/bafra-lokum-cover.jpg',
    videoUrl: 'https://www.youtube.com/watch?v=example123',
    relatedPlaces: [
      const RelatedPlace(
        id: '101',
        name: 'Tarihi Bafra Lokumcusu',
        imageUrl: 'https://your-cdn.com/places/tarihi-bafra.jpg',
        district: 'Bafra',
        rating: 4.8,
      ),
      const RelatedPlace(
        id: '102',
        name: 'Koray Çatan Restoran',
        imageUrl: 'https://your-cdn.com/places/koray-catan.jpg',
        district: 'Bafra',
        rating: 4.5,
      ),
    ],
  );
});
