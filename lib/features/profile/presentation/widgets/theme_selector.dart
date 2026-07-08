import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';

/// Theme selector widget for profile screen
class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 0),
    this.showTitle = true,
  });

  /// Outer padding (use [EdgeInsets.zero] when the parent already applies insets).
  final EdgeInsetsGeometry padding;

  /// Whether to render the built-in "Tema" heading. Set to false when the
  /// parent already provides its own section header (e.g. home drawer).
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final currentMode = themeState.mode;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Text(
              'Tema',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ThemeOption(
                  icon: Icons.light_mode_outlined,
                  label: context.l10n.themeShortLight,
                  isActive: currentMode == ThemeMode.light,
                  onTap: () {
                    ref.read(themeProvider.notifier).setTheme(AppThemeMode.light);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ThemeOption(
                  icon: Icons.dark_mode_outlined,
                  label: context.l10n.themeShortDark,
                  isActive: currentMode == ThemeMode.dark,
                  onTap: () {
                    ref.read(themeProvider.notifier).setTheme(AppThemeMode.dark);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ThemeOption(
                  icon: Icons.brightness_auto_outlined,
                  label: context.l10n.themeShortSystem,
                  isActive: currentMode == ThemeMode.system,
                  onTap: () {
                    ref.read(themeProvider.notifier).setTheme(AppThemeMode.system);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Theme option widget
class ThemeOption extends StatelessWidget {
  const ThemeOption({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).hintColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isActive
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).hintColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

