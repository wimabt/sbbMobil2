import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../models/models.dart';

/// Recipe Repository - Tarif verileri için data layer
abstract class RecipeRepository {
  /// Tarif listesi al
  Future<ApiResponse<List<Recipe>>> getRecipes({
    int page = 1,
    int limit = 20,
    String? category,
    String lang = 'tr',
    /// Place'lerde olduğu gibi, sadece belirli alanları çekmek için optional fields parametresi
    String? fields,
  });

  /// Tek tarif detayı
  Future<Recipe?> getRecipe(String id, {String lang = 'tr'});

  /// Tarif ara
  Future<ApiResponse<List<Recipe>>> searchRecipes({
    required String query,
    String? category,
    int page = 1,
    int limit = 20,
  });

  // getQuickRecipes, getPopularRecipes, getLocalRecipes KALDIRILDI
  // Bunlar artık provider'da client-side filtreleme ile yapılıyor
  // API çağrısı yerine recipesProvider.recipes'dan filtrele

  /// Tarif kategorileri al
  Future<ApiResponse<List<RecipeCategory>>> getCategories({String lang = 'tr'});
}

/// Mock implementation
class MockRecipeRepository implements RecipeRepository {
  final List<Recipe> _mockRecipes = [
    const Recipe(
      id: '1',
      title: 'Samsun Simidi',
      description: 'Geleneksel Samsun simidi tarifi',
      category: 'Hamur İşleri',
      imageUrl: 'assets/images/food-kebab.jpg',
      prepTime: '20 dk',
      cookTime: '25 dk',
      totalTime: '45 dk',
      difficulty: 'Orta',
      servings: 4,
      rating: 4.8,
      reviewCount: 124,
      isLocal: true,
      featured: true,
    ),
    const Recipe(
      id: '2',
      title: 'Karadeniz Pide',
      description: 'Kuşbaşılı Karadeniz pidesi',
      category: 'Ana Yemek',
      imageUrl: 'assets/images/food-baklava.jpg',
      prepTime: '30 dk',
      cookTime: '20 dk',
      totalTime: '50 dk',
      difficulty: 'Kolay',
      servings: 2,
      rating: 4.5,
      reviewCount: 89,
      isLocal: true,
      featured: true,
    ),
    const Recipe(
      id: '3',
      title: 'Hamsi Tava',
      description: 'Taze hamsi ile yapılan klasik tava',
      category: 'Deniz Ürünleri',
      imageUrl: 'assets/images/food-kebab.jpg',
      prepTime: '15 dk',
      cookTime: '15 dk',
      totalTime: '30 dk',
      difficulty: 'Kolay',
      servings: 4,
      rating: 4.7,
      reviewCount: 156,
      isLocal: true,
      featured: false,
    ),
    const Recipe(
      id: '4',
      title: 'Mantı',
      description: 'El açması geleneksel mantı tarifi',
      category: 'Ana Yemek',
      imageUrl: 'assets/images/food-baklava.jpg',
      prepTime: '60 dk',
      cookTime: '30 dk',
      totalTime: '90 dk',
      difficulty: 'Zor',
      servings: 6,
      rating: 4.9,
      reviewCount: 201,
      isLocal: false,
      featured: false,
    ),
  ];

  @override
  Future<ApiResponse<List<Recipe>>> getRecipes({
    int page = 1,
    int limit = 20,
    String? category,
    String lang = 'tr',
    String? fields,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    var filtered = _mockRecipes;
    if (category != null && category.isNotEmpty && category != 'all') {
      filtered = _mockRecipes
          .where((r) => r.category.toLowerCase() == category.toLowerCase())
          .toList();
    }

    return ApiResponse(
      status: true,
      message: 'Success',
      data: filtered,
      meta: ApiMeta(
        page: page,
        limit: limit,
        total: filtered.length,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      ),
    );
  }

  @override
  Future<Recipe?> getRecipe(String id, {String lang = 'tr'}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    try {
      return _mockRecipes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ApiResponse<List<Recipe>>> searchRecipes({
    required String query,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final filtered = _mockRecipes.where((r) {
      final matchesQuery = r.title.toLowerCase().contains(query.toLowerCase()) ||
          (r.description?.toLowerCase().contains(query.toLowerCase()) ?? false);
      final matchesCategory = category == null ||
          category.isEmpty ||
          r.category.toLowerCase() == category.toLowerCase();
      return matchesQuery && matchesCategory;
    }).toList();

    return ApiResponse(
      status: true,
      message: 'Success',
      data: filtered,
      meta: ApiMeta(
        page: page,
        limit: limit,
        total: filtered.length,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      ),
    );
  }

  @override
  Future<ApiResponse<List<RecipeCategory>>> getCategories({String lang = 'tr'}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Mock: Recipes'ten unique kategorileri çıkar
    final categories = _mockRecipes
        .map((r) => r.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .map((c) => RecipeCategory(id: c.toLowerCase().replaceAll(' ', '_'), label: c))
        .toList();
    
    return ApiResponse(
      status: true,
      message: 'Success',
      data: categories,
    );
  }
}

/// API implementation
class ApiRecipeRepository implements RecipeRepository {
  ApiRecipeRepository(this._client);
  final ApiClient _client;

  @override
  Future<ApiResponse<List<Recipe>>> getRecipes({
    int page = 1,
    int limit = 20,
    String? category,
    String lang = 'tr',
    String? fields,
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.recipes,
        queryParameters: {
          'page': page,
          'limit': limit,
          'lang': lang,
          'fields': ?fields,
          'category': ?category,
        },
      );

      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (obj) => (obj as List)
            .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<Recipe?> getRecipe(String id, {String lang = 'tr'}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.recipe(id),
        queryParameters: {'lang': lang},
      );

      final api = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (obj) => Recipe.fromJson(obj as Map<String, dynamic>),
      );

      return api.data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<ApiResponse<List<Recipe>>> searchRecipes({
    required String query,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.recipesSearch,
        queryParameters: {
          'q': query,
          'page': page,
          'limit': limit,
          'category': ?category,
        },
      );

      return ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (obj) => (obj as List)
            .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<ApiResponse<List<RecipeCategory>>> getCategories({String lang = 'tr'}) async {
    try {
      // Önce recipes listesini çek ve unique kategorileri çıkar
      final recipesResponse = await getRecipes(limit: 1000, lang: lang);
      
      if (recipesResponse.status && recipesResponse.data != null) {
        final recipes = recipesResponse.data!;
        // Unique kategorileri çıkar
        final categoryMap = <String, String>{};
        for (final recipe in recipes) {
          if (recipe.category.isNotEmpty) {
            final categoryId = recipe.category.toLowerCase().replaceAll(' ', '_');
            categoryMap[categoryId] = recipe.category;
          }
        }
        
        final categories = categoryMap.entries
            .map((e) => RecipeCategory(id: e.key, label: e.value))
            .toList();
        
        return ApiResponse(
          status: true,
          message: 'Success',
          data: categories,
        );
      }
      
      return ApiResponse(
        status: false,
        message: 'No categories found',
        data: [],
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

/// Provider
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  // Place'lerde olduğu gibi gerçek backend API'sini kullan
  final client = ref.watch(apiClientProvider);
  return ApiRecipeRepository(client);
});
