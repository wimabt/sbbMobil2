import 'package:flutter/material.dart';
import 'sort_menu.dart';

/// §6.4.5 — Liste ekranları için ortak sıralama tetikleyici çip'i.
///
/// Bare `PopupMenuButton` yerine, tıklanınca **app token'larıyla stillenmiş
/// ankrajlı menüyü** ([showAppSortMenu]) açar. Böylece arama butonuna taşınamayan
/// (örn. filtre butonu başka amaçla dolu olan Etkinlikler ekranı) inline
/// kullanımlar da tutarlı bir görünüm alır.
///
/// API geriye uyumlu: her ekran kendi sıralama enum'unu ([T]) ve etiket
/// fonksiyonunu geçer.
class SortMenuButton<T> extends StatefulWidget {
  const SortMenuButton({
    super.key,
    required this.current,
    required this.values,
    required this.labelOf,
    required this.onSelected,
  });

  final T current;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  State<SortMenuButton<T>> createState() => _SortMenuButtonState<T>();
}

class _SortMenuButtonState<T> extends State<SortMenuButton<T>> {
  // Menünün altına hizalanacağı sabit anchor.
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showAppSortMenu<T>(
          context: context,
          anchorKey: _anchorKey,
          current: widget.current,
          values: widget.values,
          labelOf: widget.labelOf,
          onSelected: widget.onSelected,
        ),
        child: Container(
          key: _anchorKey,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(20)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border:
                isDark ? Border.all(color: Colors.white.withAlpha(30)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert_rounded,
                  size: 18, color: isDark ? Colors.white70 : null),
              const SizedBox(width: 4),
              Text(
                widget.labelOf(widget.current),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isDark ? Colors.white70 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
