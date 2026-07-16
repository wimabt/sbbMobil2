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
/// [showAppSortMenu]'nun opsiyonel çoklu seçim bölümü için seçenek.
/// (Yerler ekranı: alt kategori filtresi — sıralamanın altında ek bölüm.)
class AppMenuMultiOption {
  const AppMenuMultiOption({required this.value, required this.label});

  final String value;
  final String label;
}

Future<void> showAppSortMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required T current,
  required List<T> values,
  required String Function(T) labelOf,
  required ValueChanged<T> onSelected,
  Map<T, IconData>? icons,
  // ── Opsiyonel çoklu seçim bölümü (ör. alt kategoriler) ──────────────
  // Sıralama listesinin ALTINA ayrı bir başlıklı bölüm ekler. Chip'lere
  // dokunmak menüyü kapatmaz (anında uygulanır); "Temizle" tüm seçimleri
  // kaldırır. [multiOptions] boş/null ise bölüm hiç render edilmez.
  String? multiSectionTitle,
  IconData multiSectionIcon = Icons.account_tree_rounded,
  List<AppMenuMultiOption>? multiOptions,
  Set<String>? multiSelected,
  ValueChanged<String>? onMultiToggled,
  VoidCallback? onMultiCleared,
  String? clearLabel,
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

  // Çoklu seçim bölümünün menü-içi görsel durumu. Caller (ör. Riverpod
  // notifier) her toggle'da YENİ bir set üretebilir — menü açıkken dışarıdaki
  // state'e erişemeyeceğimiz için yerel kopya tutulur ve callback ile
  // paralel güncellenir.
  final localSelected = Set<String>.of(multiSelected ?? const <String>{});

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
      // ── Çoklu seçim bölümü (ör. alt kategoriler) ────────────────────
      if (multiOptions != null && multiOptions.isNotEmpty) ...[
        const PopupMenuDivider(height: 1),
        PopupMenuItem<T>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: StatefulBuilder(
            builder: (ctx, setMenuState) {
              final selected = localSelected;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 34,
                    child: Row(
                      children: [
                        Icon(multiSectionIcon,
                            size: 16,
                            color: textColor.withValues(alpha: 0.55)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            multiSectionTitle ?? '',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: textColor.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (selected.isNotEmpty && onMultiCleared != null)
                          GestureDetector(
                            onTap: () {
                              localSelected.clear();
                              onMultiCleared();
                              setMenuState(() {});
                            },
                            child: Text(
                              clearLabel ?? 'Temizle',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final opt in multiOptions)
                        _MenuMultiChip(
                          label: opt.label,
                          isSelected: selected.contains(opt.value),
                          primary: primary,
                          textColor: textColor,
                          isDark: isDark,
                          onTap: () {
                            if (!localSelected.remove(opt.value)) {
                              localSelected.add(opt.value);
                            }
                            onMultiToggled?.call(opt.value);
                            setMenuState(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ],
    ],
  );

  if (selected != null && selected != current) {
    onSelected(selected);
  }
}

/// Menü içi mini çoklu seçim chip'i — harita alt kategori chip'leriyle aynı
/// dil: seçiliyken yumuşak primary ton + primary çerçeve, tik ikonu yok.
class _MenuMultiChip extends StatelessWidget {
  const _MenuMultiChip({
    required this.label,
    required this.isSelected,
    required this.primary,
    required this.textColor,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color primary;
  final Color textColor;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.22 : 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? primary.withValues(alpha: isDark ? 0.55 : 0.45)
                : textColor.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? primary : textColor.withValues(alpha: 0.8),
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}
