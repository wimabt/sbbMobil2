/// Favorite model - Kullanıcı favorileri
/// API kılavuzundaki favorite yapısına uygun
class Favorite {
  const Favorite({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.addedAt,
  });

  final String id;
  final FavoriteEntityType entityType;
  final String entityId;
  final DateTime? addedAt;

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id']?.toString() ?? json['entity_id'].toString(),
      entityType: FavoriteEntityType.fromString(
        json['entity_type'] as String? ?? 'place',
      ),
      entityId: json['entity_id'].toString(),
      addedAt: json['added_at'] != null
          ? DateTime.tryParse(json['added_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType.value,
      'entity_id': entityId,
      'added_at': addedAt?.toIso8601String(),
    };
  }
}

/// Favori entity tipleri.
///
/// Backend whitelist'i (`mobile_pending_changes.md` B15):
///   `place | route | event | recipe | ar_point`
///
/// `menu` whitelist dışındadır — Gastronomi/Lezzetler favorileri cihazda
/// (LocalFavoriteRepository) tutulmaya devam eder. Backend bu tipi destekler
/// hale gelirse [isApiSynced] flag'i true yapılarak otomatik API'ye akar.
enum FavoriteEntityType {
  place('place', isApiSynced: true),
  recipe('recipe', isApiSynced: true),
  route('route', isApiSynced: true),
  event('event', isApiSynced: true),
  arPoint('ar_point', isApiSynced: true),
  menu('menu', isApiSynced: false);

  const FavoriteEntityType(this.value, {required this.isApiSynced});
  final String value;

  /// `true` ise toggle/check çağrıları backend'e gider; aksi halde cihazda kalır.
  final bool isApiSynced;

  static FavoriteEntityType fromString(String value) {
    return FavoriteEntityType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FavoriteEntityType.place,
    );
  }
}

/// Favori toggle response
class FavoriteToggleResult {
  const FavoriteToggleResult({
    required this.success,
    required this.isFavorite,
    required this.entityType,
    required this.entityId,
  });

  final bool success;
  final bool isFavorite;
  final FavoriteEntityType entityType;
  final String entityId;

  factory FavoriteToggleResult.fromJson(Map<String, dynamic> json) {
    return FavoriteToggleResult(
      success: json['success'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
      entityType: FavoriteEntityType.fromString(
        json['entity_type'] as String? ?? 'place',
      ),
      entityId: json['entity_id'].toString(),
    );
  }
}

/// Toplu favori kontrol response
class FavoriteCheckResult {
  const FavoriteCheckResult({
    required this.entityType,
    required this.favorites,
  });

  final FavoriteEntityType entityType;
  final Map<String, bool> favorites;

  factory FavoriteCheckResult.fromJson(Map<String, dynamic> json) {
    return FavoriteCheckResult(
      entityType: FavoriteEntityType.fromString(
        json['entity_type'] as String? ?? 'place',
      ),
      favorites: (json['favorites'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as bool),
          ) ??
          {},
    );
  }

  bool isFavorite(String entityId) => favorites[entityId] ?? false;
}

/// Kullanıcının tüm favorileri
class UserFavorites {
  const UserFavorites({
    this.places = const [],
    this.recipes = const [],
    this.routes = const [],
    this.events = const [],
    this.arPoints = const [],
    this.menus = const [],
  });

  final List<Favorite> places;
  final List<Favorite> recipes;
  final List<Favorite> routes;
  final List<Favorite> events;
  final List<Favorite> arPoints;
  final List<Favorite> menus;

  /// Backend iki farklı format dönebiliyor; her ikisini de destekle:
  ///
  /// **Format A (current backend) — flat array:**
  /// ```json
  /// [
  ///   {"entity_type": "place", "entity_id": "p1", "created_at": "..."},
  ///   {"entity_type": "route", "entity_id": "18", ...},
  /// ]
  /// ```
  ///
  /// **Format B (legacy) — kategorize map:**
  /// ```json
  /// {"place": [...], "recipe": [...], "route": [...]}
  /// ```
  factory UserFavorites.fromJson(dynamic raw) {
    final places = <Favorite>[];
    final recipes = <Favorite>[];
    final routes = <Favorite>[];
    final events = <Favorite>[];
    final arPoints = <Favorite>[];
    final menus = <Favorite>[];

    void addByType(Favorite fav) {
      switch (fav.entityType) {
        case FavoriteEntityType.place:
          places.add(fav);
        case FavoriteEntityType.recipe:
          recipes.add(fav);
        case FavoriteEntityType.route:
          routes.add(fav);
        case FavoriteEntityType.event:
          events.add(fav);
        case FavoriteEntityType.arPoint:
          arPoints.add(fav);
        case FavoriteEntityType.menu:
          menus.add(fav);
      }
    }

    // Format A: list
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          addByType(Favorite.fromJson(item));
        }
      }
    }
    // Format B: kategorize map
    else if (raw is Map<String, dynamic>) {
      void parseKey(String key, String entityType) {
        final list = raw[key];
        if (list is! List) return;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            addByType(Favorite.fromJson({...item, 'entity_type': entityType}));
          }
        }
      }

      parseKey('place', 'place');
      parseKey('recipe', 'recipe');
      parseKey('route', 'route');
      parseKey('event', 'event');
      parseKey('ar_point', 'ar_point');
      parseKey('menu', 'menu');
    }

    return UserFavorites(
      places: places,
      recipes: recipes,
      routes: routes,
      events: events,
      arPoints: arPoints,
      menus: menus,
    );
  }

  UserFavorites copyWith({
    List<Favorite>? places,
    List<Favorite>? recipes,
    List<Favorite>? routes,
    List<Favorite>? events,
    List<Favorite>? arPoints,
    List<Favorite>? menus,
  }) {
    return UserFavorites(
      places: places ?? this.places,
      recipes: recipes ?? this.recipes,
      routes: routes ?? this.routes,
      events: events ?? this.events,
      arPoints: arPoints ?? this.arPoints,
      menus: menus ?? this.menus,
    );
  }

  int get totalCount =>
      places.length +
      recipes.length +
      routes.length +
      events.length +
      arPoints.length +
      menus.length;

  bool containsPlace(String placeId) =>
      places.any((f) => f.entityId == placeId);

  bool containsRecipe(String recipeId) =>
      recipes.any((f) => f.entityId == recipeId);

  bool containsRoute(String routeId) =>
      routes.any((f) => f.entityId == routeId);
}
