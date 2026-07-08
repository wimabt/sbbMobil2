import 'package:flutter/material.dart';
import '../../../../core/design/design_tokens.dart';

/// Stat card widget for profile screen — premium FinTech feel.
///
/// [isPrimary] makes the card slightly more prominent (for the Points card).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.isPrimary = false,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  /// When true, the card gets a subtle accent border + enhanced shadow
  /// to draw attention (used for the "Puan" / Points card).
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: iconColor.withAlpha(isPrimary ? 30 : 15),
                  blurRadius: isPrimary ? 14 : 8,
                  spreadRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(isPrimary ? 14 : 8),
                  blurRadius: isPrimary ? 18 : 12,
                  offset: const Offset(0, 4),
                ),
                if (isPrimary)
                  BoxShadow(
                    color: iconColor.withAlpha(12),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
              ],
        border: isDark
            ? Border.all(
                color: isPrimary
                    ? iconColor.withAlpha(40)
                    : Colors.white.withAlpha(15),
                width: isPrimary ? 1.2 : 1,
              )
            : isPrimary
                ? Border.all(
                    color: iconColor.withAlpha(30),
                    width: 1,
                  )
                : null,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(isDark ? 40 : 26),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: iconColor.withAlpha(isPrimary ? 50 : 30),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ]
                  : isPrimary
                      ? [
                          BoxShadow(
                            color: iconColor.withAlpha(20),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : null,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? Colors.white.withAlpha(150)
                      : Theme.of(context).hintColor,
                ),
          ),
        ],
      ),
    );
  }
}
