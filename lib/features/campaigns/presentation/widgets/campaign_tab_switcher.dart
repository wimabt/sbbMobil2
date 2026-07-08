import 'package:flutter/material.dart';

import '../../../../core/design/design_tokens.dart';

class CampaignTabSwitcher extends StatelessWidget {
  const CampaignTabSwitcher({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  final String activeTab;
  final ValueChanged<String> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(8)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          _buildTab(context, 'Aktif', isDark),
          _buildTab(context, 'Tamamlanan', isDark),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, String label, bool isDark) {
    final isActive = activeTab == label;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? Colors.white.withAlpha(15) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: isActive && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? (isDark ? Colors.white : Colors.black87)
                  : Theme.of(context).hintColor,
            ),
          ),
        ),
      ),
    );
  }
}
