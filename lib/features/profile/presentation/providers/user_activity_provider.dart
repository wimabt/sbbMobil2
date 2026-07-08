import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/local_activity_tracker.dart';
import '../../../../data/repositories/user_activity_repository.dart';
import '../../../auth/providers/auth_provider.dart';

/// Ziyaret + tamamlanan rota state'i — **backend kaynaklı, kullanıcıya bağlı**.
///
/// `FavoritesNotifier` ile aynı desende auth-aware: sadece authenticated iken
/// backend'den çeker, logout'ta sıfırlanır (eski kullanıcının verisi sızmaz).
class UserActivityState {
  const UserActivityState({
    this.activity = const UserActivity(),
    this.isLoading = false,
    this.error,
  });

  final UserActivity activity;
  final bool isLoading;
  final String? error;

  Set<String> get visitedPlaceIds => activity.visitedPlaceIds;
  Set<String> get completedRouteIds => activity.completedRouteIds;
  int get visitedCount => activity.visitedCount;
  int get completedRoutesCount => activity.completedRoutesCount;

  bool isPlaceVisited(String id) => activity.visitedPlaceIds.contains(id);
  bool isRouteCompleted(String id) => activity.completedRouteIds.contains(id);

  UserActivityState copyWith({
    UserActivity? activity,
    bool? isLoading,
    String? error,
  }) {
    return UserActivityState(
      activity: activity ?? this.activity,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UserActivityNotifier extends Notifier<UserActivityState> {
  late UserActivityRepository _repository;
  late LocalActivityTracker _localTracker;
  bool _isAuthed = false;

  @override
  UserActivityState build() {
    _repository = ref.watch(userActivityRepositoryProvider);
    _localTracker = ref.watch(localActivityTrackerProvider);

    final authStatus = ref.watch(authProvider.select((s) => s.status));
    _isAuthed = authStatus == AuthStatus.authenticated;

    if (authStatus == AuthStatus.authenticated) {
      Future.microtask(() => load(refresh: true));
      return const UserActivityState(isLoading: true);
    }

    if (authStatus == AuthStatus.unauthenticated) {
      // Anonim/misafir: ziyaret/rota cihazda (LocalActivityTracker). Login'de
      // backend'e migrate edilir (postLoginSyncProvider). Eski kullanıcının
      // backend verisi gelmez — yalnızca cihazdaki anonim kayıtlar.
      return UserActivityState(
        activity: UserActivity(
          visitedPlaceIds: _localTracker.getVisitedPlaceIds(),
          completedRouteIds: _localTracker.getCompletedRouteIds(),
        ),
      );
    }

    // initial / loading → boş state (auth restore tamamlanana kadar bekle).
    return const UserActivityState();
  }

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final activity = await _repository.fetch();
      state = state.copyWith(activity: activity, isLoading: false);
    } catch (e) {
      // Backend hazır değilse / hata → boş bırak (cihaz verisine düşme).
      if (kDebugMode) {
        debugPrint('[UserActivity] load failed: $e');
      }
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load(refresh: true);

  /// Yer ziyaret toggle — optimistic update + backend, hata olursa geri sar.
  /// Dönen değer: işlem sonrası "ziyaret edildi mi".
  Future<bool> togglePlaceVisited(String placeId) async {
    final wasVisited = state.isPlaceVisited(placeId);
    final next = Set<String>.of(state.visitedPlaceIds);
    if (wasVisited) {
      next.remove(placeId);
    } else {
      next.add(placeId);
    }
    state = state.copyWith(activity: state.activity.copyWith(visitedPlaceIds: next));

    if (!_isAuthed) {
      // Anonim → cihazda tut; kişiselleştirme davranış sinyalini de tazele.
      if (wasVisited) {
        await _localTracker.unmarkPlaceVisited(placeId);
      } else {
        await _localTracker.markPlaceVisited(placeId);
      }
      ref.invalidate(localActivityStateProvider);
      return !wasVisited;
    }

    try {
      if (wasVisited) {
        await _repository.unmarkPlaceVisited(placeId);
      } else {
        await _repository.markPlaceVisited(placeId);
      }
      return !wasVisited;
    } catch (e) {
      // Rollback
      final reverted = Set<String>.of(state.visitedPlaceIds);
      if (wasVisited) {
        reverted.add(placeId);
      } else {
        reverted.remove(placeId);
      }
      state = state.copyWith(
        activity: state.activity.copyWith(visitedPlaceIds: reverted),
        error: e.toString(),
      );
      return wasVisited;
    }
  }

  /// Rota tamamlandı toggle — optimistic update + backend, hata olursa geri sar.
  Future<bool> toggleRouteCompleted(String routeId) async {
    final wasDone = state.isRouteCompleted(routeId);
    final next = Set<String>.of(state.completedRouteIds);
    if (wasDone) {
      next.remove(routeId);
    } else {
      next.add(routeId);
    }
    state =
        state.copyWith(activity: state.activity.copyWith(completedRouteIds: next));

    if (!_isAuthed) {
      // Anonim → cihazda tut; kişiselleştirme davranış sinyalini de tazele.
      if (wasDone) {
        await _localTracker.unmarkRouteCompleted(routeId);
      } else {
        await _localTracker.markRouteCompleted(routeId);
      }
      ref.invalidate(localActivityStateProvider);
      return !wasDone;
    }

    try {
      if (wasDone) {
        await _repository.unmarkRouteCompleted(routeId);
      } else {
        await _repository.markRouteCompleted(routeId);
      }
      return !wasDone;
    } catch (e) {
      final reverted = Set<String>.of(state.completedRouteIds);
      if (wasDone) {
        reverted.add(routeId);
      } else {
        reverted.remove(routeId);
      }
      state = state.copyWith(
        activity: state.activity.copyWith(completedRouteIds: reverted),
        error: e.toString(),
      );
      return wasDone;
    }
  }
}

final userActivityProvider =
    NotifierProvider<UserActivityNotifier, UserActivityState>(
  UserActivityNotifier.new,
);
