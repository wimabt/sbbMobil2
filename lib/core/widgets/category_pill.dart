import 'package:flutter/material.dart';
import '../design/design_tokens.dart';
import '../utils/icon_resolver.dart';

/// Reusable category pill/chip component with active/inactive states
/// Light Theme: Gradient primary colors when active, soft grey when inactive
/// Dark Theme: Neon border glow when active, glassmorphism when inactive
/// 
/// Supports both Material Icons (IconData) and SVG icons from database (iconString).
/// iconString format: "maki:museum", "fa:map-marker", "material:place"
class CategoryPill extends StatelessWidget {
  const CategoryPill({
    super.key,
    required this.label,
    this.icon,
    this.iconString,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData? icon; // Material IconData (opsiyonel)
  final String? iconString; // Veritabanından gelen icon string (maki:xxx, fa:xxx)
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Icon rengini hesapla
    final iconColor = isActive
        ? (isDark ? AppColors.neonCyan : Colors.white)
        : (isDark ? Colors.white.withAlpha(180) : Theme.of(context).hintColor);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        splashColor: isDark
            ? AppColors.neonCyan.withAlpha(30)
            : Theme.of(context).colorScheme.primary.withAlpha(30),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            gradient: isActive
                ? (isDark
                    ? LinearGradient(
                        colors: [
                          AppColors.neonCyan.withAlpha(40),
                          AppColors.neonBlue.withAlpha(30),
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withAlpha(200),
                        ],
                      ))
                : null,
            color: isActive
                ? null
                : (isDark
                    ? Colors.white.withAlpha(10)
                    : Theme.of(context).colorScheme.surfaceContainerHighest),
            border: isDark
                ? Border.all(
                    color: isActive
                        ? AppColors.neonCyan.withAlpha(100)
                        : Colors.white.withAlpha(20),
                    width: 1,
                  )
                : null,
            boxShadow: isActive && isDark
                ? [
                    BoxShadow(
                      color: AppColors.neonCyan.withAlpha(30),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon widget (öncelik: iconString > icon)
              if (iconString != null && iconString!.isNotEmpty) ...[
                IconResolver.buildIcon(
                  iconString: iconString,
                  size: 16,
                  color: iconColor,
                  fallbackColor: iconColor,
                ),
                SizedBox(width: AppSpacing.xs),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: iconColor,
                ),
                SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? (isDark ? AppColors.neonCyan : Colors.white)
                      : (isDark ? Colors.white.withAlpha(180) : null),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

