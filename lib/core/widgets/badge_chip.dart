import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../design/design_tokens.dart';

/// Reusable badge/chip component for labels, tags, and status indicators
class BadgeChip extends StatelessWidget {
  const BadgeChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final Color? color; // For colored badges (success, warning, error, info)
  final IconData? icon;
  final Color? backgroundColor; // Custom background color
  final Color? textColor; // Custom text color

  Color _getBackgroundColor(BuildContext context) {
    if (backgroundColor != null) return backgroundColor!;
    if (color != null) return color!;
    return Theme.of(context).colorScheme.primaryContainer;
  }

  Color _getTextColor(BuildContext context) {
    if (textColor != null) return textColor!;
    if (color != null) return Colors.white;
    return Theme.of(context).colorScheme.onPrimaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor(context);
    final txtColor = _getTextColor(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: txtColor,
            ),
            SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: txtColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Predefined badge variants for common use cases
class BadgeChipVariants {
  BadgeChipVariants._();

  static Widget success(BuildContext context, String label, {IconData? icon}) {
    return BadgeChip(
      label: label,
      color: AppColors.success,
      icon: icon,
    );
  }

  static Widget warning(BuildContext context, String label, {IconData? icon}) {
    return BadgeChip(
      label: label,
      color: AppColors.warning,
      icon: icon,
    );
  }

  static Widget error(BuildContext context, String label, {IconData? icon}) {
    return BadgeChip(
      label: label,
      color: AppColors.error,
      icon: icon,
    );
  }

  static Widget info(BuildContext context, String label, {IconData? icon}) {
    return BadgeChip(
      label: label,
      color: AppColors.info,
      icon: icon,
    );
  }

  static Widget newBadge(BuildContext context) {
    return BadgeChip(
      label: context.l10n.badgeNew,
      color: AppColors.error,
    );
  }

  static Widget important(BuildContext context) {
    return BadgeChip(
      label: context.l10n.badgeImportant,
      color: Colors.red,
      icon: Icons.warning_amber_rounded,
    );
  }
}

