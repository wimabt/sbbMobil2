import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/consent_repository.dart';
import '../../../data/repositories/user_activity_repository.dart';
import '../../../core/services/notification_prefs_service.dart';
import '../../../core/services/local_activity_tracker.dart';
import '../../favorites/data/favorite_migration_service.dart';
import '../../favorites/presentation/providers/favorites_provider.dart';
import '../../profile/presentation/providers/user_activity_provider.dart';
import '../../itinerary/data/itinerary_migration_service.dart';
import '../../itinerary/presentation/providers/itineraries_provider.dart';
import '../../legal/providers/consent_provider.dart';
import '../../onboarding/presentation/providers/onboarding_provider.dart';
import 'auth_provider.dart';

/// mobile_integ.md §1.2 + §4.2 + §5.3 — Login akışı tamamlandığında bir
/// kerelik çalışan senkronizasyon koordinatörü.
///
/// `AuthState` `authenticated` durumuna geçtiğinde:
///   1. **A1** — ilgi alanları reconcile (sunucu kazanır, gerekiyorsa backfill)
///   2. **A4** — bildirim tercihleri reconcile (eklendiğinde)
///   3. **A5** — local itinerary → server migration (eklendiğinde)
///
/// Provider yaşam döngüsü `keepAlive`, böylece logout/login arası tekrar
/// tetiklenir. Kullanıcı kimliği değişimini de yakalar.
final postLoginSyncProvider = Provider<void>((ref) {
  String? lastSyncedUserId;
  ref.listen<AuthState>(
    authProvider,
    (previous, next) {
      final isAuthed = next.status == AuthStatus.authenticated;
      final userId = next.user?.id;
      if (!isAuthed || userId == null) {
        // Logout → bir sonraki login'de tekrar senkron çalışsın.
        if (lastSyncedUserId != null) lastSyncedUserId = null;
        return;
      }
      if (lastSyncedUserId == userId) return;
      lastSyncedUserId = userId;

      Future.microtask(() async {
        // A2 (KVKK §10.6.3, §14.2.3) — yerelde alınmış açık rızayı sunucudaki
        // denetim iznine yaz. Kayıt ekranında rıza alınır ama JWT henüz yoktur;
        // auth tamamlanınca burada (idempotent, sürüm guard'lı) gönderilir.
        try {
          await ref
              .read(consentProvider.notifier)
              .syncToServer(ref.read(consentRepositoryProvider));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PostLoginSync] consent sync failed: $e');
          }
        }
        // A1 — interests reconcile
        try {
          await ref
              .read(onboardingProvider.notifier)
              .reconcileWithServer();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PostLoginSync] interests reconcile failed: $e');
          }
        }
        // A4 — notification prefs reconcile
        try {
          await ref
              .read(notificationPrefsProvider.notifier)
              .reconcileWithServer();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PostLoginSync] notif prefs reconcile failed: $e');
          }
        }
        // A5 — itinerary local→server migration + state refresh
        try {
          await ref
              .read(itineraryMigrationServiceProvider)
              .migrateLocalToServer();
          // Migration sonrası API listesini taze yükle (provider repo auth
          // değişimiyle zaten ApiItineraryRepository'ye geçti).
          await ref.read(itinerariesProvider.notifier).refresh();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PostLoginSync] itinerary migration failed: $e');
          }
        }
        // B15 — favorites local→server migration + state refresh
        try {
          await ref
              .read(favoriteMigrationServiceProvider)
              .migrateLocalToServer();
          await ref.read(favoritesProvider.notifier).refresh();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PostLoginSync] favorites migration failed: $e');
          }
        }
        // §6.4 — anonim ziyaret/rota (LocalActivityTracker) → backend migration.
        // Başarılıysa cihaz kayıtları temizlenir; tekrar tetiklenmez (boş kalır).
        try {
          await _migrateLocalActivity(ref);
          await ref.read(userActivityProvider.notifier).refresh();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PostLoginSync] activity migration failed: $e');
          }
        }
      });
    },
    fireImmediately: true,
  );
  return;
}, name: 'postLoginSyncProvider');

/// Anonimken cihazda biriken ziyaret/rota kayıtlarını backend'e taşır.
/// Kalıcı flag yerine "başarıda local'i temizle" yaklaşımı: bir sonraki
/// login'de local boşsa hiçbir şey yapmaz; farklı hesaplar arası doğru çalışır.
/// Kısmi hata → local korunur, sonraki login'de tekrar denenir.
Future<void> _migrateLocalActivity(Ref ref) async {
  final tracker = ref.read(localActivityTrackerProvider);
  final visited = tracker.getVisitedPlaceIds();
  final routes = tracker.getCompletedRouteIds();
  if (visited.isEmpty && routes.isEmpty) return;

  final repo = ref.read(userActivityRepositoryProvider);
  var ok = true;
  for (final id in visited) {
    try {
      await repo.markPlaceVisited(id);
    } catch (_) {
      ok = false;
    }
  }
  for (final id in routes) {
    try {
      await repo.markRouteCompleted(id);
    } catch (_) {
      ok = false;
    }
  }
  if (ok) await tracker.clearAll();
}
