import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n.dart';

import '../../../../data/models/models.dart';
import '../../../../data/repositories/repositories.dart';

/// §6.4.5 — Tarif listesi sıralama seçenekleri.
enum RecipeSortMode {
  recommended, // Önerilen (öne çıkanlar + A-Z) — varsayılan
  name, // İsme göre (A-Z)
  rating, // Puan (yüksekten)
  duration, // Süre (kısadan)
}

String recipeSortLabel(AppLocalizations l10n, RecipeSortMode m) {
  switch (m) {
    case RecipeSortMode.recommended:
      return l10n.sortRecommended;
    case RecipeSortMode.name:
      return l10n.sortByName;
    case RecipeSortMode.rating:
      return l10n.sortRating;
    case RecipeSortMode.duration:
      return l10n.sortDuration;
  }
}

/// Recipes feature state
class RecipesState {
  const RecipesState({
    this.recipes = const [],
    this.filteredRecipes = const [],
    this.selectedCategory = 'all',
    this.searchQuery = '',
    this.categories = const [],
    this.isLoading = false,
    this.error,
    this.meta,
    this.sortMode = RecipeSortMode.recommended,
  });

  final List<Recipe> recipes;
  final List<Recipe> filteredRecipes;
  final String selectedCategory;
  final String searchQuery;
  final List<RecipeCategoryItem> categories;
  final bool isLoading;
  final String? error;
  final ApiMeta? meta;
  final RecipeSortMode sortMode;

  RecipesState copyWith({
    List<Recipe>? recipes,
    List<Recipe>? filteredRecipes,
    String? selectedCategory,
    String? searchQuery,
    List<RecipeCategoryItem>? categories,
    bool? isLoading,
    String? error,
    ApiMeta? meta,
    RecipeSortMode? sortMode,
  }) {
    return RecipesState(
      recipes: recipes ?? this.recipes,
      filteredRecipes: filteredRecipes ?? this.filteredRecipes,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      meta: meta ?? this.meta,
      sortMode: sortMode ?? this.sortMode,
    );
  }
}

/// Recipe category with icon
class RecipeCategoryItem {
  const RecipeCategoryItem({
    required this.id,
    required this.label,
    this.icon,
  });

  final String id;
  final String label;
  final IconData? icon;
}

/// Recipes Notifier
class RecipesNotifier extends Notifier<RecipesState> {
  late RecipeRepository _repository;

  @override
  RecipesState build() {
    _repository = ref.watch(recipeRepositoryProvider);
    
    Future.microtask(loadRecipes);
    
    return const RecipesState(
      isLoading: true,
      categories: [],
    );
  }

  Future<void> loadRecipes({bool refresh = false}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // NOT: Kategori filtresi API'ye gönderilmiyor - tüm tarifler çekilip
      // client-side filtreleniyor. Places ve Routes ile aynı pattern.
      
      // Liste ekranı için yalnızca ihtiyaç duyulan alanları çek
      const listFields =
          'id,name,description,category,image_url,duration_minutes,'
          'difficulty,servings,rating,review_count,is_local,featured';

      final response = await _repository.getRecipes(
        // Tüm tarifleri almak için limiti yüksek tutuyoruz
        limit: 100,
        // category YOK - tüm tarifleri çek, client-side filtrele
        fields: listFields,
      );

      if (response.status && response.data != null) {
        final recipes = [...response.data!]
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        final categories = _recipeCategoriesFrom(recipes);
        state = state.copyWith(
          recipes: recipes,
          categories: categories,
          // Mevcut kategori ve arama filtresini uygula
          filteredRecipes: _filterRecipes(recipes, state.selectedCategory, state.searchQuery),
          isLoading: false,
          meta: response.meta,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setCategory(String categoryId) {
    if (state.selectedCategory == categoryId) return;

    debugPrint('🔄 [RecipesProvider] Category changed: $categoryId (client-side filter, no API call)');
    
    state = state.copyWith(
      selectedCategory: categoryId,
      // API çağrısı YOK - cache'den client-side filtreleme
      filteredRecipes: _filterRecipes(state.recipes, categoryId, state.searchQuery),
    );
  }

  void search(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredRecipes: _filterRecipes(state.recipes, state.selectedCategory, query),
    );
  }

  void clearSearch() {
    state = state.copyWith(
      searchQuery: '',
      filteredRecipes: _filterRecipes(state.recipes, state.selectedCategory, ''),
    );
  }

  /// Hem kategori hem arama filtresi uygular (client-side)
  List<Recipe> _filterRecipes(List<Recipe> recipes, String category, String query) {
    var filtered = recipes;
    
    // 1. Kategori filtresi
    if (category != 'all' && category.isNotEmpty) {
      filtered = filtered.where((recipe) {
        return recipe.category.toLowerCase() == category.toLowerCase() ||
               recipe.category.toLowerCase().replaceAll(' ', '_') == category.toLowerCase();
      }).toList();
    }
    
    // 2. Arama filtresi
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      filtered = filtered.where((recipe) {
        return recipe.title.toLowerCase().contains(lowerQuery) ||
            (recipe.description?.toLowerCase().contains(lowerQuery) ?? false) ||
            recipe.category.toLowerCase().contains(lowerQuery);
      }).toList();
    }

    return _sortRecipes(filtered);
  }

  /// §6.4.5 — Seçili [RecipeSortMode]'a göre sırala.
  List<Recipe> _sortRecipes(List<Recipe> recipes) {
    final sorted = List<Recipe>.of(recipes);
    int byName(Recipe a, Recipe b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());
    switch (state.sortMode) {
      case RecipeSortMode.name:
        sorted.sort(byName);
        return sorted;
      case RecipeSortMode.rating:
        sorted.sort((a, b) {
          final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
          if (byRating != 0) return byRating;
          final byReviews =
              (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
          if (byReviews != 0) return byReviews;
          return byName(a, b);
        });
        return sorted;
      case RecipeSortMode.duration:
        // Süre ↑ (bilinmeyen süre sona).
        sorted.sort((a, b) {
          final da = a.durationMinutes ?? 1 << 30;
          final db = b.durationMinutes ?? 1 << 30;
          if (da != db) return da.compareTo(db);
          return byName(a, b);
        });
        return sorted;
      case RecipeSortMode.recommended:
        // Gerçek öneri sıralaması (alfabetikten anlamlı şekilde FARKLI):
        //   öne çıkan (featured) + kalite (puan) + popülerlik (yorum sayısı).
        // Yorum sayısı log ile sönümlenir (1 yorumlu 5.0, 500 yorumlu 4.6'yı
        // ezmesin). Alfabetik yalnız son-çare tiebreak'tir.
        double score(Recipe r) {
          final featuredBoost = r.featured ? 1000.0 : 0.0;
          final quality = (r.rating ?? 0) * 10.0;
          final popularity = math.log(1 + (r.reviewCount ?? 0)) * 5.0;
          return featuredBoost + quality + popularity;
        }

        sorted.sort((a, b) {
          final byScore = score(b).compareTo(score(a));
          if (byScore != 0) return byScore;
          final byReviews = (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
          if (byReviews != 0) return byReviews;
          return byName(a, b);
        });
        return sorted;
    }
  }

  /// §6.4.5 — Sıralama tercihini değiştirir ve listeyi yeniden uygular.
  /// Önce mod state'e yazılır (çünkü [_filterRecipes] → [_sortRecipes]
  /// `state.sortMode`'u okur), sonra filtre yeniden hesaplanır.
  void setSortMode(RecipeSortMode mode) {
    if (state.sortMode == mode) return;
    state = state.copyWith(sortMode: mode);
    state = state.copyWith(
      filteredRecipes:
          _filterRecipes(state.recipes, state.selectedCategory, state.searchQuery),
    );
  }

  Future<void> refresh() => loadRecipes(refresh: true);

  /// Çekilen tarif listesinden sekme kategorileri (ek API çağrısı yok).
  List<RecipeCategoryItem> _recipeCategoriesFrom(List<Recipe> recipes) {
    final categoryMap = <String, String>{};
    for (final recipe in recipes) {
      if (recipe.category.isEmpty) continue;
      final id = recipe.category.toLowerCase().replaceAll(' ', '_');
      categoryMap[id] = recipe.category;
    }
    final sorted = categoryMap.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return [
      const RecipeCategoryItem(id: 'all', label: 'Tümü', icon: Icons.restaurant_menu),
      ...sorted.map(
        (e) => RecipeCategoryItem(
          id: e.key,
          label: e.value,
          icon: _getCategoryIcon(e.value),
        ),
      ),
    ];
  }

  IconData? _getCategoryIcon(String categoryLabel) {
    final lower = categoryLabel.toLowerCase();
    if (lower.contains('ana') || lower.contains('yemek')) {
      return Icons.dinner_dining;
    } else if (lower.contains('tatlı') || lower.contains('dessert')) {
      return Icons.cake;
    } else if (lower.contains('hamur') || lower.contains('bread')) {
      return Icons.bakery_dining;
    } else if (lower.contains('deniz') || lower.contains('sea')) {
      return Icons.set_meal;
    } else if (lower.contains('çorba') || lower.contains('soup')) {
      return Icons.soup_kitchen;
    } else if (lower.contains('yöresel') || lower.contains('local')) {
      return Icons.local_fire_department;
    }
    return Icons.restaurant_menu;
  }
}

/// Provider
final recipesProvider = NotifierProvider<RecipesNotifier, RecipesState>(
  RecipesNotifier.new,
);

// ============================================================================
// CLIENT-SIDE FİLTRELEME PROVIDER'LARI
// Artık ayrı API çağrısı YOK - recipesProvider.recipes'dan filtreleniyor
// ============================================================================

/// Quick recipes provider (30 dakika altı) - CLIENT-SIDE FİLTRELEME
/// API çağrısı yapmaz, recipesProvider cache'inden filtreler
final quickRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipesState = ref.watch(recipesProvider);
  
  // Loading veya hata durumunda boş liste döndür
  if (recipesState.isLoading || recipesState.recipes.isEmpty) {
    return [];
  }
  
  // 30 dakika altı tarifleri filtrele (durationMinutes null değilse)
  return recipesState.recipes
      .where((r) => r.durationMinutes != null && r.durationMinutes! <= 30)
      .take(10)
      .toList();
});

/// Popular recipes provider - CLIENT-SIDE FİLTRELEME
/// API çağrısı yapmaz, recipesProvider cache'inden filtreler
final popularRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipesState = ref.watch(recipesProvider);
  
  if (recipesState.isLoading || recipesState.recipes.isEmpty) {
    return [];
  }
  
  // İlk 10 kayıt (API sırası; değerlendirme puanı kullanılmıyor)
  return recipesState.recipes.take(10).toList();
});

/// Local recipes provider (yerel yemekler) - CLIENT-SIDE FİLTRELEME
/// API çağrısı yapmaz, recipesProvider cache'inden filtreler
final localRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipesState = ref.watch(recipesProvider);
  
  if (recipesState.isLoading || recipesState.recipes.isEmpty) {
    return [];
  }
  
  // isLocal == true olan tarifleri filtrele
  return recipesState.recipes
      .where((r) => r.isLocal)
      .take(10)
      .toList();
});

/// Single recipe detail provider - Detay için ayrı API çağrısı DOĞRU
final recipeDetailProvider = FutureProvider.family<Recipe?, String>((ref, id) async {
  final repository = ref.watch(recipeRepositoryProvider);
  return repository.getRecipe(id);
});
