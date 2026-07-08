import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_service.dart';
import '../../../core/services/log_service.dart';
import '../../../data/repositories/api_itinerary_repository.dart';
import '../../../data/repositories/itinerary_repository.dart';

/// mobile_integ.md §5.3 — Login akışında bir kerelik:
/// Lokal plan ve durakları sunucuya taşır, başarılı olanları lokalden siler.
class ItineraryMigrationService {
  ItineraryMigrationService(this._ref);

  final Ref _ref;

  /// `keyVersion` v1 — gelecekte migrasyon kuralı değişirse ileri sürüm
  /// kullanılarak yeniden tetiklenebilir.
  Future<void> migrateLocalToServer() async {
    final local = _ref.read(localItineraryRepositoryProvider);
    final api = ApiItineraryRepository(_ref.read(apiServiceProvider).dio);

    final localPlans = await local.list();
    if (localPlans.isEmpty) return;

    if (kDebugMode) {
      debugPrint(
        '[Itinerary] migrating ${localPlans.length} local plan(s) to server...',
      );
    }

    for (final plan in localPlans) {
      try {
        final created = await api.create(
          title: plan.title,
          startsAt: plan.startsAt,
          endsAt: plan.endsAt,
          notes: plan.notes,
        );

        var current = created;
        // Lokal item sırasını koruyarak ekle. Sunucu yeni id atadığı için
        // dönen plan'ın son listesini güncel sayar.
        for (final item in plan.items) {
          current = await api.addItem(current.id, item);
        }

        // İsteğe bağlı reorder — addItem zaten sırayı ekleme sırasına göre
        // tutuyor; gönderilen liste boşsa atla.
        if (current.items.length > 1) {
          final orderedIds = current.items.map((e) => e.id).toList();
          current = await api.reorderItems(current.id, orderedIds);
        }

        await local.delete(plan.id);
      } catch (e, stack) {
        LogService.w(
          'Itinerary migration failed for plan ${plan.id}: $e',
          tag: 'ItineraryMigration',
        );
        if (kDebugMode) debugPrint('$stack');
        // Bu plan local'de kalsın; sonraki login'de tekrar denenecek.
      }
    }
  }
}

final itineraryMigrationServiceProvider =
    Provider<ItineraryMigrationService>((ref) {
  return ItineraryMigrationService(ref);
});
