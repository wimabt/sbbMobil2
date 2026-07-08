import 'package:flutter/material.dart';


/// A circular icon button with proper centering and consistent styling
class CircularIconButton extends StatelessWidget {
  const CircularIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.showShadow = true,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBgColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.95);
    final defaultIconColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? defaultBgColor,
          shape: BoxShape.circle,
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            icon,
            color: iconColor ?? defaultIconColor,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

/// Factory methods for common button types
class CircularIconButtons {
  CircularIconButtons._();

  /// Back button for detail screens
  static Widget back(BuildContext context, {VoidCallback? onPressed}) {
    return CircularIconButton(
      icon: Icons.arrow_back,
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
    );
  }

  /// Favorite button
  static Widget favorite(
    BuildContext context, {
    required bool isFavorite,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircularIconButton(
      icon: isFavorite ? Icons.favorite : Icons.favorite_border,
      iconColor: isFavorite ? colorScheme.error : null,
      onPressed: onPressed,
    );
  }

  /// Close button
  static Widget close(BuildContext context, {VoidCallback? onPressed}) {
    return CircularIconButton(
      icon: Icons.close,
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
    );
  }
}

