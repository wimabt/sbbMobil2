import 'package:flutter/material.dart';
import '../design/design_tokens.dart';

/// Base card component with consistent styling
/// Light Theme: Clean white cards with soft shadows
/// Dark Theme: Glassmorphism effect with subtle borders and glow
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevation,
    this.borderRadius,
    this.color,
    this.accentColor, // For dark theme glow effect
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final List<BoxShadow>? elevation;
  final double? borderRadius;
  final Color? color;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? AppRadius.lg;
    
    final card = Container(
      padding: padding ?? EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppColors.darkSurface : Colors.white),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: isDark
            ? (accentColor != null
                ? AppDarkEffects.neonGlow(accentColor!)
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ])
            : (elevation ?? AppElevation.level2),
        border: isDark
            ? Border.all(
                color: Colors.white.withAlpha(15),
                width: 1,
              )
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: isDark
              ? (accentColor ?? AppColors.neonBlue).withAlpha(30)
              : Theme.of(context).colorScheme.primary.withAlpha(30),
          highlightColor: isDark
              ? Colors.white.withAlpha(10)
              : Colors.black.withAlpha(5),
          child: card,
        ),
      );
    }

    return card;
  }
}

