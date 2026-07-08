import 'package:flutter/material.dart';
import '../design/design_tokens.dart';

/// Arama çubuğundaki filtre/sırala butonuna **ankrajlı** sıralama menüsü.
///
/// Bare `PopupMenuButton` yerine uygulama tasarım token'larıyla (dark/light,
/// AppColors, yuvarlatılmış köşe) tutarlı bir görünüm sağlar. Menü, verilen
/// [anchorKey]'in (genelde [AppSearchBar.filterButtonKey]) konumuna göre
/// butonun hemen altına, sağ kenarına hizalı açılır.
///
/// Kullanım:
/// ```dart
/// final sortKey = GlobalKey();
/// AppSearchBar(
///   showFilterButton: true,
///   filterButtonKey: sortKey,
///   isFilterActive: state.sortMode != DefaultSort.first,
///   onFilterTap: () => showAppSortMenu<MySort>(
///     context: context,
///     anchorKey: sortKey,
///     current: state.sortMode,
///     values: MySort.values,
///     labelOf: sortLabel,
///     onSelected: notifier.setSortMode,
///   ),
/// );
/// ```
Future<void> showAppSortMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required T current,
  required List<T> values,
  required String Function(T) labelOf,
  required ValueChanged<T> onSelected,
  Map<T, IconData>? icons,
}) async {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  final anchor = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (anchor == null || overlay == null) return;

  // Butonun overlay'e göre konumu — menü altına, sağ kenarına hizalı.
  const menuWidth = 240.0;
  final btnBottomRight = anchor.localToGlobal(
    anchor.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );
  final position = RelativeRect.fromLTRB(
    (btnBottomRight.dx - menuWidth).clamp(8.0, overlay.size.width - menuWidth),
    btnBottomRight.dy + 6,
    overlay.size.width - btnBottomRight.dx,
    0,
  );

  final surface = isDark ? AppColors.darkSurface : theme.colorScheme.surface;
  final primary = isDark ? AppColors.neonCyan : theme.colorScheme.primary;
  final textColor = theme.colorScheme.onSurface;

  final selected = await showMenu<T>(
    context: context,
    position: position,
    color: surface,
    elevation: 8,
    constraints: const BoxConstraints(minWidth: menuWidth, maxWidth: 300),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: isDark
          ? BorderSide(color: Colors.white.withValues(alpha: 0.12))
          : BorderSide(color: Colors.black.withValues(alpha: 0.06)),
    ),
    items: <PopupMenuEntry<T>>[
      PopupMenuItem<T>(
        enabled: false,
        height: 34,
        child: Row(
          children: [
            Icon(Icons.swap_vert_rounded,
                size: 16, color: textColor.withValues(alpha: 0.55)),
            const SizedBox(width: 8),
            Text(
              'Sırala',
              style: theme.textTheme.labelMedium?.copyWith(
                color: textColor.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(height: 1),
      for (final m in values)
        PopupMenuItem<T>(
          value: m,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: m == current
                  ? primary.withValues(alpha: isDark ? 0.18 : 0.10)
                  : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                if (icons != null) ...[
                  Icon(
                    icons[m] ?? Icons.sort_rounded,
                    size: 18,
                    color: m == current
                        ? primary
                        : textColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    labelOf(m),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: m == current ? primary : textColor,
                      fontWeight:
                          m == current ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (m == current)
                  Icon(Icons.check_rounded, size: 18, color: primary),
              ],
            ),
          ),
        ),
    ],
  );

  if (selected != null && selected != current) {
    onSelected(selected);
  }
}
