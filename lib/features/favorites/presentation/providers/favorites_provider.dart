import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_events.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../auth/providers/auth_provider.dart';

/// Favorites feature state
class FavoritesState {
  const FavoritesState({
    this.favorites = const UserFavorites(),
    this.favoriteIds = const {},
    this.isLoading = false,
    this.error,
  });

  final UserFavorites favorites;
  final Map<FavoriteEntityType, Set<String>> favoriteIds;
  final bool isLoading;
  final String? error;

  bool isFavorite(FavoriteEntityType type, String id) {
    return favoriteIds[type]?.contains(id) ?? false;
  }

  FavoritesState copyWith({
    UserFavorites? favorites,
    Map<FavoriteEntityType, Set<String>>? favoriteIds,
    bool? isLoading,
    String? error,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Favorites Notifier
class FavoritesNotifier extends Notifier<FavoritesState> {
  late FavoriteRepository _repository;

  @override
  FavoritesState build() {
    _repository = ref.watch(favoriteRepositoryProvider);

    // Auth status'unu izle — sadece authenticated iken backend'den çek.
    // Cold start'ta auth henüz restore edilmemişken erken fetch yapılırsa
    // 401 ile boş dönüyordu; bu yüzden auth değişimini de izliyoruz.
    final authStatus = ref.watch(authProvider.select((s) => s.status));

    if (authStatus == AuthStatus.authenticated) {
      Future.microtask(() => loadFavorites(refresh: true));
      return const FavoritesState(isLoading: true);
    }

    if (authStatus == AuthStatus.unauthenticated) {
      // Anonim/misafir: favoriler cihazda (LocalFavoriteRepository). Logout
      // sonrası eski kullanıcının backend favorileri zaten gelmez; burada
      // yalnızca cihazdaki anonim favoriler yüklenir.
      Future.microtask(() => loadFavorites(refresh: true));
      return const FavoritesState(isLoading: true);
    }

    // initial / loading — auth restore tamamlanana kadar bekle.
    return const FavoritesState(isLoading: true);
  }

  Future<void> loadFavorites({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final favorites = await _repository.getAllFavorites();

      // Build favorite IDs map for quick lookup
      final favoriteIds = <FavoriteEntityType, Set<String>>{
        FavoriteEntityType.place:
            favorites.places.map((f) => f.entityId).toSet(),
        FavoriteEntityType.recipe:
            favorites.recipes.map((f) => f.entityId).toSet(),
        FavoriteEntityType.route:
            favorites.routes.map((f) => f.entityId).toSet(),
        FavoriteEntityType.menu:
            favorites.menus.map((f) => f.entityId).toSet(),
      };

      state = state.copyWith(
        favorites: favorites,
        favoriteIds: favoriteIds,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> toggleFavorite(FavoriteEntityType type, String id) async {
    try {
      final result = await _repository.toggleFavorite(
        entityType: type,
        entityId: id,
      );

      if (result.success) {
        // Update local state
        final newFavoriteIds = Map<FavoriteEntityType, Set<String>>.from(
          state.favoriteIds,
        );

        if (result.isFavorite) {
          newFavoriteIds[type] = {...(newFavoriteIds[type] ?? {}), id};
        } else {
          newFavoriteIds[type] = (newFavoriteIds[type] ?? {})..remove(id);
        }

        state = state.copyWith(favoriteIds: newFavoriteIds);
        ref.read(analyticsServiceProvider).track(
          AnalyticsEvents.favoriteToggled,
          properties: {
            'entity_type': type.value,
            'entity_id': id,
            'is_favorite': result.isFavorite,
          },
        );
        return result.isFavorite;
      }

      return state.isFavorite(type, id);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return state.isFavorite(type, id);
    }
  }

  Future<Map<String, bool>> checkFavorites(
    FavoriteEntityType type,
    List<String> ids,
  ) async {
    try {
      final result = await _repository.checkFavorites(
        entityType: type,
        entityIds: ids,
      );
      return result.favorites;
    } catch (e) {
      // Return current state as fallback
      return {
        for (final id in ids) id: state.isFavorite(type, id),
      };
    }
  }

  Future<void> refresh() => loadFavorites(refresh: true);
}

/// Provider
final favoritesProvider = NotifierProvider<FavoritesNotifier, FavoritesState>(
  FavoritesNotifier.new,
);

/// Helper provider to check if an item is favorite
final isFavoriteProvider = Provider.family<bool, (FavoriteEntityType, String)>((ref, params) {
  final (type, id) = params;
  final state = ref.watch(favoritesProvider);
  return state.isFavorite(type, id);
});
