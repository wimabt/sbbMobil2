import 'package:flutter/material.dart';
import '../design/design_tokens.dart';

/// Reusable search bar component used across multiple screens
/// Light Theme: Pure white background with stadium border and subtle shadow
/// Dark Theme: Glassmorphism with subtle border
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.showFilterButton = false,
    this.onFilterTap,
    this.controller,
    this.isFilterActive = false,
    this.filterButtonColor,
    this.filterButtonActiveColor,
    this.filterButtonKey,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool showFilterButton;
  final VoidCallback? onFilterTap;
  final TextEditingController? controller;
  /// Filtre butonu için aktif/pasif durumu (badge ve renk için)
  final bool isFilterActive;
  /// Filtre butonunun temel rengi (opsiyonel, sayfa bazlı override)
  final Color? filterButtonColor;
  /// Filtre butonunun aktif rengi (opsiyonel, sayfa bazlı override)
  final Color? filterButtonActiveColor;
  /// Filtre butonuna ankrajlı menü açmak için (bkz. showAppSortMenu).
  final GlobalKey? filterButtonKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Background color - uses theme surface color
    final backgroundColor = isDark
        ? AppColors.darkSurface
        : colorScheme.surface;

    // Border color for dark mode
    final borderColor = isDark
        ? colorScheme.outline.withValues(alpha: 0.2)
        : null;

    // Icon color - uses theme onSurface with appropriate opacity
    final iconColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.6)
        : colorScheme.onSurface.withValues(alpha: 0.5);

    // Hint text color
    final hintColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.5)
        : colorScheme.onSurface.withValues(alpha: 0.5);

    // Text color
    final textColor = colorScheme.onSurface;

    // Filtre butonu renkleri (opsiyonel override + tema fallback)
    final defaultFilterBaseColor =
        isDark ? AppColors.neonBlue : colorScheme.primary;
    final defaultFilterActiveColor =
        isDark ? AppColors.neonCyan : colorScheme.primary;

    final effectiveFilterBaseColor =
        filterButtonColor ?? defaultFilterBaseColor;
    final effectiveFilterActiveColor =
        filterButtonActiveColor ?? defaultFilterActiveColor;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: backgroundColor,
        // Stadium/pill border - fully rounded
        borderRadius: BorderRadius.circular(30),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1)
            : null,
        // Subtle shadow for light mode to make it pop from background
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          Icon(
            Icons.search_rounded,
            size: 22,
            color: iconColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: true,
                // Same background color as container - uses theme
                fillColor: backgroundColor,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: hintColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              cursorColor: colorScheme.primary,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          if (showFilterButton) ...[
            Container(
              key: filterButtonKey,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                // Tema, aktif durum ve opsiyonel override'a göre buton rengi
                color: isFilterActive
                    ? effectiveFilterActiveColor
                    : effectiveFilterBaseColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: (isFilterActive
                                  ? effectiveFilterActiveColor
                                  : effectiveFilterBaseColor)
                              .withValues(alpha: 0.3),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onFilterTap,
                  borderRadius: BorderRadius.circular(20),
                  splashColor: colorScheme.onPrimary.withValues(alpha: 0.2),
                  highlightColor: colorScheme.onPrimary.withValues(alpha: 0.1),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      if (isFilterActive)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : colorScheme.primary,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

