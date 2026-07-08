import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının uygulamadaki aktivite sayaçlarını **sadece cihazda** tutar.
///
/// **Önemli ayrım:** Bu service [PointCollectionService]'ten tamamen
/// bağımsızdır. Hiç network çağrısı yapmaz, [FeatureFlags.pointsEnabled]
/// değerinden etkilenmez. Amacı şudur:
///
/// - Puan sistemi aktif olmadığında bile kullanıcının "şu mekanı gezdim"
///   bilgisi kaybolmasın → profil istatistikleri anlamlı kalsın.
/// - UI butonları (Place detail "Buradayım", Route detail "Tamamladım")
///   her zaman çalışsın.
/// - Puan sistemi aktif olduğunda **ek olarak** `PointCollectionService.collect()`
///   çağrılır; iki katman birbirine girmez.
///
/// **KVKK uyumu:** Sadece local. Sunucuya gönderilmez. Kullanıcı isterse
/// `clear()` ile sıfırlayabilir.
///
/// **Persistence:** SharedPreferences (`Set<String>` JSON encoded ID listesi).
class LocalActivityTracker {
  LocalActivityTracker._(this._prefs);

  final SharedPreferences _prefs;

  static const String _kVisitedKey = 'local_visited_place_ids_v1';
  static const String _kCompletedRoutesKey = 'local_completed_route_ids_v1';

  static Future<LocalActivityTracker> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalActivityTracker._(prefs);
  }

  // ─── Visited Places ───────────────────────────────────────────────────

  Set<String> getVisitedPlaceIds() {
    return _prefs.getStringList(_kVisitedKey)?.toSet() ?? <String>{};
  }

  bool isPlaceVisited(String placeId) {
    return _prefs.getStringList(_kVisitedKey)?.contains(placeId) ?? false;
  }

  int get visitedPlacesCount => getVisitedPlaceIds().length;

  /// Bir yeri ziyaret edildi olarak işaretle. Aynı ID tekrar eklenmez.
  /// `true` döner = ilk kez işaretlendi (yeni ziyaret).
  /// `false` döner = zaten ziyaret edilmişti (tekrar tıklama).
  Future<bool> markPlaceVisited(String placeId) async {
    if (placeId.trim().isEmpty) return false;
    final current = _prefs.getStringList(_kVisitedKey) ?? <String>[];
    if (current.contains(placeId)) return false;
    current.add(placeId);
    await _prefs.setStringList(_kVisitedKey, current);
    if (kDebugMode) {
      debugPrint('[LocalActivityTracker] visited place: $placeId (total: ${current.length})');
    }
    return true;
  }

  /// Ziyaret işaretini geri al (kullanıcı "yanlış işaretledim" diyebilir).
  Future<bool> unmarkPlaceVisited(String placeId) async {
    final current = _prefs.getStringList(_kVisitedKey) ?? <String>[];
    final removed = current.remove(placeId);
    if (removed) await _prefs.setStringList(_kVisitedKey, current);
    return removed;
  }

  // ─── Completed Routes ─────────────────────────────────────────────────

  Set<String> getCompletedRouteIds() {
    return _prefs.getStringList(_kCompletedRoutesKey)?.toSet() ?? <String>{};
  }

  bool isRouteCompleted(String routeId) {
    return _prefs.getStringList(_kCompletedRoutesKey)?.contains(routeId) ?? false;
  }

  int get completedRoutesCount => getCompletedRouteIds().length;

  Future<bool> markRouteCompleted(String routeId) async {
    if (routeId.trim().isEmpty) return false;
    final current = _prefs.getStringList(_kCompletedRoutesKey) ?? <String>[];
    if (current.contains(routeId)) return false;
    current.add(routeId);
    await _prefs.setStringList(_kCompletedRoutesKey, current);
    if (kDebugMode) {
      debugPrint('[LocalActivityTracker] completed route: $routeId (total: ${current.length})');
    }
    return true;
  }

  Future<bool> unmarkRouteCompleted(String routeId) async {
    final current = _prefs.getStringList(_kCompletedRoutesKey) ?? <String>[];
    final removed = current.remove(routeId);
    if (removed) await _prefs.setStringList(_kCompletedRoutesKey, current);
    return removed;
  }

  // ─── Bulk operations ──────────────────────────────────────────────────

  /// Tüm aktivite kayıtlarını siler — KVKK §14.4.2 (kullanıcı verisi sıfırlama).
  Future<void> clearAll() async {
    await _prefs.remove(_kVisitedKey);
    await _prefs.remove(_kCompletedRoutesKey);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod providers
// ─────────────────────────────────────────────────────────────────────────────

/// Singleton tracker — uygulama açılırken `create()` ile başlatılır.
/// `main.dart` startup tasks'lerinde override edilmesi beklenir.
final localActivityTrackerProvider = Provider<LocalActivityTracker>(
  (ref) => throw UnimplementedError(
    'localActivityTrackerProvider must be overridden in main.dart with '
    '`await LocalActivityTracker.create()`',
  ),
);

/// Reactive state — UI'da `ref.watch` ile sayaçları canlı izle.
/// Mark/unmark çağrılarından sonra `ref.invalidate(localActivityStateProvider)`
/// ile yenile.
class LocalActivityState {
  const LocalActivityState({
    required this.visitedPlaceIds,
    required this.completedRouteIds,
  });

  final Set<String> visitedPlaceIds;
  final Set<String> completedRouteIds;

  int get visitedCount => visitedPlaceIds.length;
  int get completedRoutesCount => completedRouteIds.length;
}

final localActivityStateProvider = Provider.autoDispose<LocalActivityState>((ref) {
  final tracker = ref.watch(localActivityTrackerProvider);
  return LocalActivityState(
    visitedPlaceIds: tracker.getVisitedPlaceIds(),
    completedRouteIds: tracker.getCompletedRouteIds(),
  );
});
