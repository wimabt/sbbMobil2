class PosMenuItem {
  const PosMenuItem({
    required this.id,
    required this.itemName,
    required this.pricePoints,
    required this.category,
    required this.emoji,
    required this.sortOrder,
    required this.isActive,
    this.description,
  });

  final String id;
  final String itemName;
  final String? description;
  final int pricePoints;
  final String category;
  final String emoji;
  final int sortOrder;
  final bool isActive;

  factory PosMenuItem.fromJson(Map<String, dynamic> json) {
    return PosMenuItem(
      id: json['id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      description: json['description']?.toString(),
      pricePoints: (json['price_points'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? 'Genel',
      emoji: json['emoji']?.toString() ?? '🛒',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}

