import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/log_service.dart';
import '../../../data/models/favorite.dart';
import '../../../data/repositories/favorite_repository.dart';

/// `mobile_pending_changes.md` B15 — Login akışında bir kerelik:
/// SharedPreferences'taki yerel favorileri (`place / recipe / route`) backend
/// `/api/v1/mobile/favorites/toggle` endpoint'ine taşır ve local kopyaları
/// temizler. `menu` whitelist dışı olduğu için aynen cihazda kalır
/// (LocalFavoriteRepository yönetir).
///
/// Migrasyon bir kez tamamlandığında [_kMigratedFlag] anahtarı set edilir ve
/// sonraki login'lerde tekrar tetiklenmez. Kısmi başarı durumunda (örn. ağ
/// hatası) bayrak konmaz; bir sonraki açılışta kaldığı yerden devam etmesi
/// için kalan ID'ler local'de durmaya devam eder.
class FavoriteMigrationService {
  FavoriteMigrationService(this._ref);

  final Ref _ref;

  /// v1 — gelecekte kural değişirse v2 anahtarı ile yeniden çalıştırılabilir.
  static const String _kMigratedFlag = 'favorites_migrated_v1';

  static const String _kPlacesKey = 'favorites_places';
  static const String _kRecipesKey = 'favorites_recipes';
  static const String _kRoutesKey = 'favorites_routes';

  Future<void> migrateLocalToServer() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kMigratedFlag) ?? false) return;

    final repo = _ref.read(favoriteRepositoryProvider);

    final batches = <(FavoriteEntityType, String, List<String>)>[
      (FavoriteEntityType.place, _kPlacesKey, prefs.getStringList(_kPlacesKey) ?? const []),
      (FavoriteEntityType.recipe, _kRecipesKey, prefs.getStringList(_kRecipesKey) ?? const []),
      (FavoriteEntityType.route, _kRoutesKey, prefs.getStringList(_kRoutesKey) ?? const []),
    ];

    final hasAny = batches.any((b) => b.$3.isNotEmpty);
    if (!hasAny) {
      // Hiç yerel favori yoksa flag'i hemen at — gereksiz tekrar denemesin.
      await prefs.setBool(_kMigratedFlag, true);
      return;
    }

    if (kDebugMode) {
      final total = batches.fold<int>(0, (acc, b) => acc + b.$3.length);
      debugPrint('[FavoriteMigration] migrating $total local favorite(s) to server...');
    }

    var anyFailure = false;

    for (final (entityType, prefsKey, ids) in batches) {
      if (ids.isEmpty) continue;
      final remaining = List<String>.from(ids);

      for (final id in ids) {
        try {
          final result = await repo.toggleFavorite(
            entityType: entityType,
            entityId: id,
          );
          // Idempotent toggle: backend zaten favoride ise tekrar toggle
          // edebilir (off yapar). Bunu engellemek için check + toggle
          // kombinasyonu kullanılabilir, ama:
          //   - Local'deki favorilerin sunucuda olmadığını biliyoruz (yeni feature).
          //   - 23505 UNIQUE constraint backend tarafında zaten yutuluyor.
          // Bu yüzden tek POST yeterli; result.success kontrolü ile devam.
          if (result.success) {
            remaining.remove(id);
          } else {
            anyFailure = true;
          }
        } catch (e) {
          anyFailure = true;
          LogService.w(
            'Favorite migration failed for ${entityType.value}/$id: $e',
            tag: 'FavoriteMigration',
          );
        }
      }

      // Bu tip için kalan ID'leri güncelle (bir kısmı taşınmış olabilir).
      if (remaining.isEmpty) {
        await prefs.remove(prefsKey);
      } else {
        await prefs.setStringList(prefsKey, remaining);
      }
    }

    if (!anyFailure) {
      await prefs.setBool(_kMigratedFlag, true);
      if (kDebugMode) {
        debugPrint('[FavoriteMigration] completed successfully');
      }
    } else if (kDebugMode) {
      debugPrint('[FavoriteMigration] partial — will retry on next login');
    }
  }
}

final favoriteMigrationServiceProvider =
    Provider<FavoriteMigrationService>((ref) {
  return FavoriteMigrationService(ref);
});
