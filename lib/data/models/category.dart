/// Category model - Genel kategori yapısı
/// API kılavuzundaki kategori yapısına uygun
class Category {
  const Category({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.imageUrl,
    this.parentId,
    this.subcategories = const [],
    this.itemCount,
    this.order,
  });

  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? imageUrl;
  final String? parentId;
  final List<Category> subcategories;
  final int? itemCount;
  final int? order;

  bool get hasSubcategories => subcategories.isNotEmpty;
  bool get isRoot => parentId == null;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'].toString(),
      name: json['name'] as String? ?? json['label'] as String? ?? '',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      imageUrl: json['image_url'] as String?,
      parentId: json['parent_id']?.toString(),
      subcategories: (json['subcategories'] as List?)
              ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      itemCount: json['item_count'] as int?,
      order: json['order'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'image_url': imageUrl,
      'parent_id': parentId,
      'subcategories': subcategories.map((e) => e.toJson()).toList(),
      'item_count': itemCount,
      'order': order,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? imageUrl,
    String? parentId,
    List<Category>? subcategories,
    int? itemCount,
    int? order,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      imageUrl: imageUrl ?? this.imageUrl,
      parentId: parentId ?? this.parentId,
      subcategories: subcategories ?? this.subcategories,
      itemCount: itemCount ?? this.itemCount,
      order: order ?? this.order,
    );
  }
}

/// Flat category item for lists/filters
class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.label,
    this.icon,
  });

  final String id;
  final String label;
  final dynamic icon;

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'].toString(),
      label: json['label'] as String? ?? json['name'] as String? ?? '',
      icon: json['icon'],
    );
  }

  factory CategoryItem.fromCategory(Category category) {
    return CategoryItem(
      id: category.id,
      label: category.name,
      icon: category.icon,
    );
  }
}
