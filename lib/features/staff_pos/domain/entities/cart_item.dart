class CartItem {
  const CartItem({
    required this.menuItemId,
    required this.name,
    required this.emoji,
    required this.pricePoints,
    required this.quantity,
  });

  final String menuItemId;
  final String name;
  final String emoji;
  final int pricePoints;
  final int quantity;

  int get subtotal => pricePoints * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      menuItemId: menuItemId,
      name: name,
      emoji: emoji,
      pricePoints: pricePoints,
      quantity: quantity ?? this.quantity,
    );
  }
}

