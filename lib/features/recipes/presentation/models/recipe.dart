class Recipe {
  const Recipe({
    required this.id,
    required this.image,
    required this.title,
    required this.description,
    required this.category,
    required this.prepTime,
    required this.difficulty,
    required this.servings,
    required this.rating,
    required this.reviews,
    required this.isLocal,
  });

  final String id;
  final String image;
  final String title;
  final String description;
  final String category;
  final String prepTime;
  final String difficulty;
  final int servings;
  final double rating;
  final int reviews;
  final bool isLocal;
}

class Restaurant {
  const Restaurant({
    required this.name,
    required this.rating,
    required this.specialty,
  });

  final String name;
  final double rating;
  final String specialty;
}

class RecipeCategory {
  const RecipeCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final dynamic icon;
}

