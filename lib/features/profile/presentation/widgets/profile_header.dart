import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

/// Profile screen header widget
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    this.onSettingsPressed,
  });

  final VoidCallback? onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            context.l10n.titleProfile,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : null,
                ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(15)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: isDark
                    ? Border.all(color: Colors.white.withAlpha(20))
                    : null,
              ),
              child: Icon(
                Icons.settings_outlined,
                color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            onPressed: onSettingsPressed,
          ),
        ],
      ),
    );
  }
}

