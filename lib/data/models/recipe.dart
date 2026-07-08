/// Recipe model - Tarif
/// API kılavuzundaki Recipe modeline uygun
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.category,
    this.description,
    this.imageUrl,
    this.prepTime,
    this.cookTime,
    this.totalTime,
    this.durationMinutes,
    this.difficulty,
    this.servings,
    this.ingredients = const [],
    this.instructions = const [],
    this.tags = const [],
    this.rating,
    this.reviewCount,
    this.isLocal = false,
    this.featured = false,
    this.calories,
    this.author,
  });

  final String id;
  final String title;
  final String? description;
  final String category;
  final String? imageUrl;
  final String? prepTime;
  final String? cookTime;
  final String? totalTime;
  final int? durationMinutes;
  final String? difficulty;
  final int? servings;
  final List<String> ingredients;
  final List<String> instructions;
  final List<String> tags;
  final double? rating;
  final int? reviewCount;
  final bool isLocal;
  final bool featured;
  final int? calories;
  final String? author;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'].toString(),
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? json['image'] as String?,
      prepTime: json['prep_time'] as String?,
      cookTime: json['cook_time'] as String?,
      totalTime: json['total_time'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      difficulty: json['difficulty'] as String?,
      servings: json['servings'] as int?,
      ingredients: List<String>.from(json['ingredients'] ?? []),
      // Backend'den 'steps' veya 'instructions' gelebilir
      instructions: List<String>.from(
        json['steps'] ?? json['instructions'] ?? [],
      ),
      tags: List<String>.from(json['tags'] ?? []),
      rating: (json['rating'] != null)
          ? (json['rating'] as num).toDouble()
          : null,
      reviewCount: json['review_count'] as int? ?? json['reviews'] as int?,
      isLocal: json['is_local'] == true,
      featured: json['featured'] == true,
      calories: json['calories'] as int?,
      author: json['author'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'image_url': imageUrl,
      'prep_time': prepTime,
      'cook_time': cookTime,
      'total_time': totalTime,
      'duration_minutes': durationMinutes,
      'difficulty': difficulty,
      'servings': servings,
      'ingredients': ingredients,
      'instructions': instructions,
      'tags': tags,
      'rating': rating,
      'review_count': reviewCount,
      'is_local': isLocal,
      'featured': featured,
      'calories': calories,
      'author': author,
    };
  }

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    String? prepTime,
    String? cookTime,
    String? totalTime,
    int? durationMinutes,
    String? difficulty,
    int? servings,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    double? rating,
    int? reviewCount,
    bool? isLocal,
    bool? featured,
    int? calories,
    String? author,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      totalTime: totalTime ?? this.totalTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      difficulty: difficulty ?? this.difficulty,
      servings: servings ?? this.servings,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      tags: tags ?? this.tags,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isLocal: isLocal ?? this.isLocal,
      featured: featured ?? this.featured,
      calories: calories ?? this.calories,
      author: author ?? this.author,
    );
  }
}

/// Recipe Category
class RecipeCategory {
  const RecipeCategory({
    required this.id,
    required this.label,
    this.icon,
  });

  final String id;
  final String label;
  final String? icon;

  factory RecipeCategory.fromJson(Map<String, dynamic> json) {
    return RecipeCategory(
      id: json['id'].toString(),
      label: json['label'] as String? ?? json['name'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }
}
